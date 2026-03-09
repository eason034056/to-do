import Foundation

public struct SettlementResult: Codable, Equatable, Sendable {
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

public enum SettlementOutcome: String, Codable, Equatable, Sendable {
    case pass
    case fail
}
