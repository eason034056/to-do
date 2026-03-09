import XCTest
@testable import CoupleTodoCore

final class TaskMutationUseCasesTests: XCTestCase {
    func testCreateTaskStoresTaskAndEvent() async throws {
        let taskRepository = TestTaskRepository()
        let eventRepository = TestEventRepository()
        let useCase = CreateTaskUseCase(taskRepository: taskRepository, eventRepository: eventRepository)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T03:00:00Z"))

        let task = TodoTask(
            id: "task_1",
            ownerUserId: "usr_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            title: "Write tests",
            notes: "Add task mutation coverage",
            bucket: .required,
            priority: .p1,
            status: .pending,
            sortOrder: 1000,
            completedAtServer: nil
        )

        let created = try await useCase.execute(
            CreateTaskRequest(
                actorUserId: "usr_1",
                coupleId: "cpl_1",
                task: task,
                now: now
            )
        )

        let stored = try await taskRepository.fetchTasks(userId: "usr_1", dateKey: "2026-03-09")
        XCTAssertEqual(stored, [created])
        XCTAssertEqual(created.syncState, .localPending)

        let events = try await eventRepository.fetchEvents(coupleId: "cpl_1", limit: 10)
        XCTAssertEqual(events.last?.type, .taskCreated)
    }

    func testUpdateTaskRejectsCrossUserMutation() async throws {
        let taskRepository = TestTaskRepository()
        let eventRepository = TestEventRepository()
        let useCase = UpdateTaskUseCase(taskRepository: taskRepository, eventRepository: eventRepository)

        let task = TodoTask(
            id: "task_1",
            ownerUserId: "usr_owner",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            title: "Private task",
            notes: nil,
            bucket: .required,
            priority: .p0,
            status: .pending,
            sortOrder: 1000,
            completedAtServer: nil
        )

        do {
            _ = try await useCase.execute(
                UpdateTaskRequest(
                    actorUserId: "usr_other",
                    coupleId: "cpl_1",
                    task: task,
                    now: Date()
                )
            )
            XCTFail("Expected cross-user update to fail.")
        } catch {
            XCTAssertEqual(error as? TaskMutationError, .taskBelongsToAnotherUser)
        }
    }

    func testToggleTaskCompletionMarksClientTimestamp() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T04:00:00Z"))
        let task = TodoTask(
            id: "task_1",
            ownerUserId: "usr_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            title: "Finish dashboard wiring",
            notes: nil,
            bucket: .required,
            priority: .p1,
            status: .pending,
            sortOrder: 1000,
            completedAtServer: nil
        )

        let taskRepository = TestTaskRepository(seed: ["usr_1_2026-03-09": [task]])
        let eventRepository = TestEventRepository()
        let useCase = ToggleTaskCompletionUseCase(taskRepository: taskRepository, eventRepository: eventRepository)

        let updated = try await useCase.execute(
            ToggleTaskCompletionRequest(
                actorUserId: "usr_1",
                coupleId: "cpl_1",
                taskId: "task_1",
                dateKey: "2026-03-09",
                completed: true,
                now: now
            )
        )

        XCTAssertEqual(updated.status, .completed)
        XCTAssertEqual(updated.completedAtClient, now)

        let events = try await eventRepository.fetchEvents(coupleId: "cpl_1", limit: 10)
        XCTAssertEqual(events.last?.type, .taskCompleted)
    }

    func testDeleteTaskRemovesStoredTask() async throws {
        let task = TodoTask(
            id: "task_1",
            ownerUserId: "usr_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            title: "Delete me",
            notes: nil,
            bucket: .optional,
            priority: .p3,
            status: .pending,
            sortOrder: 1000,
            completedAtServer: nil
        )

        let taskRepository = TestTaskRepository(seed: ["usr_1_2026-03-09": [task]])
        let eventRepository = TestEventRepository()
        let useCase = DeleteTaskUseCase(taskRepository: taskRepository, eventRepository: eventRepository)

        try await useCase.execute(
            DeleteTaskRequest(
                actorUserId: "usr_1",
                coupleId: "cpl_1",
                taskId: "task_1",
                ownerUserId: "usr_1",
                dateKey: "2026-03-09",
                now: Date()
            )
        )

        let stored = try await taskRepository.fetchTasks(userId: "usr_1", dateKey: "2026-03-09")
        XCTAssertTrue(stored.isEmpty)
    }

    func testReorderTasksUpdatesSortOrderInProvidedSequence() async throws {
        let taskA = TodoTask(
            id: "task_a",
            ownerUserId: "usr_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            title: "A",
            notes: nil,
            bucket: .required,
            priority: .p1,
            status: .pending,
            sortOrder: 1000,
            completedAtServer: nil
        )
        let taskB = TodoTask(
            id: "task_b",
            ownerUserId: "usr_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            title: "B",
            notes: nil,
            bucket: .required,
            priority: .p1,
            status: .pending,
            sortOrder: 2000,
            completedAtServer: nil
        )

        let taskRepository = TestTaskRepository(seed: ["usr_1_2026-03-09": [taskA, taskB]])
        let eventRepository = TestEventRepository()
        let useCase = ReorderTasksUseCase(taskRepository: taskRepository, eventRepository: eventRepository)

        try await useCase.execute(
            ReorderTasksRequest(
                actorUserId: "usr_1",
                coupleId: "cpl_1",
                dateKey: "2026-03-09",
                orderedTaskIds: ["task_b", "task_a"],
                now: Date()
            )
        )

        let stored = try await taskRepository.fetchTasks(userId: "usr_1", dateKey: "2026-03-09")
        XCTAssertEqual(stored.map(\.id), ["task_b", "task_a"])
        XCTAssertEqual(stored.map(\.sortOrder), [1000, 2000])
    }
}
