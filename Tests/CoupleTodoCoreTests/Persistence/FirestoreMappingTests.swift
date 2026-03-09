import XCTest
@testable import CoupleTodoCore

final class FirestoreMappingTests: XCTestCase {
    func testUserProfileRoundTripsThroughFirestoreDTO() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T06:00:00Z"))
        let user = UserProfile(
            id: "usr_1",
            displayName: "W",
            photoURL: "https://example.com/avatar.png",
            coupleId: "cpl_1",
            currentTimezone: "America/Chicago",
            currentUtcOffsetMinutes: -360,
            lastLocalDateKey: "2026-03-09",
            lastLocalWeekKey: "2026-W11",
            notificationPreferences: NotificationPreferences(
                planningReminderEnabled: true,
                settlementReminderEnabled: false,
                timeSensitiveAllowed: true
            ),
            createdAt: now,
            updatedAt: now
        )

        let payload = FirestoreUserProfileDTO.writePayload(from: user)
        let roundTrip = try payload.document.toDomain(id: user.id)

        XCTAssertEqual(payload.serverTimestampFields, [])
        XCTAssertEqual(roundTrip, user)
    }

    func testPlanWritePayloadMarksServerTimestampFields() {
        let now = Date(timeIntervalSince1970: 1_773_002_400)
        let plan = DailyPlan(
            id: "usr_1_2026-03-10",
            userId: "usr_1",
            coupleId: "cpl_1",
            dateKey: "2026-03-10",
            localTimezone: "America/Chicago",
            submittedAt: now,
            planningMissed: false,
            localUtcOffsetMinutes: -360,
            lastEditedAt: now,
            requiredCount: 2,
            optionalCount: 1,
            version: 3
        )

        let payload = FirestorePlanDTO.writePayload(
            from: plan,
            timestampStrategy: .preferServerTimestamps
        )

        XCTAssertNil(payload.document.submittedAt)
        XCTAssertNil(payload.document.lastEditedAt)
        XCTAssertEqual(payload.serverTimestampFields, ["lastEditedAt", "submittedAt"])
    }

    func testSettlementRoundTripsNestedValues() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T07:00:00Z"))
        let settlement = DailySettlement(
            id: "usr_1_2026-03-09",
            coupleId: "cpl_1",
            subjectUserId: "usr_1",
            counterpartyUserId: "usr_2",
            dateKey: "2026-03-09",
            localTimezone: "America/Chicago",
            localWeekKey: "2026-W11",
            state: .finalized,
            computedAt: now,
            graceAppliedUntil: now.addingTimeInterval(300),
            subjectResult: SettlementResult(
                requiredTotal: 3,
                requiredCompleted: 2,
                missedRequiredCount: 1,
                outcome: .fail,
                owesAmount: 12.5
            ),
            counterpartySnapshot: CounterpartySettlementSnapshot(
                latestKnownDateKey: "2026-03-09",
                latestKnownOutcome: .pass
            ),
            pendingAcknowledgementUserIds: ["usr_1"],
            rewardImpact: RewardImpact(weekKey: "2026-W11", stillEligible: false)
        )

        let payload = FirestoreSettlementDTO.writePayload(from: settlement)
        let roundTrip = try payload.document.toDomain(documentId: settlement.id)

        XCTAssertEqual(roundTrip, settlement)
    }

    func testRewardWeekRoundTripsFinalizeFlag() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T08:00:00Z"))
        let rewardWeek = RewardWeek(
            id: "cpl_1_2026-W12",
            coupleId: "cpl_1",
            weekKey: "2026-W12",
            effectiveWeekStartDate: "2026-03-16",
            draftedInWeekKey: "2026-W11",
            rewardText: "Weekend brunch",
            status: .active,
            eligibility: ["usr_1": true, "usr_2": false],
            memberLocalWeekKeys: ["usr_1": "2026-W11", "usr_2": "2026-W11"],
            finalizeWhenBothMembersWeekClosed: true,
            earnedAt: nil,
            missedAt: nil,
            updatedAt: now
        )

        let payload = FirestoreRewardWeekDTO.writePayload(from: rewardWeek)
        let roundTrip = try payload.document.toDomain()

        XCTAssertEqual(roundTrip, rewardWeek)
    }

    func testFirestorePathsMatchSchemaLayout() {
        XCTAssertEqual(FirestorePath.user("usr_1"), "users/usr_1")
        XCTAssertEqual(FirestorePath.deviceInstallation("dev_1"), "deviceInstallations/dev_1")
        XCTAssertEqual(FirestorePath.invite("demo42"), "invites/DEMO42")
        XCTAssertEqual(
            FirestorePath.plan(coupleId: "cpl_1", userId: "usr_1", dateKey: "2026-03-10"),
            "couples/cpl_1/plans/usr_1_2026-03-10"
        )
        XCTAssertEqual(
            FirestorePath.task(coupleId: "cpl_1", userId: "usr_1", dateKey: "2026-03-10", taskId: "task_1"),
            "couples/cpl_1/plans/usr_1_2026-03-10/tasks/task_1"
        )
        XCTAssertEqual(
            FirestorePath.settlement(coupleId: "cpl_1", subjectUserId: "usr_1", dateKey: "2026-03-10"),
            "couples/cpl_1/settlements/usr_1_2026-03-10"
        )
        XCTAssertEqual(
            FirestorePath.rewardWeek(coupleId: "cpl_1", weekKey: "2026-W12"),
            "couples/cpl_1/rewardWeeks/2026-W12"
        )
        XCTAssertEqual(
            FirestorePath.event(coupleId: "cpl_1", eventId: "evt_1"),
            "couples/cpl_1/events/evt_1"
        )
    }
}
