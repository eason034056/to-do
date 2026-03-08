import Foundation
import Testing
@testable import CoupleTodoCore

struct SettlementEngineTests {
    @Test
    func returnsPassWhenAllRequiredTasksCompletedBeforeCutoff() {
        let engine = SettlementEngine(penaltyAmount: 50)
        let cutoff = ISO8601DateFormatter().date(from: "2026-03-08T23:59:00Z")!
        let completedTime = ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z")!

        let tasks = [
            TodoTask(
                id: "1",
                ownerUserId: "usr_1",
                dateKey: "2026-03-08",
                bucket: .required,
                title: "Workout",
                completionState: .completed,
                completedAtServer: completedTime
            ),
            TodoTask(
                id: "2",
                ownerUserId: "usr_1",
                dateKey: "2026-03-08",
                bucket: .optional,
                title: "Read",
                completionState: .pending,
                completedAtServer: nil
            )
        ]

        let result = engine.computeUserSettlement(
            for: "usr_1",
            on: "2026-03-08",
            cutoff: cutoff,
            tasks: tasks
        )

        #expect(result.requiredTotal == 1)
        #expect(result.requiredCompleted == 1)
        #expect(result.missedRequiredCount == 0)
        #expect(result.outcome == .pass)
        #expect(result.owesAmount == 0)
    }

    @Test
    func returnsFailAndPenaltyWhenRequiredTasksAreIncompleteOrLate() {
        let engine = SettlementEngine(penaltyAmount: 50)
        let cutoff = ISO8601DateFormatter().date(from: "2026-03-08T23:59:00Z")!
        let lateTime = ISO8601DateFormatter().date(from: "2026-03-09T00:01:00Z")!

        let tasks = [
            TodoTask(
                id: "1",
                ownerUserId: "usr_1",
                dateKey: "2026-03-08",
                bucket: .required,
                title: "Plan tomorrow",
                completionState: .completed,
                completedAtServer: lateTime
            ),
            TodoTask(
                id: "2",
                ownerUserId: "usr_1",
                dateKey: "2026-03-08",
                bucket: .required,
                title: "Submit report",
                completionState: .pending,
                completedAtServer: nil
            )
        ]

        let result = engine.computeUserSettlement(
            for: "usr_1",
            on: "2026-03-08",
            cutoff: cutoff,
            tasks: tasks
        )

        #expect(result.requiredTotal == 2)
        #expect(result.requiredCompleted == 0)
        #expect(result.missedRequiredCount == 2)
        #expect(result.outcome == .fail)
        #expect(result.owesAmount == 50)
    }
}
