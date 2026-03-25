import XCTest
@testable import CoupleTodoFirebase
import CoupleTodoCore

final class FirestoreDocumentTests: XCTestCase {
    func testUserProfilePayloadPreservesCoupleIdForRuleSafeUpdates() {
        let user = UserProfile(
            id: "usr_1",
            displayName: "Alex",
            photoURL: "https://example.com/avatar.png",
            coupleId: "cpl_1",
            currentTimezone: "UTC",
            currentUtcOffsetMinutes: 0,
            lastLocalDateKey: "2026-03-24",
            lastLocalWeekKey: "2026-W13",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let payload = UserProfileDocument.clientPayload(from: user)

        XCTAssertEqual(payload["coupleId"] as? String, "cpl_1")
    }

    func testUserProfileUpdatePayloadDoesNotRewriteCreatedAt() {
        let user = UserProfile(
            id: "usr_1",
            displayName: "Alex",
            photoURL: nil,
            coupleId: "cpl_1",
            currentTimezone: "UTC",
            currentUtcOffsetMinutes: 0,
            lastLocalDateKey: "2026-03-24",
            lastLocalWeekKey: "2026-W13",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let updatePayload = UserProfileDocument.clientPayload(from: user, includeCreatedAt: false)

        XCTAssertNil(updatePayload["createdAt"])
        XCTAssertEqual(updatePayload["coupleId"] as? String, "cpl_1")
    }

    func testCoupleSettingsPayloadOnlyContainsClientWritableFields() {
        let couple = Couple(
            id: "cpl_1",
            memberIds: ["usr_1", "usr_2"],
            status: .active,
            weekStartsOn: .monday,
            penaltyPolicy: .default,
            reminderConfig: .default,
            inviteCode: "ABC123",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let payload = CoupleDocument.clientSettingsPayload(from: couple)

        XCTAssertEqual(Set(payload.keys), Set(["weekStartsOn", "penaltyPolicy", "reminderConfig", "updatedAt"]))
        XCTAssertNil(payload["memberIds"])
        XCTAssertNil(payload["inviteCode"])
        XCTAssertNil(payload["status"])
    }

    func testTaskClientPayloadDoesNotSendServerOwnedCompletionTimestamp() {
        let task = TodoTask(
            id: "task_1",
            ownerUserId: "usr_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            title: "Workout",
            notes: "30 mins",
            bucket: .required,
            priority: .p0,
            status: .completed,
            sortOrder: 1000,
            completedAtServer: Date(),
            completedAtClient: Date()
        )

        let payload = TodoTaskDocument.clientPayload(from: task)

        XCTAssertNil(payload["completedAtServer"])
        XCTAssertEqual(payload["ownerUserId"] as? String, "usr_1")
        XCTAssertEqual(payload["status"] as? String, TaskStatus.completed.rawValue)
    }

    func testTaskUpdatePayloadDoesNotRewriteCreatedAt() {
        let task = TodoTask(
            id: "task_1",
            ownerUserId: "usr_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            title: "Workout",
            notes: nil,
            bucket: .required,
            priority: .p0,
            status: .pending,
            sortOrder: 1000,
            completedAtServer: nil,
            localUtcOffsetMinutes: 0,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        let payload = TodoTaskDocument.clientPayload(from: task, includeCreatedAt: false)

        XCTAssertNil(payload["createdAt"])
        XCTAssertEqual(payload["ownerUserId"] as? String, "usr_1")
        XCTAssertEqual(payload["status"] as? String, TaskStatus.pending.rawValue)
    }

    func testPaymentStatusPayloadsOnlyTouchAllowedClientFields() {
        let paidPayload = PaymentRecordDocument.markPaidPayload(
            actorUserId: "usr_debtor",
            paidAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(Set(paidPayload.keys.map { "\($0)" }), Set(["markedPaidAt", "markedByUserId", "updatedAt"]))

        let acknowledgedPayload = PaymentRecordDocument.resolveStatusPayload(
            status: .acknowledged,
            actorUserId: "usr_creditor",
            resolvedAt: Date(timeIntervalSince1970: 200)
        )
        XCTAssertEqual(acknowledgedPayload["status"] as? String, PaymentStatus.acknowledged.rawValue)
        XCTAssertEqual(acknowledgedPayload["acknowledgedByUserId"] as? String, "usr_creditor")
        XCTAssertNotNil(acknowledgedPayload["acknowledgedAt"])
        XCTAssertNotNil(acknowledgedPayload["disputedAt"])
    }

    func testFirestorePathBuildersMatchNestedSchema() {
        XCTAssertEqual(FirestorePaths.userDocument("usr_1"), "users/usr_1")
        XCTAssertEqual(
            FirestorePaths.taskDocument(coupleId: "cpl_1", planId: "usr_1_2026-03-09", taskId: "task_1"),
            "couples/cpl_1/plans/usr_1_2026-03-09/tasks/task_1"
        )
        XCTAssertEqual(
            FirestorePaths.paymentDocument(coupleId: "cpl_1", recordId: "pay_1"),
            "couples/cpl_1/payments/pay_1"
        )
    }
}
