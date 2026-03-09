import XCTest
@testable import CoupleTodoCore

final class SettlementUseCasesTests: XCTestCase {
    func testFinalizeDailySettlementStoresSettlementAndUpdatesEligibility() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T23:59:00Z"))
        let cutoff = now
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let couple = Couple(
            id: "cpl_1",
            memberIds: ["usr_1", "usr_2"],
            status: .active,
            weekStartsOn: .monday,
            penaltyPolicy: .default,
            reminderConfig: .default,
            inviteCode: "ABC123",
            createdAt: now,
            updatedAt: now
        )
        let rewardWeek = RewardWeek(
            id: "cpl_1_2026-W10",
            coupleId: "cpl_1",
            weekKey: "2026-W10",
            effectiveWeekStartDate: "2026-03-02",
            draftedInWeekKey: "2026-W09",
            rewardText: "Date night",
            status: .active,
            eligibility: ["usr_1": true, "usr_2": true],
            memberLocalWeekKeys: [:],
            updatedAt: now
        )
        let useCase = FinalizeDailySettlementUseCase(
            coupleRepository: TestCoupleRepository(seed: [couple]),
            planRepository: TestPlanRepository(seed: [
                DailyPlan(
                    id: "usr_1_2026-03-08",
                    userId: "usr_1",
                    coupleId: "cpl_1",
                    dateKey: "2026-03-08",
                    localTimezone: "UTC",
                    submittedAt: now,
                    planningMissed: false
                )
            ]),
            taskRepository: TestTaskRepository(seed: [
                "usr_1_2026-03-08": [
                    TodoTask(
                        id: "task_1",
                        ownerUserId: "usr_1",
                        dateKey: "2026-03-08",
                        localTimezone: "UTC",
                        title: "Required work",
                        notes: nil,
                        bucket: .required,
                        priority: .p0,
                        status: .pending,
                        sortOrder: 1,
                        completedAtServer: nil
                    )
                ]
            ]),
            settlementRepository: TestSettlementRepository(),
            rewardWeekRepository: TestRewardWeekRepository(seed: [rewardWeek]),
            eventRepository: TestEventRepository()
        )

        let settlement = try await useCase.execute(
            FinalizeDailySettlementRequest(
                coupleId: "cpl_1",
                subjectUserId: "usr_1",
                counterpartyUserId: "usr_2",
                dateKey: "2026-03-08",
                timezone: timezone,
                cutoff: cutoff,
                finalizedAt: now
            )
        )

        XCTAssertEqual(settlement.subjectResult.outcome, .fail)
        XCTAssertEqual(settlement.subjectResult.owesAmount, 50)
        XCTAssertEqual(settlement.rewardImpact?.stillEligible, false)
        XCTAssertEqual(settlement.pendingAcknowledgementUserIds, ["usr_1", "usr_2"])
    }

    func testAcknowledgeSettlementRemovesUserFromPendingList() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T23:59:00Z"))
        let settlement = DailySettlement(
            id: "usr_1_2026-03-08",
            coupleId: "cpl_1",
            subjectUserId: "usr_1",
            counterpartyUserId: "usr_2",
            dateKey: "2026-03-08",
            localTimezone: "UTC",
            localWeekKey: "2026-W10",
            state: .finalized,
            computedAt: now,
            graceAppliedUntil: now,
            subjectResult: SettlementResult(
                requiredTotal: 1,
                requiredCompleted: 0,
                missedRequiredCount: 1,
                outcome: .fail,
                owesAmount: 50
            ),
            pendingAcknowledgementUserIds: ["usr_1", "usr_2"]
        )
        let repo = TestSettlementRepository(seed: [settlement])
        let useCase = AcknowledgeSettlementUseCase(settlementRepository: repo)

        let updated = try await useCase.execute(
            AcknowledgeSettlementRequest(coupleId: "cpl_1", settlementId: "usr_1_2026-03-08", userId: "usr_1")
        )

        XCTAssertEqual(updated.pendingAcknowledgementUserIds, ["usr_2"])
    }
}
