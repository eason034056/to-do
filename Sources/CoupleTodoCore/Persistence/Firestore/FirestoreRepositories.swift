import Foundation

public enum FirestoreRepositoryError: Error, Equatable {
    case userNotFound(String)
    case userHasNoCouple(String)
    case settlementNotFound(String)
}

public struct FirestoreUserRepository: UserRepository, Sendable {
    private let documentStore: any FirestoreDocumentStore
    private let timestampStrategy: FirestoreTimestampStrategy

    public init(
        documentStore: any FirestoreDocumentStore,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) {
        self.documentStore = documentStore
        self.timestampStrategy = timestampStrategy
    }

    public func fetchUser(userId: String) async throws -> UserProfile? {
        let stored = try await documentStore.fetchDocument(
            at: FirestorePath.user(userId),
            as: FirestoreUserProfileDTO.self
        )
        return try stored?.document.toDomain(id: userId)
    }

    public func upsertUser(_ user: UserProfile) async throws {
        let payload = FirestoreUserProfileDTO.writePayload(from: user, timestampStrategy: timestampStrategy)
        try await documentStore.writeDocument(payload.document, at: FirestorePath.user(user.id))
    }
}

public struct FirestoreCoupleRepository: CoupleRepository, Sendable {
    private let documentStore: any FirestoreDocumentStore
    private let timestampStrategy: FirestoreTimestampStrategy

    public init(
        documentStore: any FirestoreDocumentStore,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) {
        self.documentStore = documentStore
        self.timestampStrategy = timestampStrategy
    }

    public func fetchCouple(coupleId: String) async throws -> Couple? {
        let stored = try await documentStore.fetchDocument(
            at: FirestorePath.couple(coupleId),
            as: FirestoreCoupleDTO.self
        )
        return try stored?.document.toDomain(id: coupleId)
    }

    public func findCouple(inviteCode: String) async throws -> Couple? {
        let documents = try await documentStore.listDocuments(
            in: FirestoreCollection.couples.rawValue,
            as: FirestoreCoupleDTO.self
        )
        let matching = documents.first {
            $0.document.inviteCode?.caseInsensitiveCompare(inviteCode) == .orderedSame
        }
        return try matching?.document.toDomain(id: matching?.documentID ?? "")
    }

    public func upsertCouple(_ couple: Couple) async throws {
        let payload = FirestoreCoupleDTO.writePayload(from: couple, timestampStrategy: timestampStrategy)
        try await documentStore.writeDocument(payload.document, at: FirestorePath.couple(couple.id))
    }
}

public struct FirestoreDeviceInstallationRepository: DeviceInstallationRepository, Sendable {
    private let documentStore: any FirestoreDocumentStore
    private let timestampStrategy: FirestoreTimestampStrategy

    public init(
        documentStore: any FirestoreDocumentStore,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) {
        self.documentStore = documentStore
        self.timestampStrategy = timestampStrategy
    }

    public func fetchInstallations(userId: String) async throws -> [DeviceInstallation] {
        let documents = try await documentStore.listDocuments(
            in: FirestoreCollection.deviceInstallations.rawValue,
            as: FirestoreDeviceInstallationDTO.self
        )
        return try documents
            .filter { $0.document.userId == userId }
            .map { try $0.document.toDomain(id: $0.documentID) }
    }

    public func upsertInstallation(_ installation: DeviceInstallation) async throws {
        let payload = FirestoreDeviceInstallationDTO.writePayload(
            from: installation,
            timestampStrategy: timestampStrategy
        )
        try await documentStore.writeDocument(
            payload.document,
            at: FirestorePath.deviceInstallation(installation.id)
        )
    }
}

public struct FirestorePlanRepository: PlanRepository, Sendable {
    private let documentStore: any FirestoreDocumentStore
    private let timestampStrategy: FirestoreTimestampStrategy

    public init(
        documentStore: any FirestoreDocumentStore,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) {
        self.documentStore = documentStore
        self.timestampStrategy = timestampStrategy
    }

    public func upsertPlan(_ plan: DailyPlan) async throws {
        let payload = FirestorePlanDTO.writePayload(from: plan, timestampStrategy: timestampStrategy)
        try await documentStore.writeDocument(
            payload.document,
            at: FirestorePath.plan(coupleId: plan.coupleId, userId: plan.userId, dateKey: plan.dateKey)
        )
    }

    public func fetchPlan(userId: String, dateKey: String) async throws -> DailyPlan? {
        let documents = try await documentStore.listCollectionGroup(
            .plans,
            as: FirestorePlanDTO.self
        )
        let matching = documents.first {
            $0.document.userId == userId && $0.document.dateKey == dateKey
        }
        return matching?.document.toDomain(documentId: matching?.documentID ?? "")
    }
}

public struct FirestoreTaskRepository: TaskRepository, Sendable {
    private let documentStore: any FirestoreDocumentStore
    private let userRepository: any UserRepository
    private let timestampStrategy: FirestoreTimestampStrategy

    public init(
        documentStore: any FirestoreDocumentStore,
        userRepository: any UserRepository,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) {
        self.documentStore = documentStore
        self.userRepository = userRepository
        self.timestampStrategy = timestampStrategy
    }

    public func replaceTasks(for userId: String, dateKey: String, tasks: [TodoTask]) async throws {
        let existingDocuments = try await queryTaskDocuments(ownerUserId: userId, dateKey: dateKey)
        for document in existingDocuments {
            try await documentStore.deleteDocument(at: document.path)
        }

        for task in tasks {
            try await upsertTask(task)
        }
    }

    public func fetchTasks(userId: String, dateKey: String) async throws -> [TodoTask] {
        let documents = try await queryTaskDocuments(ownerUserId: userId, dateKey: dateKey)
        let tasks = try documents.map { try $0.document.toDomain(id: $0.documentID) }
        return TaskSortingService.sort(tasks)
    }

    public func upsertTask(_ task: TodoTask) async throws {
        let coupleId = try await resolveCoupleId(for: task.ownerUserId)
        let payload = FirestoreTaskDTO.writePayload(from: task, timestampStrategy: timestampStrategy)
        try await documentStore.writeDocument(
            payload.document,
            at: FirestorePath.task(
                coupleId: coupleId,
                userId: task.ownerUserId,
                dateKey: task.dateKey,
                taskId: task.id
            )
        )
    }

    public func deleteTask(id: String, ownerUserId: String, dateKey: String) async throws {
        let documents = try await queryTaskDocuments(ownerUserId: ownerUserId, dateKey: dateKey)
        for document in documents where document.documentID == id {
            try await documentStore.deleteDocument(at: document.path)
        }
    }

    private func queryTaskDocuments(
        ownerUserId: String,
        dateKey: String
    ) async throws -> [FirestoreStoredDocument<FirestoreTaskDTO>] {
        let documents = try await documentStore.listCollectionGroup(
            .tasks,
            as: FirestoreTaskDTO.self
        )
        return documents.filter {
            $0.document.ownerUserId == ownerUserId && $0.document.dateKey == dateKey
        }
    }

    private func resolveCoupleId(for userId: String) async throws -> String {
        guard let user = try await userRepository.fetchUser(userId: userId) else {
            throw FirestoreRepositoryError.userNotFound(userId)
        }
        guard let coupleId = user.coupleId else {
            throw FirestoreRepositoryError.userHasNoCouple(userId)
        }
        return coupleId
    }
}

public struct FirestoreSettlementRepository: SettlementRepository, Sendable {
    private let documentStore: any FirestoreDocumentStore
    private let timestampStrategy: FirestoreTimestampStrategy

    public init(
        documentStore: any FirestoreDocumentStore,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) {
        self.documentStore = documentStore
        self.timestampStrategy = timestampStrategy
    }

    public func upsertSettlement(_ settlement: DailySettlement) async throws {
        let payload = FirestoreSettlementDTO.writePayload(
            from: settlement,
            timestampStrategy: timestampStrategy
        )
        try await documentStore.writeDocument(
            payload.document,
            at: FirestorePath.settlement(
                coupleId: settlement.coupleId,
                subjectUserId: settlement.subjectUserId,
                dateKey: settlement.dateKey
            )
        )
    }

    public func fetchSettlement(coupleId: String, settlementId: String) async throws -> DailySettlement? {
        let stored = try await documentStore.fetchDocument(
            at: "\(FirestorePath.couple(coupleId))/\(FirestoreCollection.settlements.rawValue)/\(settlementId)",
            as: FirestoreSettlementDTO.self
        )
        return try stored?.document.toDomain(documentId: settlementId)
    }

    public func fetchLatestSettlement(coupleId: String, subjectUserId: String) async throws -> DailySettlement? {
        let documents = try await documentStore.listDocuments(
            in: "\(FirestorePath.couple(coupleId))/\(FirestoreCollection.settlements.rawValue)",
            as: FirestoreSettlementDTO.self
        )
        let settlements = try documents
            .filter { $0.document.subjectUserId == subjectUserId }
            .map { try $0.document.toDomain(documentId: $0.documentID) }
        return settlements.max(by: { $0.computedAt < $1.computedAt })
    }

    public func acknowledgeSettlement(coupleId: String, settlementId: String, userId: String) async throws {
        guard var settlement = try await fetchSettlement(coupleId: coupleId, settlementId: settlementId) else {
            throw FirestoreRepositoryError.settlementNotFound(settlementId)
        }
        settlement.pendingAcknowledgementUserIds.removeAll { $0 == userId }
        try await upsertSettlement(settlement)
    }
}

public struct FirestoreRewardWeekRepository: RewardWeekRepository, Sendable {
    private let documentStore: any FirestoreDocumentStore
    private let timestampStrategy: FirestoreTimestampStrategy

    public init(
        documentStore: any FirestoreDocumentStore,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) {
        self.documentStore = documentStore
        self.timestampStrategy = timestampStrategy
    }

    public func upsertRewardWeek(_ rewardWeek: RewardWeek) async throws {
        let payload = FirestoreRewardWeekDTO.writePayload(
            from: rewardWeek,
            timestampStrategy: timestampStrategy
        )
        try await documentStore.writeDocument(
            payload.document,
            at: FirestorePath.rewardWeek(coupleId: rewardWeek.coupleId, weekKey: rewardWeek.weekKey)
        )
    }

    public func fetchRewardWeek(coupleId: String, weekKey: String) async throws -> RewardWeek? {
        let stored = try await documentStore.fetchDocument(
            at: FirestorePath.rewardWeek(coupleId: coupleId, weekKey: weekKey),
            as: FirestoreRewardWeekDTO.self
        )
        return try stored?.document.toDomain()
    }
}

public struct FirestoreEventRepository: EventRepository, Sendable {
    private let documentStore: any FirestoreDocumentStore
    private let timestampStrategy: FirestoreTimestampStrategy

    public init(
        documentStore: any FirestoreDocumentStore,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) {
        self.documentStore = documentStore
        self.timestampStrategy = timestampStrategy
    }

    public func appendEvent(_ event: EventLogEntry) async throws {
        let payload = FirestoreEventLogEntryDTO.writePayload(
            from: event,
            timestampStrategy: timestampStrategy
        )
        try await documentStore.writeDocument(
            payload.document,
            at: FirestorePath.event(coupleId: event.coupleId, eventId: event.id)
        )
    }

    public func fetchEvents(coupleId: String, limit: Int) async throws -> [EventLogEntry] {
        let documents = try await documentStore.listDocuments(
            in: "\(FirestorePath.couple(coupleId))/\(FirestoreCollection.events.rawValue)",
            as: FirestoreEventLogEntryDTO.self
        )
        let sorted = try documents
            .map { try $0.document.toDomain(id: $0.documentID) }
            .sorted(by: { $0.createdAt < $1.createdAt })
        return Array(sorted.suffix(limit))
    }
}
