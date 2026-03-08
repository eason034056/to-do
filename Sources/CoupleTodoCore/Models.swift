import Foundation

public enum TaskBucket: String, Codable, Sendable {
    case required
    case optional
}

public enum TaskCompletionState: String, Codable, Sendable {
    case pending
    case completed
}

public struct TodoTask: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let ownerUserId: String
    public let dateKey: String
    public let bucket: TaskBucket
    public let title: String
    public let completionState: TaskCompletionState
    public let completedAtServer: Date?

    public init(
        id: String,
        ownerUserId: String,
        dateKey: String,
        bucket: TaskBucket,
        title: String,
        completionState: TaskCompletionState,
        completedAtServer: Date?
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.dateKey = dateKey
        self.bucket = bucket
        self.title = title
        self.completionState = completionState
        self.completedAtServer = completedAtServer
    }
}

public struct SettlementResult: Equatable, Sendable {
    public let requiredTotal: Int
    public let requiredCompleted: Int
    public let missedRequiredCount: Int
    public let outcome: SettlementOutcome
    public let owesAmount: Decimal

    public init(
        requiredTotal: Int,
        requiredCompleted: Int,
        missedRequiredCount: Int,
        outcome: SettlementOutcome,
        owesAmount: Decimal
    ) {
        self.requiredTotal = requiredTotal
        self.requiredCompleted = requiredCompleted
        self.missedRequiredCount = missedRequiredCount
        self.outcome = outcome
        self.owesAmount = owesAmount
    }
}

public enum SettlementOutcome: String, Equatable, Sendable {
    case pass
    case fail
}
