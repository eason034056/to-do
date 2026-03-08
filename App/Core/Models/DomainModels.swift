import Foundation

enum TaskBucket: String, Codable, CaseIterable {
    case required
    case optional
}

enum TaskPriority: String, Codable, CaseIterable {
    case p0, p1, p2, p3
}

enum TaskStatus: String, Codable {
    case pending
    case completed
}

struct TodoTask: Identifiable, Codable, Hashable {
    let id: String
    let ownerUserId: String
    let dateKey: String
    let localTimezone: String
    var title: String
    var notes: String?
    var bucket: TaskBucket
    var priority: TaskPriority
    var status: TaskStatus
    var sortOrder: Int
    var completedAtServer: Date?
}

struct DailyPlan: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let coupleId: String
    let dateKey: String
    let localTimezone: String
    var submittedAt: Date?
    var planningMissed: Bool
}

struct SettlementSummary: Identifiable, Codable, Hashable {
    let id: String
    let subjectUserId: String
    let counterpartyUserId: String
    let dateKey: String
    let localTimezone: String
    let requiredTotal: Int
    let requiredCompleted: Int
    let owesAmount: Decimal
    let isPass: Bool
}

struct WeekReward: Identifiable, Codable, Hashable {
    enum Status: String, Codable {
        case draft
        case locked
        case earned
        case missed
    }

    let id: String
    let weekKey: String
    var title: String
    var status: Status
}
