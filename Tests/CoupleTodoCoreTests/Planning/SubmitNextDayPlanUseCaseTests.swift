import XCTest
@testable import CoupleTodoCore

final class SubmitNextDayPlanUseCaseTests: XCTestCase {
    func testExecuteStoresPlanAndTasksForNextLocalDay() async throws {
        let planRepo = InMemoryPlanRepository()
        let taskRepo = InMemoryTaskRepository()
        let useCase = SubmitNextDayPlanUseCase(planRepository: planRepo, taskRepository: taskRepo)

        let timezone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T14:30:00Z"))
        let submittedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T14:31:00Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: submittedAt,
            now: now,
            timezone: timezone,
            tasks: [
                TodoTask(
                    id: "task_2",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-09",
                    localTimezone: "Asia/Tokyo",
                    title: "optional item",
                    notes: nil,
                    bucket: .optional,
                    priority: .p0,
                    status: .pending,
                    sortOrder: 1,
                    completedAtServer: nil
                ),
                TodoTask(
                    id: "task_1",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-09",
                    localTimezone: "Asia/Tokyo",
                    title: "required item",
                    notes: nil,
                    bucket: .required,
                    priority: .p1,
                    status: .pending,
                    sortOrder: 20,
                    completedAtServer: nil
                )
            ],
            noRequiredTasksConfirmed: false
        )

        let plan = try await useCase.execute(request)

        XCTAssertEqual(plan.id, "usr_1_2026-03-09")
        XCTAssertEqual(plan.dateKey, "2026-03-09")
        XCTAssertEqual(plan.localTimezone, "Asia/Tokyo")

        let savedPlan = try await planRepo.fetchPlan(userId: "usr_1", dateKey: "2026-03-09")
        XCTAssertEqual(savedPlan?.dateKey, "2026-03-09")

        let savedTasks = try await taskRepo.fetchTasks(userId: "usr_1", dateKey: "2026-03-09")
        XCTAssertEqual(savedTasks.map(\.id), ["task_1", "task_2"])
    }

    func testExecuteRejectsEmptyTasksWithoutConfirmation() async throws {
        let useCase = SubmitNextDayPlanUseCase(planRepository: InMemoryPlanRepository(), taskRepository: InMemoryTaskRepository())
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T21:00:00Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: now,
            now: now,
            timezone: timezone,
            tasks: [],
            noRequiredTasksConfirmed: false
        )

        do {
            _ = try await useCase.execute(request)
            XCTFail("Expected validation error")
        } catch let error as SubmitNextDayPlanError {
            XCTAssertEqual(error, .emptyTasksWithoutConfirmation)
        }
    }

    func testExecuteRejectsWrongDateKey() async throws {
        let useCase = SubmitNextDayPlanUseCase(planRepository: InMemoryPlanRepository(), taskRepository: InMemoryTaskRepository())
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T21:00:00Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: now,
            now: now,
            timezone: timezone,
            tasks: [
                TodoTask(
                    id: "task_1",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-10",
                    localTimezone: "UTC",
                    title: "wrong date",
                    notes: nil,
                    bucket: .required,
                    priority: .p0,
                    status: .pending,
                    sortOrder: 1,
                    completedAtServer: nil
                )
            ],
            noRequiredTasksConfirmed: false
        )

        do {
            _ = try await useCase.execute(request)
            XCTFail("Expected date mismatch error")
        } catch let error as SubmitNextDayPlanError {
            XCTAssertEqual(error, .taskDateKeyMismatch(expected: "2026-03-09", actual: "2026-03-10"))
        }
    }
}

private actor InMemoryPlanRepository: PlanRepository {
    private var storage: [String: DailyPlan] = [:]

    func upsertPlan(_ plan: DailyPlan) async throws {
        storage[plan.id] = plan
    }

    func fetchPlan(userId: String, dateKey: String) async throws -> DailyPlan? {
        storage["\(userId)_\(dateKey)"]
    }
}

private actor InMemoryTaskRepository: TaskRepository {
    private var storage: [String: [TodoTask]] = [:]

    func replaceTasks(for userId: String, dateKey: String, tasks: [TodoTask]) async throws {
        storage["\(userId)_\(dateKey)"] = tasks
    }

    func fetchTasks(userId: String, dateKey: String) async throws -> [TodoTask] {
        storage["\(userId)_\(dateKey)"] ?? []
    }
}
