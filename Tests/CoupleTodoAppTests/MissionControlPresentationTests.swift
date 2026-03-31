import XCTest
@testable import CoupleTodo
import CoupleTodoCore

final class MissionControlPresentationTests: XCTestCase {
    func testHeroPrioritizesSettlementWhenAcknowledgementIsPending() {
        let snapshot = makeSnapshot(
            selfSubmittedNextPlan: false,
            latestSettlement: makeSettlement(pendingAcknowledgementUserIds: ["usr_self"]),
            pendingPayments: []
        )

        let hero = DashboardPresenter.hero(for: snapshot)

        XCTAssertEqual(hero.eyebrow, "Daily Recap")
        XCTAssertEqual(hero.title, "Check today's results")
        XCTAssertEqual(hero.primaryActionTitle, "View Results")
        XCTAssertEqual(hero.emphasis, .urgent)
    }

    func testHeroPromptsTomorrowPlanWhenPlanningIsMissing() {
        let snapshot = makeSnapshot(
            selfSubmittedNextPlan: false,
            latestSettlement: nil,
            pendingPayments: []
        )

        let hero = DashboardPresenter.hero(for: snapshot)

        XCTAssertEqual(hero.eyebrow, "Plan Tomorrow")
        XCTAssertEqual(hero.title, "What's on for tomorrow?")
        XCTAssertEqual(hero.primaryActionTitle, "Plan Now")
        XCTAssertEqual(hero.emphasis, .active)
    }

    func testHeroCelebratesWhenRewardIsEarnedAndCriticalWorkIsClear() {
        let snapshot = makeSnapshot(
            selfSubmittedNextPlan: true,
            latestSettlement: nil,
            currentRewardWeek: RewardWeek(
                id: "reward_1",
                coupleId: "cpl_1",
                weekKey: "2026-W13",
                effectiveWeekStartDate: "2026-03-23",
                draftedInWeekKey: "2026-W12",
                rewardText: "Bubble tea date night",
                status: .earned,
                eligibility: ["usr_self": true, "usr_partner": true],
                memberLocalWeekKeys: ["usr_self": "2026-W13", "usr_partner": "2026-W13"],
                finalizeWhenBothMembersWeekClosed: true,
                earnedAt: Date(),
                missedAt: nil,
                updatedAt: Date()
            ),
            pendingPayments: []
        )

        let hero = DashboardPresenter.hero(for: snapshot)

        XCTAssertEqual(hero.eyebrow, "Reward Earned")
        XCTAssertEqual(hero.title, "You did it together!")
        XCTAssertEqual(hero.primaryActionTitle, "See Reward")
        XCTAssertEqual(hero.emphasis, .success)
    }

    func testNotificationCopyUsesFriendlyLanguage() {
        XCTAssertEqual(NotificationCopy.title(for: .planningReminder), "Time to plan tomorrow")
        XCTAssertEqual(NotificationCopy.body(for: .planningEscalation), "Submit tomorrow's plan now.")
        XCTAssertEqual(NotificationCopy.actionTitle(for: .settlementReady), "View Results")
        XCTAssertEqual(NotificationCopy.actionTitle(for: .paymentPending), "Review")
    }

    private func makeSnapshot(
        selfSubmittedNextPlan: Bool,
        latestSettlement: DailySettlement?,
        currentRewardWeek: RewardWeek? = nil,
        pendingPayments: [PaymentRecord]
    ) -> DashboardSnapshot {
        DashboardSnapshot(
            user: UserProfile(
                id: "usr_self",
                displayName: "You",
                coupleId: "cpl_1",
                currentTimezone: "America/Chicago",
                currentUtcOffsetMinutes: -300,
                lastLocalDateKey: "2026-03-25",
                lastLocalWeekKey: "2026-W13",
                createdAt: Date(),
                updatedAt: Date()
            ),
            partner: UserProfile(
                id: "usr_partner",
                displayName: "Partner",
                coupleId: "cpl_1",
                currentTimezone: "Asia/Tokyo",
                currentUtcOffsetMinutes: 540,
                lastLocalDateKey: "2026-03-26",
                lastLocalWeekKey: "2026-W13",
                createdAt: Date(),
                updatedAt: Date()
            ),
            couple: Couple(
                id: "cpl_1",
                memberIds: ["usr_self", "usr_partner"],
                status: .active,
                weekStartsOn: .monday,
                penaltyPolicy: .default,
                reminderConfig: .default,
                inviteCode: "ABC123",
                createdAt: Date(),
                updatedAt: Date()
            ),
            selfContext: LocalTimeContext(
                timezoneIdentifier: "America/Chicago",
                utcOffsetMinutes: -300,
                dateKey: "2026-03-25",
                weekKey: "2026-W13"
            ),
            partnerContext: LocalTimeContext(
                timezoneIdentifier: "Asia/Tokyo",
                utcOffsetMinutes: 540,
                dateKey: "2026-03-26",
                weekKey: "2026-W13"
            ),
            selfRequired: [
                TodoTask(
                    id: "task_1",
                    ownerUserId: "usr_self",
                    dateKey: "2026-03-25",
                    localTimezone: "America/Chicago",
                    title: "Cook dinner",
                    notes: nil,
                    bucket: .required,
                    priority: .p1,
                    status: .completed,
                    sortOrder: 1000,
                    completedAtServer: Date()
                )
            ],
            selfOptional: [],
            partnerRequired: [
                TodoTask(
                    id: "task_2",
                    ownerUserId: "usr_partner",
                    dateKey: "2026-03-26",
                    localTimezone: "Asia/Tokyo",
                    title: "Take out trash",
                    notes: nil,
                    bucket: .required,
                    priority: .p1,
                    status: .pending,
                    sortOrder: 1000,
                    completedAtServer: nil
                )
            ],
            partnerOptional: [],
            selfSubmittedNextPlan: selfSubmittedNextPlan,
            partnerSubmittedNextPlan: true,
            planningTargetDateKey: "2026-03-26",
            selfPlanningCountdownMinutes: 42,
            partnerPlanningCountdownMinutes: 20,
            selfSettlementCountdownMinutes: 90,
            partnerSettlementCountdownMinutes: 50,
            latestSettlement: latestSettlement,
            currentRewardWeek: currentRewardWeek,
            pendingPayments: pendingPayments,
            pendingGate: nil
        )
    }

    private func makeSettlement(pendingAcknowledgementUserIds: [String]) -> DailySettlement {
        DailySettlement(
            id: "stl_1",
            coupleId: "cpl_1",
            subjectUserId: "usr_self",
            counterpartyUserId: "usr_partner",
            dateKey: "2026-03-25",
            localTimezone: "America/Chicago",
            localWeekKey: "2026-W13",
            state: .finalized,
            computedAt: Date(),
            graceAppliedUntil: nil,
            subjectResult: SettlementResult(
                requiredTotal: 3,
                requiredCompleted: 2,
                missedRequiredCount: 1,
                outcome: .fail,
                owesAmount: 8
            ),
            counterpartySnapshot: CounterpartySettlementSnapshot(
                latestKnownDateKey: "2026-03-26",
                latestKnownOutcome: .pass
            ),
            pendingAcknowledgementUserIds: pendingAcknowledgementUserIds,
            rewardImpact: RewardImpact(weekKey: "2026-W13", stillEligible: false)
        )
    }
}
