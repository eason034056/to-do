import Foundation

public struct SubmitNextDayPlanRequest: Sendable {
    public let userId: String
    public let coupleId: String
    public let submittedAt: Date
    public let now: Date
    public let timezone: TimeZone
    public let tasks: [TodoTask]
    public let noRequiredTasksConfirmed: Bool

    public init(
        userId: String,
        coupleId: String,
        submittedAt: Date,
        now: Date,
        timezone: TimeZone,
        tasks: [TodoTask],
        noRequiredTasksConfirmed: Bool
    ) {
        self.userId = userId
        self.coupleId = coupleId
        self.submittedAt = submittedAt
        self.now = now
        self.timezone = timezone
        self.tasks = tasks
        self.noRequiredTasksConfirmed = noRequiredTasksConfirmed
    }
}

public enum SubmitNextDayPlanError: Error, Equatable {
    case emptyTasksWithoutConfirmation
    case taskBelongsToAnotherUser
    case taskDateKeyMismatch(expected: String, actual: String)
    case taskTimezoneMismatch(expected: String, actual: String)
}

public struct SubmitNextDayPlanUseCase: Sendable {
    private let planRepository: PlanRepository
    private let taskRepository: TaskRepository

    public init(planRepository: PlanRepository, taskRepository: TaskRepository) {
        self.planRepository = planRepository
        self.taskRepository = taskRepository
    }

    @discardableResult
    public func execute(_ request: SubmitNextDayPlanRequest) async throws -> DailyPlan {
        let nextDayKey = DateKeyFactory.nextDateKey(from: request.now, timezone: request.timezone)

        if request.tasks.isEmpty, request.noRequiredTasksConfirmed == false {
            throw SubmitNextDayPlanError.emptyTasksWithoutConfirmation
        }

        for task in request.tasks {
            if task.ownerUserId != request.userId {
                throw SubmitNextDayPlanError.taskBelongsToAnotherUser
            }
            if task.dateKey != nextDayKey {
                throw SubmitNextDayPlanError.taskDateKeyMismatch(expected: nextDayKey, actual: task.dateKey)
            }
            if task.localTimezone != request.timezone.identifier {
                throw SubmitNextDayPlanError.taskTimezoneMismatch(expected: request.timezone.identifier, actual: task.localTimezone)
            }
        }

        let planId = "\(request.userId)_\(nextDayKey)"
        let plan = DailyPlan(
            id: planId,
            userId: request.userId,
            coupleId: request.coupleId,
            dateKey: nextDayKey,
            localTimezone: request.timezone.identifier,
            submittedAt: request.submittedAt,
            planningMissed: false
        )

        try await planRepository.upsertPlan(plan)
        try await taskRepository.replaceTasks(for: request.userId, dateKey: nextDayKey, tasks: TaskSortingService.sort(request.tasks))

        return plan
    }
}

enum DateKeyFactory {
    static func nextDateKey(from date: Date, timezone: TimeZone) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timezone
        let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: nextDate)
    }
}
