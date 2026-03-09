import XCTest
@testable import CoupleTodoCore

final class LoadDashboardUseCaseTests: XCTestCase {
    func testExecuteBuildsCrossTimezoneSnapshotAndSettlementGate() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T14:30:00Z"))
        let user = UserProfile(
            id: "usr_1",
            displayName: "W",
            currentTimezone: "America/Chicago",
            currentUtcOffsetMinutes: -360,
            lastLocalDateKey: "2026-03-08",
            lastLocalWeekKey: "2026-W10",
            createdAt: now,
            updatedAt: now
        )
        let partner = UserProfile(
            id: "usr_2",
            displayName: "P",
            currentTimezone: "Asia/Tokyo",
            currentUtcOffsetMinutes: 540,
            lastLocalDateKey: "2026-03-08",
            lastLocalWeekKey: "2026-W10",
            createdAt: now,
            updatedAt: now
        )
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
        let settlement = DailySettlement(
            id: "usr_1_2026-03-08",
            coupleId: "cpl_1",
            subjectUserId: "usr_1",
            counterpartyUserId: "usr_2",
            dateKey: "2026-03-08",
            localTimezone: "America/Chicago",
            localWeekKey: "2026-W10",
            state: .finalized,
            computedAt: now,
            graceAppliedUntil: now,
            subjectResult: SettlementResult(
                requiredTotal: 2,
                requiredCompleted: 1,
                missedRequiredCount: 1,
                outcome: .fail,
                owesAmount: 50
            ),
            pendingAcknowledgementUserIds: ["usr_1", "usr_2"]
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

        let useCase = LoadDashboardUseCase(
            userRepository: TestUserRepository(seed: [user, partner]),
            coupleRepository: TestCoupleRepository(seed: [couple]),
            planRepository: TestPlanRepository(seed: [
                DailyPlan(
                    id: "usr_2_2026-03-10",
                    userId: "usr_2",
                    coupleId: "cpl_1",
                    dateKey: "2026-03-10",
                    localTimezone: "Asia/Tokyo",
                    submittedAt: now,
                    planningMissed: false
                )
            ]),
            taskRepository: TestTaskRepository(seed: [
                "usr_1_2026-03-08": [
                    makeDashboardTask(id: "self_required", ownerUserId: "usr_1", dateKey: "2026-03-08", localTimezone: "America/Chicago", title: "Workout", bucket: .required)
                ],
                "usr_2_2026-03-08": [],
                "usr_2_2026-03-09": [
                    makeDashboardTask(id: "partner_required", ownerUserId: "usr_2", dateKey: "2026-03-09", localTimezone: "Asia/Tokyo", title: "Call doctor", bucket: .required)
                ]
            ]),
            settlementRepository: TestSettlementRepository(seed: [settlement]),
            rewardWeekRepository: TestRewardWeekRepository(seed: [rewardWeek])
        )

        let snapshot = try await useCase.execute(LoadDashboardRequest(userId: "usr_1", now: now))

        XCTAssertEqual(snapshot.selfContext.dateKey, "2026-03-08")
        XCTAssertEqual(snapshot.partnerContext.dateKey, "2026-03-08")
        XCTAssertEqual(snapshot.selfRequired.map(\.id), ["self_required"])
        XCTAssertEqual(snapshot.latestSettlement?.id, "usr_1_2026-03-08")
        XCTAssertEqual(snapshot.currentRewardWeek?.rewardText, "Date night")
        XCTAssertEqual(snapshot.pendingGate, .settlement(dateKey: "2026-03-08"))
    }
}

private func makeDashboardTask(
    id: String,
    ownerUserId: String,
    dateKey: String,
    localTimezone: String,
    title: String,
    bucket: TaskBucket
) -> TodoTask {
    TodoTask(
        id: id,
        ownerUserId: ownerUserId,
        dateKey: dateKey,
        localTimezone: localTimezone,
        title: title,
        notes: nil,
        bucket: bucket,
        priority: .p0,
        status: .pending,
        sortOrder: 1,
        completedAtServer: nil
    )
}
