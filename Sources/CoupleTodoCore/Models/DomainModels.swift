import Foundation

public enum TaskBucket: String, Codable, CaseIterable, Sendable {
    case required
    case optional
}

public enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case p0, p1, p2, p3
}

public enum TaskStatus: String, Codable, Sendable {
    case pending
    case completed
}

public struct TodoTask: Identifiable, Codable, Hashable, Sendable {
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
        completedAtServer: Date?
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
    }
}

public struct DailyPlan: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let userId: String
    public let coupleId: String
    public let dateKey: String
    public let localTimezone: String
    public var submittedAt: Date?
    public var planningMissed: Bool
}

public struct SettlementSummary: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let subjectUserId: String
    public let counterpartyUserId: String
    public let dateKey: String
    public let localTimezone: String
    public let requiredTotal: Int
    public let requiredCompleted: Int
    public let owesAmount: Decimal
    public let isPass: Bool
}

public struct WeekReward: Identifiable, Codable, Hashable, Sendable {
    public enum Status: String, Codable, Sendable {
        case draft
        case locked
        case earned
        case missed
    }

    public let id: String
    public let weekKey: String
    public var title: String
    public var status: Status
}
