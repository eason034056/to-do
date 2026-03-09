import Foundation

public enum TaskBucket: String, Codable, CaseIterable, Sendable {
    case required
    case optional
}

public enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case p0
    case p1
    case p2
    case p3
}

public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case completed
    case missed
    case carriedOver
}

public enum SyncState: String, Codable, CaseIterable, Sendable {
    case localPending = "local_pending"
    case synced
    case serverFinal = "server_final"
}

public struct TodoTask: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let ownerUserId: String
    public let dateKey: String
    public let localTimezone: String
    public var title: String
    public var notes: String?
    public var bucket: TaskBucket
    public var priority: TaskPriority
    public var status: TaskStatus
    public var sortOrder: Int
    public var completedAtServer: Date?
    public var localUtcOffsetMinutes: Int?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var completedAtClient: Date?
    public var carriedFromTaskId: String?
    public var deleted: Bool
    public var syncState: SyncState

    public init(
        id: String,
        ownerUserId: String,
        dateKey: String,
        localTimezone: String,
        title: String,
        notes: String?,
        bucket: TaskBucket,
        priority: TaskPriority,
        status: TaskStatus,
        sortOrder: Int,
        completedAtServer: Date?,
        localUtcOffsetMinutes: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        completedAtClient: Date? = nil,
        carriedFromTaskId: String? = nil,
        deleted: Bool = false,
        syncState: SyncState = .synced
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.dateKey = dateKey
        self.localTimezone = localTimezone
        self.title = title
        self.notes = notes
        self.bucket = bucket
        self.priority = priority
        self.status = status
        self.sortOrder = sortOrder
        self.completedAtServer = completedAtServer
        self.localUtcOffsetMinutes = localUtcOffsetMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAtClient = completedAtClient
        self.carriedFromTaskId = carriedFromTaskId
        self.deleted = deleted
        self.syncState = syncState
    }
}

public struct DailyPlan: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let userId: String
    public let coupleId: String
    public let dateKey: String
    public let localTimezone: String
    public var submittedAt: Date?
    public var planningMissed: Bool
    public var localUtcOffsetMinutes: Int?
    public var lastEditedAt: Date?
    public var requiredCount: Int
    public var optionalCount: Int
    public var version: Int

    public init(
        id: String,
        userId: String,
        coupleId: String,
        dateKey: String,
        localTimezone: String,
        submittedAt: Date?,
        planningMissed: Bool,
        localUtcOffsetMinutes: Int? = nil,
        lastEditedAt: Date? = nil,
        requiredCount: Int = 0,
        optionalCount: Int = 0,
        version: Int = 1
    ) {
        self.id = id
        self.userId = userId
        self.coupleId = coupleId
        self.dateKey = dateKey
        self.localTimezone = localTimezone
        self.submittedAt = submittedAt
        self.planningMissed = planningMissed
        self.localUtcOffsetMinutes = localUtcOffsetMinutes
        self.lastEditedAt = lastEditedAt
        self.requiredCount = requiredCount
        self.optionalCount = optionalCount
        self.version = version
    }
}

public struct SettlementSummary: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let subjectUserId: String
    public let counterpartyUserId: String
    public let dateKey: String
    public let localTimezone: String
    public let requiredTotal: Int
    public let requiredCompleted: Int
    public let owesAmount: Decimal
    public let isPass: Bool

    public init(
        id: String,
        subjectUserId: String,
        counterpartyUserId: String,
        dateKey: String,
        localTimezone: String,
        requiredTotal: Int,
        requiredCompleted: Int,
        owesAmount: Decimal,
        isPass: Bool
    ) {
        self.id = id
        self.subjectUserId = subjectUserId
        self.counterpartyUserId = counterpartyUserId
        self.dateKey = dateKey
        self.localTimezone = localTimezone
        self.requiredTotal = requiredTotal
        self.requiredCompleted = requiredCompleted
        self.owesAmount = owesAmount
        self.isPass = isPass
    }

    public init(from settlement: DailySettlement) {
        self.init(
            id: settlement.id,
            subjectUserId: settlement.subjectUserId,
            counterpartyUserId: settlement.counterpartyUserId,
            dateKey: settlement.dateKey,
            localTimezone: settlement.localTimezone,
            requiredTotal: settlement.subjectResult.requiredTotal,
            requiredCompleted: settlement.subjectResult.requiredCompleted,
            owesAmount: settlement.subjectResult.owesAmount,
            isPass: settlement.subjectResult.outcome == .pass
        )
    }
}

public enum WeekStart: String, Codable, CaseIterable, Sendable {
    case monday
    case sunday
}

public struct NotificationPreferences: Codable, Sendable, Equatable {
    public var planningReminderEnabled: Bool
    public var settlementReminderEnabled: Bool
    public var timeSensitiveAllowed: Bool

    public init(
        planningReminderEnabled: Bool = true,
        settlementReminderEnabled: Bool = true,
        timeSensitiveAllowed: Bool = true
    ) {
        self.planningReminderEnabled = planningReminderEnabled
        self.settlementReminderEnabled = settlementReminderEnabled
        self.timeSensitiveAllowed = timeSensitiveAllowed
    }
}

public struct ReminderConfig: Codable, Sendable, Equatable {
    public var planningReminderTime: LocalClockTime
    public var planningCutoffTime: LocalClockTime
    public var planningEscalationEveryMinutes: Int
    public var dailySettlementTime: LocalClockTime
    public var dailySettlementGraceMinutes: Int

    public init(
        planningReminderTime: LocalClockTime = LocalClockTime(hour: 21, minute: 30),
        planningCutoffTime: LocalClockTime = LocalClockTime(hour: 23, minute: 0),
        planningEscalationEveryMinutes: Int = 15,
        dailySettlementTime: LocalClockTime = LocalClockTime(hour: 23, minute: 59),
        dailySettlementGraceMinutes: Int = 5
    ) {
        self.planningReminderTime = planningReminderTime
        self.planningCutoffTime = planningCutoffTime
        self.planningEscalationEveryMinutes = planningEscalationEveryMinutes
        self.dailySettlementTime = dailySettlementTime
        self.dailySettlementGraceMinutes = dailySettlementGraceMinutes
    }

    public static let `default` = ReminderConfig()
}

public struct PenaltyPolicy: Codable, Sendable, Equatable {
    public enum Mode: String, Codable, Sendable {
        case flatPerDay = "flat_per_day"
    }

    public var mode: Mode
    public var amount: Decimal
    public var currency: String
    public var enabled: Bool
    public var planningMissPenaltyEnabled: Bool

    public init(
        mode: Mode = .flatPerDay,
        amount: Decimal = 50,
        currency: String = "USD",
        enabled: Bool = true,
        planningMissPenaltyEnabled: Bool = false
    ) {
        self.mode = mode
        self.amount = amount
        self.currency = currency
        self.enabled = enabled
        self.planningMissPenaltyEnabled = planningMissPenaltyEnabled
    }

    public static let `default` = PenaltyPolicy()
}

public enum CoupleStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case active
}

public struct Couple: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var memberIds: [String]
    public var status: CoupleStatus
    public var weekStartsOn: WeekStart
    public var penaltyPolicy: PenaltyPolicy
    public var reminderConfig: ReminderConfig
    public var inviteCode: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        memberIds: [String],
        status: CoupleStatus,
        weekStartsOn: WeekStart,
        penaltyPolicy: PenaltyPolicy,
        reminderConfig: ReminderConfig,
        inviteCode: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.memberIds = memberIds
        self.status = status
        self.weekStartsOn = weekStartsOn
        self.penaltyPolicy = penaltyPolicy
        self.reminderConfig = reminderConfig
        self.inviteCode = inviteCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct UserProfile: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var displayName: String
    public var photoURL: String?
    public var coupleId: String?
    public var currentTimezone: String
    public var currentUtcOffsetMinutes: Int
    public var lastLocalDateKey: String
    public var lastLocalWeekKey: String
    public var notificationPreferences: NotificationPreferences
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        displayName: String,
        photoURL: String? = nil,
        coupleId: String? = nil,
        currentTimezone: String,
        currentUtcOffsetMinutes: Int,
        lastLocalDateKey: String,
        lastLocalWeekKey: String,
        notificationPreferences: NotificationPreferences = NotificationPreferences(),
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.displayName = displayName
        self.photoURL = photoURL
        self.coupleId = coupleId
        self.currentTimezone = currentTimezone
        self.currentUtcOffsetMinutes = currentUtcOffsetMinutes
        self.lastLocalDateKey = lastLocalDateKey
        self.lastLocalWeekKey = lastLocalWeekKey
        self.notificationPreferences = notificationPreferences
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum DevicePlatform: String, Codable, CaseIterable, Sendable {
    case ios
}

public struct DeviceInstallation: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var userId: String
    public var platform: DevicePlatform
    public var fcmToken: String?
    public var apnsToken: String?
    public var timezone: String
    public var utcOffsetMinutes: Int
    public var lastLocalDateKey: String
    public var supportsLiveActivities: Bool
    public var supportsTimeSensitive: Bool
    public var appVersion: String
    public var buildNumber: String
    public var updatedAt: Date

    public init(
        id: String,
        userId: String,
        platform: DevicePlatform = .ios,
        fcmToken: String? = nil,
        apnsToken: String? = nil,
        timezone: String,
        utcOffsetMinutes: Int,
        lastLocalDateKey: String,
        supportsLiveActivities: Bool,
        supportsTimeSensitive: Bool,
        appVersion: String,
        buildNumber: String,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.platform = platform
        self.fcmToken = fcmToken
        self.apnsToken = apnsToken
        self.timezone = timezone
        self.utcOffsetMinutes = utcOffsetMinutes
        self.lastLocalDateKey = lastLocalDateKey
        self.supportsLiveActivities = supportsLiveActivities
        self.supportsTimeSensitive = supportsTimeSensitive
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.updatedAt = updatedAt
    }
}

public enum SettlementState: String, Codable, CaseIterable, Sendable {
    case pending
    case finalized
}

public struct CounterpartySettlementSnapshot: Codable, Sendable, Equatable {
    public var latestKnownDateKey: String?
    public var latestKnownOutcome: SettlementOutcome?

    public init(latestKnownDateKey: String? = nil, latestKnownOutcome: SettlementOutcome? = nil) {
        self.latestKnownDateKey = latestKnownDateKey
        self.latestKnownOutcome = latestKnownOutcome
    }
}

public struct RewardImpact: Codable, Sendable, Equatable {
    public var weekKey: String
    public var stillEligible: Bool

    public init(weekKey: String, stillEligible: Bool) {
        self.weekKey = weekKey
        self.stillEligible = stillEligible
    }
}

public struct DailySettlement: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let coupleId: String
    public var subjectUserId: String
    public var counterpartyUserId: String
    public var dateKey: String
    public var localTimezone: String
    public var localWeekKey: String
    public var state: SettlementState
    public var computedAt: Date
    public var graceAppliedUntil: Date?
    public var subjectResult: SettlementResult
    public var counterpartySnapshot: CounterpartySettlementSnapshot
    public var pendingAcknowledgementUserIds: [String]
    public var rewardImpact: RewardImpact?

    public init(
        id: String,
        coupleId: String,
        subjectUserId: String,
        counterpartyUserId: String,
        dateKey: String,
        localTimezone: String,
        localWeekKey: String,
        state: SettlementState,
        computedAt: Date,
        graceAppliedUntil: Date?,
        subjectResult: SettlementResult,
        counterpartySnapshot: CounterpartySettlementSnapshot = CounterpartySettlementSnapshot(),
        pendingAcknowledgementUserIds: [String] = [],
        rewardImpact: RewardImpact? = nil
    ) {
        self.id = id
        self.coupleId = coupleId
        self.subjectUserId = subjectUserId
        self.counterpartyUserId = counterpartyUserId
        self.dateKey = dateKey
        self.localTimezone = localTimezone
        self.localWeekKey = localWeekKey
        self.state = state
        self.computedAt = computedAt
        self.graceAppliedUntil = graceAppliedUntil
        self.subjectResult = subjectResult
        self.counterpartySnapshot = counterpartySnapshot
        self.pendingAcknowledgementUserIds = pendingAcknowledgementUserIds
        self.rewardImpact = rewardImpact
    }
}

public enum RewardWeekStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case active
    case locked
    case earned
    case missed
}

public struct RewardWeek: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let coupleId: String
    public var weekKey: String
    public var effectiveWeekStartDate: String
    public var draftedInWeekKey: String
    public var rewardText: String
    public var status: RewardWeekStatus
    public var eligibility: [String: Bool]
    public var memberLocalWeekKeys: [String: String]
    public var finalizeWhenBothMembersWeekClosed: Bool
    public var earnedAt: Date?
    public var missedAt: Date?
    public var updatedAt: Date

    public init(
        id: String,
        coupleId: String,
        weekKey: String,
        effectiveWeekStartDate: String,
        draftedInWeekKey: String,
        rewardText: String,
        status: RewardWeekStatus,
        eligibility: [String: Bool],
        memberLocalWeekKeys: [String: String],
        finalizeWhenBothMembersWeekClosed: Bool = true,
        earnedAt: Date? = nil,
        missedAt: Date? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.coupleId = coupleId
        self.weekKey = weekKey
        self.effectiveWeekStartDate = effectiveWeekStartDate
        self.draftedInWeekKey = draftedInWeekKey
        self.rewardText = rewardText
        self.status = status
        self.eligibility = eligibility
        self.memberLocalWeekKeys = memberLocalWeekKeys
        self.finalizeWhenBothMembersWeekClosed = finalizeWhenBothMembersWeekClosed
        self.earnedAt = earnedAt
        self.missedAt = missedAt
        self.updatedAt = updatedAt
    }
}

public typealias WeekReward = RewardWeek

public enum EventLogType: String, Codable, CaseIterable, Sendable {
    case taskCreated = "task_created"
    case taskUpdated = "task_updated"
    case taskDeleted = "task_deleted"
    case taskCompleted = "task_completed"
    case taskUncompleted = "task_uncompleted"
    case planSubmitted = "plan_submitted"
    case planningMissed = "planning_missed"
    case settlementFinalized = "settlement_finalized"
    case weeklyRewardDrafted = "weekly_reward_drafted"
    case weeklyRewardEarned = "weekly_reward_earned"
    case weeklyRewardMissed = "weekly_reward_missed"
}

public struct EventLogEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let coupleId: String
    public var type: EventLogType
    public var actorUserId: String
    public var subjectId: String?
    public var payload: [String: String]
    public var createdAt: Date

    public init(
        id: String,
        coupleId: String,
        type: EventLogType,
        actorUserId: String,
        subjectId: String? = nil,
        payload: [String: String] = [:],
        createdAt: Date
    ) {
        self.id = id
        self.coupleId = coupleId
        self.type = type
        self.actorUserId = actorUserId
        self.subjectId = subjectId
        self.payload = payload
        self.createdAt = createdAt
    }
}

public struct SharedSnapshot: Codable, Sendable, Equatable {
    public struct TodaySnapshot: Codable, Sendable, Equatable {
        public struct UserSummary: Codable, Sendable, Equatable {
            public var timezone: String
            public var requiredRemaining: Int
            public var requiredCompleted: Int
            public var topTasks: [String]

            public init(timezone: String, requiredRemaining: Int, requiredCompleted: Int, topTasks: [String]) {
                self.timezone = timezone
                self.requiredRemaining = requiredRemaining
                self.requiredCompleted = requiredCompleted
                self.topTasks = topTasks
            }
        }

        public var selfDateKey: String
        public var partnerDateKey: String
        public var `self`: UserSummary
        public var partner: UserSummary

        public init(selfDateKey: String, partnerDateKey: String, selfSummary: UserSummary, partner: UserSummary) {
            self.selfDateKey = selfDateKey
            self.partnerDateKey = partnerDateKey
            self.`self` = selfSummary
            self.partner = partner
        }
    }

    public struct PlanningSnapshot: Codable, Sendable, Equatable {
        public var targetDateKey: String
        public var selfSubmitted: Bool
        public var partnerSubmitted: Bool

        public init(targetDateKey: String, selfSubmitted: Bool, partnerSubmitted: Bool) {
            self.targetDateKey = targetDateKey
            self.selfSubmitted = selfSubmitted
            self.partnerSubmitted = partnerSubmitted
        }
    }

    public struct SettlementSnapshot: Codable, Sendable, Equatable {
        public var selfDateKey: String
        public var partnerLatestDateKey: String?
        public var isPendingAck: Bool
        public var selfOutcome: SettlementOutcome?
        public var partnerOutcome: SettlementOutcome?
        public var selfOwesAmount: Decimal

        public init(
            selfDateKey: String,
            partnerLatestDateKey: String?,
            isPendingAck: Bool,
            selfOutcome: SettlementOutcome?,
            partnerOutcome: SettlementOutcome?,
            selfOwesAmount: Decimal
        ) {
            self.selfDateKey = selfDateKey
            self.partnerLatestDateKey = partnerLatestDateKey
            self.isPendingAck = isPendingAck
            self.selfOutcome = selfOutcome
            self.partnerOutcome = partnerOutcome
            self.selfOwesAmount = selfOwesAmount
        }
    }

    public var generatedAt: Date
    public var today: TodaySnapshot
    public var planning: PlanningSnapshot
    public var settlement: SettlementSnapshot

    public init(generatedAt: Date, today: TodaySnapshot, planning: PlanningSnapshot, settlement: SettlementSnapshot) {
        self.generatedAt = generatedAt
        self.today = today
        self.planning = planning
        self.settlement = settlement
    }
}

public struct PlanningReminderActivityContentState: Codable, Sendable, Equatable {
    public var selfSubmitted: Bool
    public var partnerSubmitted: Bool
    public var cutoffTime: String
    public var remainingMinutes: Int

    public init(selfSubmitted: Bool, partnerSubmitted: Bool, cutoffTime: String, remainingMinutes: Int) {
        self.selfSubmitted = selfSubmitted
        self.partnerSubmitted = partnerSubmitted
        self.cutoffTime = cutoffTime
        self.remainingMinutes = remainingMinutes
    }
}

public struct DailySettlementActivityContentState: Codable, Sendable, Equatable {
    public var selfOutcome: SettlementOutcome?
    public var partnerOutcome: SettlementOutcome?
    public var selfOwesAmount: Decimal
    public var partnerOwesAmount: Decimal
    public var needsAck: Bool

    public init(
        selfOutcome: SettlementOutcome?,
        partnerOutcome: SettlementOutcome?,
        selfOwesAmount: Decimal,
        partnerOwesAmount: Decimal,
        needsAck: Bool
    ) {
        self.selfOutcome = selfOutcome
        self.partnerOutcome = partnerOutcome
        self.selfOwesAmount = selfOwesAmount
        self.partnerOwesAmount = partnerOwesAmount
        self.needsAck = needsAck
    }
}
