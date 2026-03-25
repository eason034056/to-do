import CoupleTodoCore
@preconcurrency import FirebaseFirestore
import Foundation

public actor FirestoreUserRepository: UserRepository {
    private let database: Firestore

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func fetchUser(userId: String) async throws -> UserProfile? {
        let snapshot = try await database.document(FirestorePaths.userDocument(userId)).getDocumentAsync()
        guard let data = snapshot.data() else { return nil }
        return try UserProfileDocument.decode(id: snapshot.documentID, data: data)
    }

    public func upsertUser(_ user: UserProfile) async throws {
        let document = database.document(FirestorePaths.userDocument(user.id))
        let snapshot = try await document.getDocumentAsync()
        try await document.setDataAsync(
            UserProfileDocument.clientPayload(from: user, includeCreatedAt: snapshot.exists == false),
            merge: true
        )
    }
}

public actor FirestoreCoupleRepository: CoupleRepository {
    private let database: Firestore

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func fetchCouple(coupleId: String) async throws -> Couple? {
        let snapshot = try await database.document(FirestorePaths.coupleDocument(coupleId)).getDocumentAsync()
        guard let data = snapshot.data() else { return nil }
        return try CoupleDocument.decode(id: snapshot.documentID, data: data)
    }

    public func findCouple(inviteCode: String) async throws -> Couple? {
        let snapshot = try await database.collection(FirestorePaths.couples)
            .whereField("inviteCode", isEqualTo: inviteCode)
            .limit(to: 1)
            .getDocumentsAsync()

        guard let document = snapshot.documents.first else {
            return nil
        }
        return try CoupleDocument.decode(id: document.documentID, data: document.data())
    }

    public func upsertCouple(_ couple: Couple) async throws {
        try await database.document(FirestorePaths.coupleDocument(couple.id)).setDataAsync(
            CoupleDocument.clientSettingsPayload(from: couple),
            merge: true
        )
    }
}

public actor FirestoreDeviceInstallationRepository: DeviceInstallationRepository {
    private let database: Firestore

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func fetchInstallations(userId: String) async throws -> [DeviceInstallation] {
        let snapshot = try await database.collection(FirestorePaths.deviceInstallations)
            .whereField("userId", isEqualTo: userId)
            .getDocumentsAsync()
        return try snapshot.documents.compactMap { document in
            try DeviceInstallationDocument.decode(id: document.documentID, data: document.data())
        }
    }

    public func upsertInstallation(_ installation: DeviceInstallation) async throws {
        try await database.document(FirestorePaths.deviceInstallationDocument(installation.id)).setDataAsync(
            DeviceInstallationDocument.clientPayload(from: installation),
            merge: true
        )
    }
}

public actor FirestorePlanRepository: PlanRepository {
    private let database: Firestore

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func upsertPlan(_ plan: DailyPlan) async throws {
        try await database.document(
            FirestorePaths.planDocument(coupleId: plan.coupleId, planId: plan.id)
        ).setDataAsync(DailyPlanDocument.clientPayload(from: plan), merge: true)
    }

    public func fetchPlan(userId: String, dateKey: String) async throws -> DailyPlan? {
        guard let coupleId = try await fetchCoupleId(for: userId) else { return nil }
        let planId = FirestorePaths.planId(userId: userId, dateKey: dateKey)
        let snapshot = try await database.document(
            FirestorePaths.planDocument(coupleId: coupleId, planId: planId)
        ).getDocumentAsync()
        guard let data = snapshot.data() else { return nil }
        return try DailyPlanDocument.decode(id: snapshot.documentID, data: data)
    }

    private func fetchCoupleId(for userId: String) async throws -> String? {
        let snapshot = try await database.document(FirestorePaths.userDocument(userId)).getDocumentAsync()
        guard let data = snapshot.data() else { return nil }
        return data["coupleId"] as? String
    }
}

public actor FirestoreTaskRepository: TaskRepository {
    private let database: Firestore

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func replaceTasks(for userId: String, dateKey: String, tasks: [TodoTask]) async throws {
        guard let coupleId = try await fetchCoupleId(for: userId) else { return }
        let planId = FirestorePaths.planId(userId: userId, dateKey: dateKey)
        let collection = database.collection("\(FirestorePaths.planDocument(coupleId: coupleId, planId: planId))/\(FirestorePaths.tasks)")
        let existingTasks = try await collection.getDocumentsAsync()
        let retainedIds = Set(tasks.map(\.id))
        let existingTaskIds = Set(existingTasks.documents.map(\.documentID))
        let batch = database.batch()

        for document in existingTasks.documents where retainedIds.contains(document.documentID) == false {
            batch.deleteDocument(document.reference)
        }
        for task in tasks {
            batch.setData(
                TodoTaskDocument.clientPayload(
                    from: task,
                    includeCreatedAt: existingTaskIds.contains(task.id) == false
                ),
                forDocument: collection.document(task.id),
                merge: true
            )
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    public func fetchTasks(userId: String, dateKey: String) async throws -> [TodoTask] {
        guard let coupleId = try await fetchCoupleId(for: userId) else { return [] }
        let planId = FirestorePaths.planId(userId: userId, dateKey: dateKey)
        let snapshot = try await database.collection(
            "\(FirestorePaths.planDocument(coupleId: coupleId, planId: planId))/\(FirestorePaths.tasks)"
        ).getDocumentsAsync()

        return try snapshot.documents.compactMap { document in
            try TodoTaskDocument.decode(id: document.documentID, data: document.data())
        }
    }

    public func upsertTask(_ task: TodoTask) async throws {
        guard let coupleId = try await fetchCoupleId(for: task.ownerUserId) else { return }
        let planId = FirestorePaths.planId(userId: task.ownerUserId, dateKey: task.dateKey)
        let document = database.document(
            FirestorePaths.taskDocument(coupleId: coupleId, planId: planId, taskId: task.id)
        )
        let snapshot = try await document.getDocumentAsync()
        try await document.setDataAsync(
            TodoTaskDocument.clientPayload(from: task, includeCreatedAt: snapshot.exists == false),
            merge: true
        )
    }

    public func deleteTask(id: String, ownerUserId: String, dateKey: String) async throws {
        guard let coupleId = try await fetchCoupleId(for: ownerUserId) else { return }
        let planId = FirestorePaths.planId(userId: ownerUserId, dateKey: dateKey)
        try await database.document(
            FirestorePaths.taskDocument(coupleId: coupleId, planId: planId, taskId: id)
        ).deleteAsync()
    }

    private func fetchCoupleId(for userId: String) async throws -> String? {
        let snapshot = try await database.document(FirestorePaths.userDocument(userId)).getDocumentAsync()
        guard let data = snapshot.data() else { return nil }
        return data["coupleId"] as? String
    }
}

public actor FirestoreSettlementRepository: SettlementRepository {
    private let database: Firestore

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func upsertSettlement(_ settlement: DailySettlement) async throws {
        try await database.document(
            FirestorePaths.settlementDocument(coupleId: settlement.coupleId, settlementId: settlement.id)
        ).setDataAsync(DailySettlementDocument.encode(settlement), merge: true)
    }

    public func fetchSettlement(coupleId: String, settlementId: String) async throws -> DailySettlement? {
        let snapshot = try await database.document(
            FirestorePaths.settlementDocument(coupleId: coupleId, settlementId: settlementId)
        ).getDocumentAsync()
        guard let data = snapshot.data() else { return nil }
        return try DailySettlementDocument.decode(id: snapshot.documentID, data: data)
    }

    public func fetchLatestSettlement(coupleId: String, subjectUserId: String) async throws -> DailySettlement? {
        let snapshot = try await database.collection("\(FirestorePaths.coupleDocument(coupleId))/\(FirestorePaths.settlements)")
            .whereField("subjectUserId", isEqualTo: subjectUserId)
            .order(by: "computedAt", descending: true)
            .limit(to: 1)
            .getDocumentsAsync()

        guard let document = snapshot.documents.first else {
            return nil
        }
        return try DailySettlementDocument.decode(id: document.documentID, data: document.data())
    }

    public func acknowledgeSettlement(coupleId: String, settlementId: String, userId: String) async throws {
        guard let settlement = try await fetchSettlement(coupleId: coupleId, settlementId: settlementId) else { return }
        try await database.document(
            FirestorePaths.settlementDocument(coupleId: coupleId, settlementId: settlementId)
        ).updateDataAsync(DailySettlementDocument.acknowledgementPayload(from: settlement, userId: userId))
    }
}

public actor FirestoreRewardWeekRepository: RewardWeekRepository {
    private let database: Firestore

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func upsertRewardWeek(_ rewardWeek: RewardWeek) async throws {
        try await database.document(
            FirestorePaths.rewardWeekDocument(coupleId: rewardWeek.coupleId, weekKey: rewardWeek.weekKey)
        ).setDataAsync(RewardWeekDocument.encode(rewardWeek), merge: true)
    }

    public func fetchRewardWeek(coupleId: String, weekKey: String) async throws -> RewardWeek? {
        let snapshot = try await database.document(
            FirestorePaths.rewardWeekDocument(coupleId: coupleId, weekKey: weekKey)
        ).getDocumentAsync()
        guard let data = snapshot.data() else { return nil }
        return try RewardWeekDocument.decode(id: snapshot.documentID, data: data)
    }
}

public actor FirestorePaymentRepository: PaymentRepository {
    private let database: Firestore

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func upsertPayment(_ payment: PaymentRecord) async throws {
        try await database.document(
            FirestorePaths.paymentDocument(coupleId: payment.coupleId, recordId: payment.id)
        ).setDataAsync(PaymentRecordDocument.encode(payment), merge: true)
    }

    public func fetchPayment(coupleId: String, recordId: String) async throws -> PaymentRecord? {
        let snapshot = try await database.document(
            FirestorePaths.paymentDocument(coupleId: coupleId, recordId: recordId)
        ).getDocumentAsync()
        guard let data = snapshot.data() else { return nil }
        return try PaymentRecordDocument.decode(id: snapshot.documentID, data: data)
    }

    public func fetchPayments(coupleId: String, userId: String) async throws -> [PaymentRecord] {
        let snapshot = try await database.collection("\(FirestorePaths.coupleDocument(coupleId))/\(FirestorePaths.payments)")
            .getDocumentsAsync()

        let payments = try snapshot.documents.map { document in
            let payment = try PaymentRecordDocument.decode(id: document.documentID, data: document.data())
            return payment
        }
        .filter { payment in
            payment.debtorUserId == userId || payment.creditorUserId == userId
        }
        .sorted(by: { $0.updatedAt > $1.updatedAt })
        return payments
    }

    public func markPaymentPaid(coupleId: String, recordId: String, debtorUserId: String, paidAt: Date) async throws {
        try await database.document(
            FirestorePaths.paymentDocument(coupleId: coupleId, recordId: recordId)
        ).updateDataAsync(PaymentRecordDocument.markPaidPayload(actorUserId: debtorUserId, paidAt: paidAt))
    }

    public func resolvePaymentStatus(
        coupleId: String,
        recordId: String,
        creditorUserId: String,
        status: PaymentStatus,
        resolvedAt: Date
    ) async throws {
        try await database.document(
            FirestorePaths.paymentDocument(coupleId: coupleId, recordId: recordId)
        ).updateDataAsync(
            PaymentRecordDocument.resolveStatusPayload(
                status: status,
                actorUserId: creditorUserId,
                resolvedAt: resolvedAt
            )
        )
    }
}

public actor FirestoreEventRepository: EventRepository {
    private let database: Firestore

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func appendEvent(_ event: EventLogEntry) async throws {
        try await database.document(
            FirestorePaths.eventDocument(coupleId: event.coupleId, eventId: event.id)
        ).setDataAsync(EventLogEntryDocument.encode(event), merge: true)
    }

    public func fetchEvents(coupleId: String, limit: Int) async throws -> [EventLogEntry] {
        let snapshot = try await database.collection("\(FirestorePaths.coupleDocument(coupleId))/\(FirestorePaths.events)")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocumentsAsync()

        return try snapshot.documents.compactMap { document in
            try EventLogEntryDocument.decode(id: document.documentID, data: document.data())
        }
    }
}
