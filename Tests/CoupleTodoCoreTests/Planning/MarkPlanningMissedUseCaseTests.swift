import XCTest
@testable import CoupleTodoCore

final class MarkPlanningMissedUseCaseTests: XCTestCase {
    func testExecuteMarksPlanMissedAndAppendsEvent() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T23:30:00Z"))
        let planRepository = TestPlanRepository()
        let eventRepository = TestEventRepository()
        let useCase = MarkPlanningMissedUseCase(planRepository: planRepository, eventRepository: eventRepository)

        let updated = try await useCase.execute(
            MarkPlanningMissedRequest(
                userId: "usr_1",
                coupleId: "cpl_1",
                dateKey: "2026-03-09",
                timezone: .init(identifier: "UTC") ?? .current,
                now: now
            )
        )

        XCTAssertTrue(updated.planningMissed)
        XCTAssertEqual(updated.version, 2)
        let events = try await eventRepository.fetchEvents(coupleId: "cpl_1", limit: 10)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.type, .planningMissed)
    }

    func testExecuteIsIdempotentWhenPlanAlreadyMarkedMissed() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T23:30:00Z"))
        let existingPlan = DailyPlan(
            id: "usr_1_2026-03-09",
            userId: "usr_1",
            coupleId: "cpl_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            submittedAt: nil,
            planningMissed: true,
            version: 4
        )
        let seedEvent = EventLogEntry(
            id: "evt_1",
            coupleId: "cpl_1",
            type: .planningMissed,
            actorUserId: "usr_1",
            subjectId: existingPlan.id,
            createdAt: now
        )
        let planRepository = TestPlanRepository(seed: [existingPlan])
        let eventRepository = TestEventRepository(seed: [seedEvent])
        let useCase = MarkPlanningMissedUseCase(planRepository: planRepository, eventRepository: eventRepository)

        let updated = try await useCase.execute(
            MarkPlanningMissedRequest(
                userId: "usr_1",
                coupleId: "cpl_1",
                dateKey: "2026-03-09",
                timezone: .init(identifier: "UTC") ?? .current,
                now: now
            )
        )

        XCTAssertEqual(updated.version, 4)
        XCTAssertTrue(updated.planningMissed)
        let events = try await eventRepository.fetchEvents(coupleId: "cpl_1", limit: 10)
        XCTAssertEqual(events.count, 1)
    }
}
