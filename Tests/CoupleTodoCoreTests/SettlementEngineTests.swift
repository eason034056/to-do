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
                localTimezone: "UTC",
                title: "Workout",
                notes: nil,
                bucket: .required,
                priority: .p0,
                status: .completed,
                sortOrder: 1,
                completedAtServer: completedTime
            ),
            TodoTask(
                id: "2",
                ownerUserId: "usr_1",
                dateKey: "2026-03-08",
                localTimezone: "UTC",
                title: "Read",
                notes: nil,
                bucket: .optional,
                priority: .p1,
                status: .pending,
                sortOrder: 2,
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
                localTimezone: "UTC",
                title: "Plan tomorrow",
                notes: nil,
                bucket: .required,
                priority: .p0,
                status: .completed,
                sortOrder: 1,
                completedAtServer: lateTime
            ),
            TodoTask(
                id: "2",
                ownerUserId: "usr_1",
                dateKey: "2026-03-08",
                localTimezone: "UTC",
                title: "Submit report",
                notes: nil,
                bucket: .required,
                priority: .p1,
                status: .pending,
                sortOrder: 2,
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
