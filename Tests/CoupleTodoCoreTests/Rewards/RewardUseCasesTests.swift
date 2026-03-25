import XCTest
@testable import CoupleTodoCore

final class RewardUseCasesTests: XCTestCase {
    func testSaveNextWeekRewardCreatesDraftForNextWeek() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))
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
        let rewardRepo = TestRewardWeekRepository()
        let eventRepo = TestEventRepository()
        let useCase = SaveNextWeekRewardUseCase(
            coupleRepository: TestCoupleRepository(seed: [couple]),
            rewardWeekRepository: rewardRepo,
            eventRepository: eventRepo
        )
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))

        let rewardWeek = try await useCase.execute(
            SaveNextWeekRewardRequest(
                coupleId: "cpl_1",
                actorUserId: "usr_1",
                rewardText: "Weekend brunch",
                now: now,
                timezone: timezone
            )
        )

        XCTAssertEqual(rewardWeek.weekKey, "2026-W11")
        XCTAssertEqual(rewardWeek.rewardText, "Weekend brunch")
        XCTAssertEqual(rewardWeek.status, .draft)

        let stored = try await rewardRepo.fetchRewardWeek(coupleId: "cpl_1", weekKey: "2026-W11")
        XCTAssertEqual(stored?.rewardText, "Weekend brunch")

        let events = try await eventRepo.fetchEvents(coupleId: "cpl_1", limit: 10)
        XCTAssertEqual(events.last?.type, .weeklyRewardDrafted)
    }

    func testSaveNextWeekRewardRejectsActorOutsideCouple() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))
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
        let useCase = SaveNextWeekRewardUseCase(
            coupleRepository: TestCoupleRepository(seed: [couple]),
            rewardWeekRepository: TestRewardWeekRepository(),
            eventRepository: TestEventRepository()
        )
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))

        do {
            _ = try await useCase.execute(
                SaveNextWeekRewardRequest(
                    coupleId: "cpl_1",
                    actorUserId: "usr_3",
                    rewardText: "Unauthorized draft",
                    now: now,
                    timezone: timezone
                )
            )
            XCTFail("Expected forbidden error")
        } catch let error as SaveNextWeekRewardError {
            XCTAssertEqual(error, .forbidden)
        }
    }

    func testSaveNextWeekRewardRejectsLockedNextWeekReward() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))
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
        let lockedNextWeek = RewardWeek(
            id: "cpl_1_2026-W11",
            coupleId: "cpl_1",
            weekKey: "2026-W11",
            effectiveWeekStartDate: "2026-03-09",
            draftedInWeekKey: "2026-W10",
            rewardText: "Locked",
            status: .active,
            eligibility: ["usr_1": true, "usr_2": true],
            memberLocalWeekKeys: [:],
            updatedAt: now
        )
        let useCase = SaveNextWeekRewardUseCase(
            coupleRepository: TestCoupleRepository(seed: [couple]),
            rewardWeekRepository: TestRewardWeekRepository(seed: [lockedNextWeek]),
            eventRepository: TestEventRepository()
        )
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))

        do {
            _ = try await useCase.execute(
                SaveNextWeekRewardRequest(
                    coupleId: "cpl_1",
                    actorUserId: "usr_1",
                    rewardText: "Try overwrite lock",
                    now: now,
                    timezone: timezone
                )
            )
            XCTFail("Expected reward lock error")
        } catch let error as SaveNextWeekRewardError {
            XCTAssertEqual(error, .rewardLocked)
        }
    }
}
