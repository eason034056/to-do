import XCTest
@testable import CoupleTodoCore

final class LoadDashboardUseCaseTests: XCTestCase {
    func testExecuteBuildsCrossTimezoneSnapshotAndSettlementGate() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T14:30:00Z"))
        let user = UserProfile(
            id: "usr_1",
            displayName: "W",
            coupleId: "cpl_1",
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
            coupleId: "cpl_1",
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
        let pendingPayment = PaymentRecord(
            id: "pay_1",
            coupleId: "cpl_1",
            debtorUserId: "usr_1",
            creditorUserId: "usr_2",
            sourceSettlementId: "usr_1_2026-03-08",
            sourceDateKey: "2026-03-08",
            amount: 50,
            currency: "USD",
            status: .pending,
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
                    makeDashboardTask(
                        id: "self_required",
                        ownerUserId: "usr_1",
                        dateKey: "2026-03-08",
                        localTimezone: "America/Chicago",
                        title: "Workout",
                        bucket: .required,
                        syncState: .localPending
                    )
                ],
                "usr_2_2026-03-08": [
                    makeDashboardTask(
                        id: "partner_required",
                        ownerUserId: "usr_2",
                        dateKey: "2026-03-08",
                        localTimezone: "Asia/Tokyo",
                        title: "Call doctor",
                        bucket: .required,
                        syncState: .localPending
                    )
                ]
            ]),
            settlementRepository: TestSettlementRepository(seed: [settlement]),
            rewardWeekRepository: TestRewardWeekRepository(seed: [rewardWeek]),
            paymentRepository: TestPaymentRepository(seed: [pendingPayment])
        )

        let snapshot = try await useCase.execute(LoadDashboardRequest(userId: "usr_1", now: now))

        XCTAssertEqual(snapshot.selfContext.dateKey, "2026-03-08")
        XCTAssertEqual(snapshot.partnerContext.dateKey, "2026-03-08")
        XCTAssertEqual(snapshot.selfRequired.map(\.id), ["self_required"])
        XCTAssertEqual(snapshot.selfRequired.map(\.syncState), [.serverFinal])
        XCTAssertEqual(snapshot.partnerRequired.map(\.syncState), [.synced])
        XCTAssertEqual(snapshot.latestSettlement?.id, "usr_1_2026-03-08")
        XCTAssertEqual(snapshot.currentRewardWeek?.rewardText, "Date night")
        XCTAssertEqual(snapshot.pendingPayments.map(\.id), ["pay_1"])
        XCTAssertGreaterThan(snapshot.selfPlanningCountdownMinutes, 0)
        XCTAssertGreaterThan(snapshot.selfSettlementCountdownMinutes, 0)
        XCTAssertGreaterThan(snapshot.partnerPlanningCountdownMinutes, 0)
        XCTAssertGreaterThan(snapshot.partnerSettlementCountdownMinutes, 0)
        XCTAssertEqual(snapshot.pendingGate, .settlement(dateKey: "2026-03-08"))
    }

    func testExecuteThrowsCoupleNotFoundWhenUserHasNoCoupleMembership() async throws {
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
        let useCase = LoadDashboardUseCase(
            userRepository: TestUserRepository(seed: [user]),
            coupleRepository: TestCoupleRepository(),
            planRepository: TestPlanRepository(),
            taskRepository: TestTaskRepository(),
            settlementRepository: TestSettlementRepository(),
            rewardWeekRepository: TestRewardWeekRepository(),
            paymentRepository: TestPaymentRepository()
        )

        do {
            _ = try await useCase.execute(LoadDashboardRequest(userId: "usr_1", now: now))
            XCTFail("Expected missing couple error")
        } catch let error as LoadDashboardError {
            XCTAssertEqual(error, .coupleNotFound)
        }
    }

    func testExecuteComputesCountdownWithReminderAndSettlementGrace() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))
        let user = UserProfile(
            id: "usr_1",
            displayName: "W",
            coupleId: "cpl_1",
            currentTimezone: "UTC",
            currentUtcOffsetMinutes: 0,
            lastLocalDateKey: "2026-03-08",
            lastLocalWeekKey: "2026-W10",
            createdAt: now,
            updatedAt: now
        )
        let partner = UserProfile(
            id: "usr_2",
            displayName: "P",
            coupleId: "cpl_1",
            currentTimezone: "UTC",
            currentUtcOffsetMinutes: 0,
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

        let useCase = LoadDashboardUseCase(
            userRepository: TestUserRepository(seed: [user, partner]),
            coupleRepository: TestCoupleRepository(seed: [couple]),
            planRepository: TestPlanRepository(),
            taskRepository: TestTaskRepository(),
            settlementRepository: TestSettlementRepository(),
            rewardWeekRepository: TestRewardWeekRepository(),
            paymentRepository: TestPaymentRepository()
        )

        let snapshot = try await useCase.execute(LoadDashboardRequest(userId: "usr_1", now: now))

        XCTAssertEqual(snapshot.selfPlanningCountdownMinutes, 1_410)
        XCTAssertEqual(snapshot.selfSettlementCountdownMinutes, 124)
        XCTAssertEqual(snapshot.partnerPlanningCountdownMinutes, 1_410)
        XCTAssertEqual(snapshot.partnerSettlementCountdownMinutes, 124)
    }
}

private func makeDashboardTask(
    id: String,
    ownerUserId: String,
    dateKey: String,
    localTimezone: String,
    title: String,
    bucket: TaskBucket,
    syncState: SyncState = .synced
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
        completedAtServer: nil,
        syncState: syncState
    )
}
