import Foundation

public enum FirestoreTimestampStrategy: Sendable {
    case preserveDomainValues
    case preferServerTimestamps
}

public struct FirestoreWritePayload<DTO: Sendable>: Sendable {
    public let document: DTO
    public let serverTimestampFields: Set<String>

    public init(document: DTO, serverTimestampFields: Set<String>) {
        self.document = document
        self.serverTimestampFields = serverTimestampFields
    }
}

public enum FirestoreMappingError: Error, Equatable {
    case invalidEnum(field: String, value: String)
    case invalidClockTime(field: String, value: String)
    case invalidDecimal(field: String, value: String)
    case missingRequiredField(String)
}

public struct FirestoreNotificationPreferencesDTO: Codable, Equatable, Sendable {
    public var planningReminderEnabled: Bool
    public var settlementReminderEnabled: Bool
    public var timeSensitiveAllowed: Bool

    public init(from domain: NotificationPreferences) {
        planningReminderEnabled = domain.planningReminderEnabled
        settlementReminderEnabled = domain.settlementReminderEnabled
        timeSensitiveAllowed = domain.timeSensitiveAllowed
    }

    public func toDomain() -> NotificationPreferences {
        NotificationPreferences(
            planningReminderEnabled: planningReminderEnabled,
            settlementReminderEnabled: settlementReminderEnabled,
            timeSensitiveAllowed: timeSensitiveAllowed
        )
    }
}

public struct FirestoreReminderConfigDTO: Codable, Equatable, Sendable {
    public var planningReminderTime: String
    public var planningCutoffTime: String
    public var planningEscalationEveryMinutes: Int
    public var dailySettlementTime: String
    public var dailySettlementGraceMinutes: Int

    public init(from domain: ReminderConfig) {
        planningReminderTime = domain.planningReminderTime.displayString
        planningCutoffTime = domain.planningCutoffTime.displayString
        planningEscalationEveryMinutes = domain.planningEscalationEveryMinutes
        dailySettlementTime = domain.dailySettlementTime.displayString
        dailySettlementGraceMinutes = domain.dailySettlementGraceMinutes
    }

    public func toDomain() throws -> ReminderConfig {
        ReminderConfig(
            planningReminderTime: try parseClockTime(planningReminderTime, field: "planningReminderTime"),
            planningCutoffTime: try parseClockTime(planningCutoffTime, field: "planningCutoffTime"),
            planningEscalationEveryMinutes: planningEscalationEveryMinutes,
            dailySettlementTime: try parseClockTime(dailySettlementTime, field: "dailySettlementTime"),
            dailySettlementGraceMinutes: dailySettlementGraceMinutes
        )
    }
}

public struct FirestorePenaltyPolicyDTO: Codable, Equatable, Sendable {
    public var mode: String
    public var amount: String
    public var currency: String
    public var enabled: Bool
    public var planningMissPenaltyEnabled: Bool

    public init(from domain: PenaltyPolicy) {
        mode = domain.mode.rawValue
        amount = decimalString(domain.amount)
        currency = domain.currency
        enabled = domain.enabled
        planningMissPenaltyEnabled = domain.planningMissPenaltyEnabled
    }

    public func toDomain() throws -> PenaltyPolicy {
        guard let mode = PenaltyPolicy.Mode(rawValue: mode) else {
            throw FirestoreMappingError.invalidEnum(field: "mode", value: mode)
        }
        return PenaltyPolicy(
            mode: mode,
            amount: try parseDecimal(amount, field: "amount"),
            currency: currency,
            enabled: enabled,
            planningMissPenaltyEnabled: planningMissPenaltyEnabled
        )
    }
}

public struct FirestoreSettlementResultDTO: Codable, Equatable, Sendable {
    public var requiredTotal: Int
    public var requiredCompleted: Int
    public var missedRequiredCount: Int
    public var outcome: String
    public var owesAmount: String

    public init(from domain: SettlementResult) {
        requiredTotal = domain.requiredTotal
        requiredCompleted = domain.requiredCompleted
        missedRequiredCount = domain.missedRequiredCount
        outcome = domain.outcome.rawValue
        owesAmount = decimalString(domain.owesAmount)
    }

    public func toDomain() throws -> SettlementResult {
        guard let outcome = SettlementOutcome(rawValue: outcome) else {
            throw FirestoreMappingError.invalidEnum(field: "outcome", value: outcome)
        }
        return SettlementResult(
            requiredTotal: requiredTotal,
            requiredCompleted: requiredCompleted,
            missedRequiredCount: missedRequiredCount,
            outcome: outcome,
            owesAmount: try parseDecimal(owesAmount, field: "owesAmount")
        )
    }
}

public struct FirestoreCounterpartySettlementSnapshotDTO: Codable, Equatable, Sendable {
    public var latestKnownDateKey: String?
    public var latestKnownOutcome: String?

    public init(from domain: CounterpartySettlementSnapshot) {
        latestKnownDateKey = domain.latestKnownDateKey
        latestKnownOutcome = domain.latestKnownOutcome?.rawValue
    }

    public func toDomain() throws -> CounterpartySettlementSnapshot {
        let outcome: SettlementOutcome?
        if let latestKnownOutcome {
            guard let parsed = SettlementOutcome(rawValue: latestKnownOutcome) else {
                throw FirestoreMappingError.invalidEnum(field: "latestKnownOutcome", value: latestKnownOutcome)
            }
            outcome = parsed
        } else {
            outcome = nil
        }

        return CounterpartySettlementSnapshot(
            latestKnownDateKey: latestKnownDateKey,
            latestKnownOutcome: outcome
        )
    }
}

public struct FirestoreRewardImpactDTO: Codable, Equatable, Sendable {
    public var weekKey: String
    public var stillEligible: Bool

    public init(from domain: RewardImpact?) {
        weekKey = domain?.weekKey ?? ""
        stillEligible = domain?.stillEligible ?? false
    }

    public func toDomain() -> RewardImpact? {
        weekKey.isEmpty ? nil : RewardImpact(weekKey: weekKey, stillEligible: stillEligible)
    }
}

public struct FirestoreUserProfileDTO: Codable, Equatable, Sendable {
    public var displayName: String
    public var photoURL: String?
    public var coupleId: String?
    public var currentTimezone: String
    public var currentUtcOffsetMinutes: Int
    public var lastLocalDateKey: String
    public var lastLocalWeekKey: String
    public var notificationPreferences: FirestoreNotificationPreferencesDTO
    public var createdAt: Date?
    public var updatedAt: Date?

    public static func writePayload(
        from user: UserProfile,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) -> FirestoreWritePayload<FirestoreUserProfileDTO> {
        var serverTimestampFields = Set<String>()
        let document = FirestoreUserProfileDTO(
            displayName: user.displayName,
            photoURL: user.photoURL,
            coupleId: user.coupleId,
            currentTimezone: user.currentTimezone,
            currentUtcOffsetMinutes: user.currentUtcOffsetMinutes,
            lastLocalDateKey: user.lastLocalDateKey,
            lastLocalWeekKey: user.lastLocalWeekKey,
            notificationPreferences: FirestoreNotificationPreferencesDTO(from: user.notificationPreferences),
            createdAt: serializedTimestamp(user.createdAt, field: "createdAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            updatedAt: serializedTimestamp(user.updatedAt, field: "updatedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields)
        )
        return FirestoreWritePayload(document: document, serverTimestampFields: serverTimestampFields)
    }

    public func toDomain(id: String) throws -> UserProfile {
        UserProfile(
            id: id,
            displayName: displayName,
            photoURL: photoURL,
            coupleId: coupleId,
            currentTimezone: currentTimezone,
            currentUtcOffsetMinutes: currentUtcOffsetMinutes,
            lastLocalDateKey: lastLocalDateKey,
            lastLocalWeekKey: lastLocalWeekKey,
            notificationPreferences: notificationPreferences.toDomain(),
            createdAt: try required(createdAt, field: "createdAt"),
            updatedAt: try required(updatedAt, field: "updatedAt")
        )
    }
}

public struct FirestoreDeviceInstallationDTO: Codable, Equatable, Sendable {
    public var userId: String
    public var platform: String
    public var fcmToken: String?
    public var apnsToken: String?
    public var timezone: String
    public var utcOffsetMinutes: Int
    public var lastLocalDateKey: String
    public var supportsLiveActivities: Bool
    public var supportsTimeSensitive: Bool
    public var appVersion: String
    public var buildNumber: String
    public var updatedAt: Date?

    public static func writePayload(
        from installation: DeviceInstallation,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) -> FirestoreWritePayload<FirestoreDeviceInstallationDTO> {
        var serverTimestampFields = Set<String>()
        let document = FirestoreDeviceInstallationDTO(
            userId: installation.userId,
            platform: installation.platform.rawValue,
            fcmToken: installation.fcmToken,
            apnsToken: installation.apnsToken,
            timezone: installation.timezone,
            utcOffsetMinutes: installation.utcOffsetMinutes,
            lastLocalDateKey: installation.lastLocalDateKey,
            supportsLiveActivities: installation.supportsLiveActivities,
            supportsTimeSensitive: installation.supportsTimeSensitive,
            appVersion: installation.appVersion,
            buildNumber: installation.buildNumber,
            updatedAt: serializedTimestamp(installation.updatedAt, field: "updatedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields)
        )
        return FirestoreWritePayload(document: document, serverTimestampFields: serverTimestampFields)
    }

    public func toDomain(id: String) throws -> DeviceInstallation {
        guard let platform = DevicePlatform(rawValue: platform) else {
            throw FirestoreMappingError.invalidEnum(field: "platform", value: platform)
        }
        return DeviceInstallation(
            id: id,
            userId: userId,
            platform: platform,
            fcmToken: fcmToken,
            apnsToken: apnsToken,
            timezone: timezone,
            utcOffsetMinutes: utcOffsetMinutes,
            lastLocalDateKey: lastLocalDateKey,
            supportsLiveActivities: supportsLiveActivities,
            supportsTimeSensitive: supportsTimeSensitive,
            appVersion: appVersion,
            buildNumber: buildNumber,
            updatedAt: try required(updatedAt, field: "updatedAt")
        )
    }
}

public struct FirestoreCoupleDTO: Codable, Equatable, Sendable {
    public var memberIds: [String]
    public var status: String
    public var weekStartsOn: String
    public var penaltyPolicy: FirestorePenaltyPolicyDTO
    public var reminderConfig: FirestoreReminderConfigDTO
    public var inviteCode: String?
    public var createdAt: Date?
    public var updatedAt: Date?

    public static func writePayload(
        from couple: Couple,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) -> FirestoreWritePayload<FirestoreCoupleDTO> {
        var serverTimestampFields = Set<String>()
        let document = FirestoreCoupleDTO(
            memberIds: couple.memberIds,
            status: couple.status.rawValue,
            weekStartsOn: couple.weekStartsOn.rawValue,
            penaltyPolicy: FirestorePenaltyPolicyDTO(from: couple.penaltyPolicy),
            reminderConfig: FirestoreReminderConfigDTO(from: couple.reminderConfig),
            inviteCode: couple.inviteCode,
            createdAt: serializedTimestamp(couple.createdAt, field: "createdAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            updatedAt: serializedTimestamp(couple.updatedAt, field: "updatedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields)
        )
        return FirestoreWritePayload(document: document, serverTimestampFields: serverTimestampFields)
    }

    public func toDomain(id: String) throws -> Couple {
        guard let status = CoupleStatus(rawValue: status) else {
            throw FirestoreMappingError.invalidEnum(field: "status", value: status)
        }
        guard let weekStartsOn = WeekStart(rawValue: weekStartsOn) else {
            throw FirestoreMappingError.invalidEnum(field: "weekStartsOn", value: weekStartsOn)
        }
        return Couple(
            id: id,
            memberIds: memberIds,
            status: status,
            weekStartsOn: weekStartsOn,
            penaltyPolicy: try penaltyPolicy.toDomain(),
            reminderConfig: try reminderConfig.toDomain(),
            inviteCode: inviteCode,
            createdAt: try required(createdAt, field: "createdAt"),
            updatedAt: try required(updatedAt, field: "updatedAt")
        )
    }
}

public struct FirestoreInviteDTO: Codable, Equatable, Sendable {
    public var coupleId: String
    public var inviteCode: String
    public var createdByUserId: String
    public var claimedByUserId: String?
    public var status: String
    public var expiresAt: Date?
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        coupleId: String,
        inviteCode: String,
        createdByUserId: String,
        claimedByUserId: String? = nil,
        status: String = "active",
        expiresAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.coupleId = coupleId
        self.inviteCode = inviteCode
        self.createdByUserId = createdByUserId
        self.claimedByUserId = claimedByUserId
        self.status = status
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct FirestorePlanDTO: Codable, Equatable, Sendable {
    public var userId: String
    public var coupleId: String
    public var dateKey: String
    public var localTimezone: String
    public var submittedAt: Date?
    public var planningMissed: Bool
    public var localUtcOffsetMinutes: Int?
    public var lastEditedAt: Date?
    public var requiredCount: Int
    public var optionalCount: Int
    public var version: Int

    public static func writePayload(
        from plan: DailyPlan,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) -> FirestoreWritePayload<FirestorePlanDTO> {
        var serverTimestampFields = Set<String>()
        let document = FirestorePlanDTO(
            userId: plan.userId,
            coupleId: plan.coupleId,
            dateKey: plan.dateKey,
            localTimezone: plan.localTimezone,
            submittedAt: serializedTimestamp(plan.submittedAt, field: "submittedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            planningMissed: plan.planningMissed,
            localUtcOffsetMinutes: plan.localUtcOffsetMinutes,
            lastEditedAt: serializedTimestamp(plan.lastEditedAt, field: "lastEditedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            requiredCount: plan.requiredCount,
            optionalCount: plan.optionalCount,
            version: plan.version
        )
        return FirestoreWritePayload(document: document, serverTimestampFields: serverTimestampFields)
    }

    public func toDomain(documentId: String) -> DailyPlan {
        DailyPlan(
            id: documentId,
            userId: userId,
            coupleId: coupleId,
            dateKey: dateKey,
            localTimezone: localTimezone,
            submittedAt: submittedAt,
            planningMissed: planningMissed,
            localUtcOffsetMinutes: localUtcOffsetMinutes,
            lastEditedAt: lastEditedAt,
            requiredCount: requiredCount,
            optionalCount: optionalCount,
            version: version
        )
    }
}

public struct FirestoreTaskDTO: Codable, Equatable, Sendable {
    public var ownerUserId: String
    public var dateKey: String
    public var localTimezone: String
    public var title: String
    public var notes: String?
    public var bucket: String
    public var priority: String
    public var status: String
    public var sortOrder: Int
    public var completedAtServer: Date?
    public var localUtcOffsetMinutes: Int?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var completedAtClient: Date?
    public var carriedFromTaskId: String?
    public var deleted: Bool
    public var syncState: String

    public static func writePayload(
        from task: TodoTask,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) -> FirestoreWritePayload<FirestoreTaskDTO> {
        var serverTimestampFields = Set<String>()
        let document = FirestoreTaskDTO(
            ownerUserId: task.ownerUserId,
            dateKey: task.dateKey,
            localTimezone: task.localTimezone,
            title: task.title,
            notes: task.notes,
            bucket: task.bucket.rawValue,
            priority: task.priority.rawValue,
            status: task.status.rawValue,
            sortOrder: task.sortOrder,
            completedAtServer: serializedTimestamp(task.completedAtServer, field: "completedAtServer", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            localUtcOffsetMinutes: task.localUtcOffsetMinutes,
            createdAt: serializedTimestamp(task.createdAt, field: "createdAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            updatedAt: serializedTimestamp(task.updatedAt, field: "updatedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            completedAtClient: task.completedAtClient,
            carriedFromTaskId: task.carriedFromTaskId,
            deleted: task.deleted,
            syncState: task.syncState.rawValue
        )
        return FirestoreWritePayload(document: document, serverTimestampFields: serverTimestampFields)
    }

    public func toDomain(id: String) throws -> TodoTask {
        guard let bucket = TaskBucket(rawValue: bucket) else {
            throw FirestoreMappingError.invalidEnum(field: "bucket", value: bucket)
        }
        guard let priority = TaskPriority(rawValue: priority) else {
            throw FirestoreMappingError.invalidEnum(field: "priority", value: priority)
        }
        guard let status = TaskStatus(rawValue: status) else {
            throw FirestoreMappingError.invalidEnum(field: "status", value: status)
        }
        guard let syncState = SyncState(rawValue: syncState) else {
            throw FirestoreMappingError.invalidEnum(field: "syncState", value: syncState)
        }

        return TodoTask(
            id: id,
            ownerUserId: ownerUserId,
            dateKey: dateKey,
            localTimezone: localTimezone,
            title: title,
            notes: notes,
            bucket: bucket,
            priority: priority,
            status: status,
            sortOrder: sortOrder,
            completedAtServer: completedAtServer,
            localUtcOffsetMinutes: localUtcOffsetMinutes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAtClient: completedAtClient,
            carriedFromTaskId: carriedFromTaskId,
            deleted: deleted,
            syncState: syncState
        )
    }
}

public struct FirestoreSettlementDTO: Codable, Equatable, Sendable {
    public var coupleId: String
    public var subjectUserId: String
    public var counterpartyUserId: String
    public var dateKey: String
    public var localTimezone: String
    public var localWeekKey: String
    public var state: String
    public var computedAt: Date?
    public var graceAppliedUntil: Date?
    public var subjectResult: FirestoreSettlementResultDTO
    public var counterpartySnapshot: FirestoreCounterpartySettlementSnapshotDTO
    public var pendingAcknowledgementUserIds: [String]
    public var rewardImpact: FirestoreRewardImpactDTO

    public static func writePayload(
        from settlement: DailySettlement,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) -> FirestoreWritePayload<FirestoreSettlementDTO> {
        var serverTimestampFields = Set<String>()
        let document = FirestoreSettlementDTO(
            coupleId: settlement.coupleId,
            subjectUserId: settlement.subjectUserId,
            counterpartyUserId: settlement.counterpartyUserId,
            dateKey: settlement.dateKey,
            localTimezone: settlement.localTimezone,
            localWeekKey: settlement.localWeekKey,
            state: settlement.state.rawValue,
            computedAt: serializedTimestamp(settlement.computedAt, field: "computedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            graceAppliedUntil: settlement.graceAppliedUntil,
            subjectResult: FirestoreSettlementResultDTO(from: settlement.subjectResult),
            counterpartySnapshot: FirestoreCounterpartySettlementSnapshotDTO(from: settlement.counterpartySnapshot),
            pendingAcknowledgementUserIds: settlement.pendingAcknowledgementUserIds,
            rewardImpact: FirestoreRewardImpactDTO(from: settlement.rewardImpact)
        )
        return FirestoreWritePayload(document: document, serverTimestampFields: serverTimestampFields)
    }

    public func toDomain(documentId: String) throws -> DailySettlement {
        guard let state = SettlementState(rawValue: state) else {
            throw FirestoreMappingError.invalidEnum(field: "state", value: state)
        }
        return DailySettlement(
            id: documentId,
            coupleId: coupleId,
            subjectUserId: subjectUserId,
            counterpartyUserId: counterpartyUserId,
            dateKey: dateKey,
            localTimezone: localTimezone,
            localWeekKey: localWeekKey,
            state: state,
            computedAt: try required(computedAt, field: "computedAt"),
            graceAppliedUntil: graceAppliedUntil,
            subjectResult: try subjectResult.toDomain(),
            counterpartySnapshot: try counterpartySnapshot.toDomain(),
            pendingAcknowledgementUserIds: pendingAcknowledgementUserIds,
            rewardImpact: rewardImpact.toDomain()
        )
    }
}

public struct FirestoreRewardWeekDTO: Codable, Equatable, Sendable {
    public var coupleId: String
    public var weekKey: String
    public var effectiveWeekStartDate: String
    public var draftedInWeekKey: String
    public var rewardText: String
    public var status: String
    public var eligibility: [String: Bool]
    public var memberLocalWeekKeys: [String: String]
    public var finalizeWhenBothMembersWeekClosed: Bool
    public var updatedAt: Date?
    public var earnedAt: Date?
    public var missedAt: Date?

    public static func writePayload(
        from rewardWeek: RewardWeek,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) -> FirestoreWritePayload<FirestoreRewardWeekDTO> {
        var serverTimestampFields = Set<String>()
        let document = FirestoreRewardWeekDTO(
            coupleId: rewardWeek.coupleId,
            weekKey: rewardWeek.weekKey,
            effectiveWeekStartDate: rewardWeek.effectiveWeekStartDate,
            draftedInWeekKey: rewardWeek.draftedInWeekKey,
            rewardText: rewardWeek.rewardText,
            status: rewardWeek.status.rawValue,
            eligibility: rewardWeek.eligibility,
            memberLocalWeekKeys: rewardWeek.memberLocalWeekKeys,
            finalizeWhenBothMembersWeekClosed: rewardWeek.finalizeWhenBothMembersWeekClosed,
            updatedAt: serializedTimestamp(rewardWeek.updatedAt, field: "updatedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            earnedAt: serializedTimestamp(rewardWeek.earnedAt, field: "earnedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields),
            missedAt: serializedTimestamp(rewardWeek.missedAt, field: "missedAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields)
        )
        return FirestoreWritePayload(document: document, serverTimestampFields: serverTimestampFields)
    }

    public func toDomain(documentId: String? = nil) throws -> RewardWeek {
        guard let status = RewardWeekStatus(rawValue: status) else {
            throw FirestoreMappingError.invalidEnum(field: "status", value: status)
        }
        return RewardWeek(
            id: documentId ?? "\(coupleId)_\(weekKey)",
            coupleId: coupleId,
            weekKey: weekKey,
            effectiveWeekStartDate: effectiveWeekStartDate,
            draftedInWeekKey: draftedInWeekKey,
            rewardText: rewardText,
            status: status,
            eligibility: eligibility,
            memberLocalWeekKeys: memberLocalWeekKeys,
            finalizeWhenBothMembersWeekClosed: finalizeWhenBothMembersWeekClosed,
            earnedAt: earnedAt,
            missedAt: missedAt,
            updatedAt: try required(updatedAt, field: "updatedAt")
        )
    }
}

public struct FirestoreEventLogEntryDTO: Codable, Equatable, Sendable {
    public var coupleId: String
    public var type: String
    public var actorUserId: String
    public var subjectId: String?
    public var payload: [String: String]
    public var createdAt: Date?

    public static func writePayload(
        from event: EventLogEntry,
        timestampStrategy: FirestoreTimestampStrategy = .preserveDomainValues
    ) -> FirestoreWritePayload<FirestoreEventLogEntryDTO> {
        var serverTimestampFields = Set<String>()
        let document = FirestoreEventLogEntryDTO(
            coupleId: event.coupleId,
            type: event.type.rawValue,
            actorUserId: event.actorUserId,
            subjectId: event.subjectId,
            payload: event.payload,
            createdAt: serializedTimestamp(event.createdAt, field: "createdAt", strategy: timestampStrategy, serverTimestampFields: &serverTimestampFields)
        )
        return FirestoreWritePayload(document: document, serverTimestampFields: serverTimestampFields)
    }

    public func toDomain(id: String) throws -> EventLogEntry {
        guard let type = EventLogType(rawValue: type) else {
            throw FirestoreMappingError.invalidEnum(field: "type", value: type)
        }
        return EventLogEntry(
            id: id,
            coupleId: coupleId,
            type: type,
            actorUserId: actorUserId,
            subjectId: subjectId,
            payload: payload,
            createdAt: try required(createdAt, field: "createdAt")
        )
    }
}

private func serializedTimestamp(
    _ value: Date?,
    field: String,
    strategy: FirestoreTimestampStrategy,
    serverTimestampFields: inout Set<String>
) -> Date? {
    guard let value else {
        return nil
    }
    switch strategy {
    case .preserveDomainValues:
        return value
    case .preferServerTimestamps:
        serverTimestampFields.insert(field)
        return nil
    }
}

private func required(_ value: Date?, field: String) throws -> Date {
    guard let value else {
        throw FirestoreMappingError.missingRequiredField(field)
    }
    return value
}

private func parseClockTime(_ value: String, field: String) throws -> LocalClockTime {
    let parts = value.split(separator: ":").map(String.init)
    guard parts.count == 2,
          let hour = Int(parts[0]),
          let minute = Int(parts[1]) else {
        throw FirestoreMappingError.invalidClockTime(field: field, value: value)
    }
    let time = LocalClockTime(hour: hour, minute: minute)
    guard time.isValid else {
        throw FirestoreMappingError.invalidClockTime(field: field, value: value)
    }
    return time
}

private func parseDecimal(_ value: String, field: String) throws -> Decimal {
    guard let decimal = Decimal(string: value) else {
        throw FirestoreMappingError.invalidDecimal(field: field, value: value)
    }
    return decimal
}

private func decimalString(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
}
