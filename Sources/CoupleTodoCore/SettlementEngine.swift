import Foundation

public struct SettlementEngine: Sendable {
    public let penaltyAmount: Decimal

    public init(penaltyAmount: Decimal = 50) {
        self.penaltyAmount = penaltyAmount
    }

    public func computeUserSettlement(
        for userId: String,
        on dateKey: String,
        cutoff: Date,
        tasks: [TodoTask]
    ) -> SettlementResult {
        let requiredTasks = tasks.filter {
            $0.ownerUserId == userId &&
            $0.dateKey == dateKey &&
            $0.bucket == .required
        }

        let requiredCompleted = requiredTasks.filter { task in
            guard task.status == .completed,
                  let completedAtServer = task.completedAtServer else {
                return false
            }
            return completedAtServer <= cutoff
        }.count

        let requiredTotal = requiredTasks.count
        let missedRequiredCount = max(0, requiredTotal - requiredCompleted)
        let outcome: SettlementOutcome = missedRequiredCount == 0 ? .pass : .fail
        let owesAmount = outcome == .fail ? penaltyAmount : 0

        return SettlementResult(
            requiredTotal: requiredTotal,
            requiredCompleted: requiredCompleted,
            missedRequiredCount: missedRequiredCount,
            outcome: outcome,
            owesAmount: owesAmount
        )
    }
}
