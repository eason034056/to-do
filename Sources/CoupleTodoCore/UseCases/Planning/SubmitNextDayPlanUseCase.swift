import Foundation

public struct SubmitNextDayPlanRequest: Sendable {
    public let userId: String
    public let coupleId: String
    public let submittedAt: Date
    public let now: Date
    public let timezone: TimeZone
    public let planningWindowPolicy: PlanningWindowPolicy
    public let tasks: [TodoTask]
    public let noRequiredTasksConfirmed: Bool

    public init(
        userId: String,
        coupleId: String,
        submittedAt: Date,
        now: Date,
        timezone: TimeZone,
        planningWindowPolicy: PlanningWindowPolicy = .default,
        tasks: [TodoTask],
        noRequiredTasksConfirmed: Bool
    ) {
        self.userId = userId
        self.coupleId = coupleId
        self.submittedAt = submittedAt
        self.now = now
        self.timezone = timezone
        self.planningWindowPolicy = planningWindowPolicy
        self.tasks = tasks
        self.noRequiredTasksConfirmed = noRequiredTasksConfirmed
    }
}

public enum SubmitNextDayPlanError: Error, Equatable {
    case emptyTasks
    case missingRequiredTaskConfirmation
    case submissionBeforeReminderTime(reminderTime: String, actualLocalTime: String)
    case submissionAfterCutoffTime(cutoffTime: String, actualLocalTime: String)
    case invalidPlanningWindow(reminderTime: String, cutoffTime: String)
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
        switch request.planningWindowPolicy.validate(submittedAt: request.submittedAt, timezone: request.timezone) {
        case .withinWindow:
            break
        case let .beforeReminderTime(reminderTime, actualLocalTime):
            throw SubmitNextDayPlanError.submissionBeforeReminderTime(
                reminderTime: reminderTime,
                actualLocalTime: actualLocalTime
            )
        case let .afterCutoffTime(cutoffTime, actualLocalTime):
            throw SubmitNextDayPlanError.submissionAfterCutoffTime(
                cutoffTime: cutoffTime,
                actualLocalTime: actualLocalTime
            )
        case let .invalidPolicy(reminderTime, cutoffTime):
            throw SubmitNextDayPlanError.invalidPlanningWindow(
                reminderTime: reminderTime,
                cutoffTime: cutoffTime
            )
        }

        let nextDayKey = DateKeyFactory.nextDateKey(from: request.now, timezone: request.timezone)

        if request.tasks.isEmpty {
            throw SubmitNextDayPlanError.emptyTasks
        }

        let hasRequiredTask = request.tasks.contains(where: { $0.bucket == .required })
        if hasRequiredTask == false, request.noRequiredTasksConfirmed == false {
            throw SubmitNextDayPlanError.missingRequiredTaskConfirmation
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
        let requiredCount = request.tasks.filter { $0.bucket == .required && $0.deleted == false }.count
        let optionalCount = request.tasks.filter { $0.bucket == .optional && $0.deleted == false }.count
        let plan = DailyPlan(
            id: planId,
            userId: request.userId,
            coupleId: request.coupleId,
            dateKey: nextDayKey,
            localTimezone: request.timezone.identifier,
            submittedAt: request.submittedAt,
            planningMissed: false,
            localUtcOffsetMinutes: request.timezone.secondsFromGMT(for: request.submittedAt) / 60,
            lastEditedAt: request.submittedAt,
            requiredCount: requiredCount,
            optionalCount: optionalCount,
            version: 1
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
