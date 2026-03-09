import XCTest
@testable import CoupleTodoCore

final class CoupleLifecycleUseCasesTests: XCTestCase {
    func testCreateAndJoinCoupleUpdatesMembership() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T12:00:00Z"))
        let userRepo = TestUserRepository(seed: [
            UserProfile(
                id: "usr_1",
                displayName: "W",
                currentTimezone: "UTC",
                currentUtcOffsetMinutes: 0,
                lastLocalDateKey: "2026-03-08",
                lastLocalWeekKey: "2026-W10",
                createdAt: now,
                updatedAt: now
            ),
            UserProfile(
                id: "usr_2",
                displayName: "P",
                currentTimezone: "UTC",
                currentUtcOffsetMinutes: 0,
                lastLocalDateKey: "2026-03-08",
                lastLocalWeekKey: "2026-W10",
                createdAt: now,
                updatedAt: now
            )
        ])
        let coupleRepo = TestCoupleRepository()

        let createResult = try await CreateCoupleUseCase(
            userRepository: userRepo,
            coupleRepository: coupleRepo
        ).execute(CreateCoupleRequest(creatorUserId: "usr_1", now: now))

        XCTAssertEqual(createResult.couple.memberIds, ["usr_1"])
        XCTAssertEqual(createResult.couple.status, .pending)

        let joinedCouple = try await JoinCoupleUseCase(
            userRepository: userRepo,
            coupleRepository: coupleRepo
        ).execute(
            JoinCoupleRequest(userId: "usr_2", inviteCode: createResult.inviteCode, now: now)
        )

        XCTAssertEqual(joinedCouple.memberIds.sorted(), ["usr_1", "usr_2"])
        XCTAssertEqual(joinedCouple.status, .active)
    }
}
