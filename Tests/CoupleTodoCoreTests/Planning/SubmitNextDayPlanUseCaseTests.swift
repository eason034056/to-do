import XCTest
@testable import CoupleTodoCore

final class SubmitNextDayPlanUseCaseTests: XCTestCase {
    func testExecuteStoresPlanAndTasksForNextLocalDay() async throws {
        let planRepo = TestPlanRepository()
        let taskRepo = TestTaskRepository()
        let useCase = SubmitNextDayPlanUseCase(planRepository: planRepo, taskRepository: taskRepo)

        let timezone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T12:30:00Z"))
        let submittedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T12:31:00Z"))

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
        let useCase = SubmitNextDayPlanUseCase(planRepository: TestPlanRepository(), taskRepository: TestTaskRepository())
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))

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
            XCTAssertEqual(error, .emptyTasks)
        }
    }

    func testExecuteRejectsWrongDateKey() async throws {
        let useCase = SubmitNextDayPlanUseCase(planRepository: TestPlanRepository(), taskRepository: TestTaskRepository())
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: now,
            now: now,
            timezone: timezone,
            tasks: [
                makeTask(
                    id: "task_1",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-10",
                    localTimezone: "UTC",
                    title: "wrong date",
                    bucket: .required
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

    func testExecuteRejectsOptionalOnlyTasksWithoutConfirmation() async throws {
        let useCase = SubmitNextDayPlanUseCase(planRepository: TestPlanRepository(), taskRepository: TestTaskRepository())
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: now,
            now: now,
            timezone: timezone,
            tasks: [
                makeTask(
                    id: "task_optional",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-09",
                    localTimezone: "UTC",
                    title: "optional only",
                    bucket: .optional
                )
            ],
            noRequiredTasksConfirmed: false
        )

        do {
            _ = try await useCase.execute(request)
            XCTFail("Expected validation error")
        } catch let error as SubmitNextDayPlanError {
            XCTAssertEqual(error, .missingRequiredTaskConfirmation)
        }
    }

    func testExecuteRejectsSubmissionBeforeReminderTime() async throws {
        let useCase = SubmitNextDayPlanUseCase(planRepository: TestPlanRepository(), taskRepository: TestTaskRepository())
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let submittedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T21:29:59Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: submittedAt,
            now: submittedAt,
            timezone: timezone,
            tasks: [
                makeTask(
                    id: "task_1",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-09",
                    localTimezone: "UTC",
                    title: "before reminder",
                    bucket: .required
                )
            ],
            noRequiredTasksConfirmed: false
        )

        do {
            _ = try await useCase.execute(request)
            XCTFail("Expected reminder window error")
        } catch let error as SubmitNextDayPlanError {
            XCTAssertEqual(
                error,
                .submissionBeforeReminderTime(reminderTime: "21:30", actualLocalTime: "21:29:59")
            )
        }
    }

    func testExecuteAllowsSubmissionAtCutoffTime() async throws {
        let planRepo = TestPlanRepository()
        let taskRepo = TestTaskRepository()
        let useCase = SubmitNextDayPlanUseCase(planRepository: planRepo, taskRepository: taskRepo)
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let submittedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T23:00:00Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: submittedAt,
            now: submittedAt,
            timezone: timezone,
            tasks: [
                makeTask(
                    id: "task_1",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-09",
                    localTimezone: "UTC",
                    title: "at cutoff",
                    bucket: .required
                )
            ],
            noRequiredTasksConfirmed: false
        )

        let plan = try await useCase.execute(request)

        XCTAssertEqual(plan.dateKey, "2026-03-09")
        let savedTasks = try await taskRepo.fetchTasks(userId: "usr_1", dateKey: "2026-03-09")
        XCTAssertEqual(savedTasks.count, 1)
    }

    func testExecuteAcceptsEquivalentUTCAndGMTTimezoneIdentifiers() async throws {
        let planRepo = TestPlanRepository()
        let taskRepo = TestTaskRepository()
        let useCase = SubmitNextDayPlanUseCase(planRepository: planRepo, taskRepository: taskRepo)
        let timezone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        let submittedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:15:00Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: submittedAt,
            now: submittedAt,
            timezone: timezone,
            tasks: [
                makeTask(
                    id: "task_utc",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-09",
                    localTimezone: "UTC",
                    title: "utc alias",
                    bucket: .required
                )
            ],
            noRequiredTasksConfirmed: false
        )

        let plan = try await useCase.execute(request)
        let savedTasks = try await taskRepo.fetchTasks(userId: "usr_1", dateKey: "2026-03-09")

        XCTAssertEqual(plan.dateKey, "2026-03-09")
        XCTAssertEqual(savedTasks.count, 1)
    }

    func testExecuteRejectsSubmissionAfterCutoffTime() async throws {
        let useCase = SubmitNextDayPlanUseCase(planRepository: TestPlanRepository(), taskRepository: TestTaskRepository())
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let submittedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T23:00:01Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: submittedAt,
            now: submittedAt,
            timezone: timezone,
            tasks: [
                makeTask(
                    id: "task_1",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-09",
                    localTimezone: "UTC",
                    title: "after cutoff",
                    bucket: .required
                )
            ],
            noRequiredTasksConfirmed: false
        )

        do {
            _ = try await useCase.execute(request)
            XCTFail("Expected cutoff error")
        } catch let error as SubmitNextDayPlanError {
            XCTAssertEqual(
                error,
                .submissionAfterCutoffTime(cutoffTime: "23:00", actualLocalTime: "23:00:01")
            )
        }
    }

    func testExecuteRejectsInvalidPlanningWindowPolicy() async throws {
        let useCase = SubmitNextDayPlanUseCase(planRepository: TestPlanRepository(), taskRepository: TestTaskRepository())
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))

        let request = SubmitNextDayPlanRequest(
            userId: "usr_1",
            coupleId: "cpl_1",
            submittedAt: now,
            now: now,
            timezone: timezone,
            planningWindowPolicy: PlanningWindowPolicy(
                reminderTime: LocalClockTime(hour: 23, minute: 0),
                cutoffTime: LocalClockTime(hour: 21, minute: 30)
            ),
            tasks: [
                makeTask(
                    id: "task_1",
                    ownerUserId: "usr_1",
                    dateKey: "2026-03-09",
                    localTimezone: "UTC",
                    title: "invalid policy",
                    bucket: .required
                )
            ],
            noRequiredTasksConfirmed: false
        )

        do {
            _ = try await useCase.execute(request)
            XCTFail("Expected invalid policy error")
        } catch let error as SubmitNextDayPlanError {
            XCTAssertEqual(
                error,
                .invalidPlanningWindow(reminderTime: "23:00", cutoffTime: "21:30")
            )
        }
    }

    func testExecuteAllowsResubmissionAfterCutoffWhenPlanAlreadySubmitted() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))
        let submittedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T23:30:00Z"))
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let existingPlan = DailyPlan(
            id: "usr_1_2026-03-09",
            userId: "usr_1",
            coupleId: "cpl_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            submittedAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:10:00Z")),
            planningMissed: false
        )
        let planRepo = TestPlanRepository(seed: [existingPlan])
        let taskRepo = TestTaskRepository()
        let useCase = SubmitNextDayPlanUseCase(planRepository: planRepo, taskRepository: taskRepo)

        let plan = try await useCase.execute(
            SubmitNextDayPlanRequest(
                userId: "usr_1",
                coupleId: "cpl_1",
                submittedAt: submittedAt,
                now: now,
                timezone: timezone,
                tasks: [
                    makeTask(
                        id: "task_1",
                        ownerUserId: "usr_1",
                        dateKey: "2026-03-09",
                        localTimezone: "UTC",
                        title: "resubmit",
                        bucket: .required
                    )
                ],
                noRequiredTasksConfirmed: false
            )
        )

        XCTAssertEqual(plan.dateKey, "2026-03-09")
        XCTAssertEqual(plan.submittedAt, submittedAt)
    }

    func testExecuteRejectsResubmissionAfterEditableDeadline() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:00:00Z"))
        let submittedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-09T00:00:01Z"))
        let timezone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let existingPlan = DailyPlan(
            id: "usr_1_2026-03-09",
            userId: "usr_1",
            coupleId: "cpl_1",
            dateKey: "2026-03-09",
            localTimezone: "UTC",
            submittedAt: try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T22:10:00Z")),
            planningMissed: false
        )
        let useCase = SubmitNextDayPlanUseCase(
            planRepository: TestPlanRepository(seed: [existingPlan]),
            taskRepository: TestTaskRepository()
        )

        do {
            _ = try await useCase.execute(
                SubmitNextDayPlanRequest(
                    userId: "usr_1",
                    coupleId: "cpl_1",
                    submittedAt: submittedAt,
                    now: now,
                    timezone: timezone,
                    tasks: [
                        makeTask(
                            id: "task_1",
                            ownerUserId: "usr_1",
                            dateKey: "2026-03-09",
                            localTimezone: "UTC",
                            title: "too late edit",
                            bucket: .required
                        )
                    ],
                    noRequiredTasksConfirmed: false
                )
            )
            XCTFail("Expected edit deadline error")
        } catch let error as SubmitNextDayPlanError {
            XCTAssertEqual(
                error,
                .editDeadlinePassed(deadline: "00:00", actualLocalTime: "00:00:01")
            )
        }
    }
}

private func makeTask(
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
