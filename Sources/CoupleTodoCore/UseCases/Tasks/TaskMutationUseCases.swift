import Foundation

public enum TaskMutationError: Error, Equatable {
    case taskBelongsToAnotherUser
    case taskNotFound
}

public struct CreateTaskRequest: Sendable {
    public let actorUserId: String
    public let coupleId: String
    public let task: TodoTask
    public let now: Date

    public init(actorUserId: String, coupleId: String, task: TodoTask, now: Date) {
        self.actorUserId = actorUserId
        self.coupleId = coupleId
        self.task = task
        self.now = now
    }
}

public struct CreateTaskUseCase: Sendable {
    private let taskRepository: TaskRepository
    private let eventRepository: EventRepository

    public init(taskRepository: TaskRepository, eventRepository: EventRepository) {
        self.taskRepository = taskRepository
        self.eventRepository = eventRepository
    }

    @discardableResult
    public func execute(_ request: CreateTaskRequest) async throws -> TodoTask {
        guard request.task.ownerUserId == request.actorUserId else {
            throw TaskMutationError.taskBelongsToAnotherUser
        }

        var task = request.task
        task.createdAt = request.now
        task.updatedAt = request.now
        task.syncState = .localPending

        try await taskRepository.upsertTask(task)
        try await eventRepository.appendEvent(
            EventLogEntry(
                id: UUID().uuidString.lowercased(),
                coupleId: request.coupleId,
                type: .taskCreated,
                actorUserId: request.actorUserId,
                subjectId: task.id,
                payload: ["dateKey": task.dateKey, "title": task.title],
                createdAt: request.now
            )
        )

        return task
    }
}

public struct UpdateTaskRequest: Sendable {
    public let actorUserId: String
    public let coupleId: String
    public let task: TodoTask
    public let now: Date

    public init(actorUserId: String, coupleId: String, task: TodoTask, now: Date) {
        self.actorUserId = actorUserId
        self.coupleId = coupleId
        self.task = task
        self.now = now
    }
}

public struct UpdateTaskUseCase: Sendable {
    private let taskRepository: TaskRepository
    private let eventRepository: EventRepository

    public init(taskRepository: TaskRepository, eventRepository: EventRepository) {
        self.taskRepository = taskRepository
        self.eventRepository = eventRepository
    }

    @discardableResult
    public func execute(_ request: UpdateTaskRequest) async throws -> TodoTask {
        guard request.task.ownerUserId == request.actorUserId else {
            throw TaskMutationError.taskBelongsToAnotherUser
        }

        var task = request.task
        task.updatedAt = request.now
        task.syncState = .localPending

        try await taskRepository.upsertTask(task)
        try await eventRepository.appendEvent(
            EventLogEntry(
                id: UUID().uuidString.lowercased(),
                coupleId: request.coupleId,
                type: .taskUpdated,
                actorUserId: request.actorUserId,
                subjectId: task.id,
                payload: ["dateKey": task.dateKey, "title": task.title],
                createdAt: request.now
            )
        )

        return task
    }
}

public struct DeleteTaskRequest: Sendable {
    public let actorUserId: String
    public let coupleId: String
    public let taskId: String
    public let ownerUserId: String
    public let dateKey: String
    public let now: Date

    public init(actorUserId: String, coupleId: String, taskId: String, ownerUserId: String, dateKey: String, now: Date) {
        self.actorUserId = actorUserId
        self.coupleId = coupleId
        self.taskId = taskId
        self.ownerUserId = ownerUserId
        self.dateKey = dateKey
        self.now = now
    }
}

public struct DeleteTaskUseCase: Sendable {
    private let taskRepository: TaskRepository
    private let eventRepository: EventRepository

    public init(taskRepository: TaskRepository, eventRepository: EventRepository) {
        self.taskRepository = taskRepository
        self.eventRepository = eventRepository
    }

    public func execute(_ request: DeleteTaskRequest) async throws {
        guard request.ownerUserId == request.actorUserId else {
            throw TaskMutationError.taskBelongsToAnotherUser
        }

        try await taskRepository.deleteTask(id: request.taskId, ownerUserId: request.ownerUserId, dateKey: request.dateKey)
        try await eventRepository.appendEvent(
            EventLogEntry(
                id: UUID().uuidString.lowercased(),
                coupleId: request.coupleId,
                type: .taskDeleted,
                actorUserId: request.actorUserId,
                subjectId: request.taskId,
                payload: ["dateKey": request.dateKey],
                createdAt: request.now
            )
        )
    }
}

public struct ToggleTaskCompletionRequest: Sendable {
    public let actorUserId: String
    public let coupleId: String
    public let taskId: String
    public let dateKey: String
    public let completed: Bool
    public let now: Date

    public init(actorUserId: String, coupleId: String, taskId: String, dateKey: String, completed: Bool, now: Date) {
        self.actorUserId = actorUserId
        self.coupleId = coupleId
        self.taskId = taskId
        self.dateKey = dateKey
        self.completed = completed
        self.now = now
    }
}

public struct ToggleTaskCompletionUseCase: Sendable {
    private let taskRepository: TaskRepository
    private let eventRepository: EventRepository

    public init(taskRepository: TaskRepository, eventRepository: EventRepository) {
        self.taskRepository = taskRepository
        self.eventRepository = eventRepository
    }

    @discardableResult
    public func execute(_ request: ToggleTaskCompletionRequest) async throws -> TodoTask {
        let tasks = try await taskRepository.fetchTasks(userId: request.actorUserId, dateKey: request.dateKey)
        guard var task = tasks.first(where: { $0.id == request.taskId && $0.deleted == false }) else {
            throw TaskMutationError.taskNotFound
        }

        task.status = request.completed ? .completed : .pending
        task.completedAtClient = request.completed ? request.now : nil
        task.updatedAt = request.now
        task.syncState = .localPending
        if request.completed == false {
            task.completedAtServer = nil
        }

        try await taskRepository.upsertTask(task)
        try await eventRepository.appendEvent(
            EventLogEntry(
                id: UUID().uuidString.lowercased(),
                coupleId: request.coupleId,
                type: request.completed ? .taskCompleted : .taskUncompleted,
                actorUserId: request.actorUserId,
                subjectId: task.id,
                payload: ["dateKey": task.dateKey, "title": task.title],
                createdAt: request.now
            )
        )

        return task
    }
}

public struct ReorderTasksRequest: Sendable {
    public let actorUserId: String
    public let coupleId: String
    public let dateKey: String
    public let orderedTaskIds: [String]
    public let now: Date

    public init(actorUserId: String, coupleId: String, dateKey: String, orderedTaskIds: [String], now: Date) {
        self.actorUserId = actorUserId
        self.coupleId = coupleId
        self.dateKey = dateKey
        self.orderedTaskIds = orderedTaskIds
        self.now = now
    }
}

public struct ReorderTasksUseCase: Sendable {
    private let taskRepository: TaskRepository
    private let eventRepository: EventRepository

    public init(taskRepository: TaskRepository, eventRepository: EventRepository) {
        self.taskRepository = taskRepository
        self.eventRepository = eventRepository
    }

    public func execute(_ request: ReorderTasksRequest) async throws {
        var tasks = try await taskRepository.fetchTasks(userId: request.actorUserId, dateKey: request.dateKey)
        let sortMap = Dictionary(uniqueKeysWithValues: request.orderedTaskIds.enumerated().map { ($1, ($0 + 1) * 1000) })

        for index in tasks.indices {
            if let sortOrder = sortMap[tasks[index].id] {
                tasks[index].sortOrder = sortOrder
                tasks[index].updatedAt = request.now
                tasks[index].syncState = .localPending
            }
        }

        try await taskRepository.replaceTasks(
            for: request.actorUserId,
            dateKey: request.dateKey,
            tasks: TaskSortingService.sort(tasks)
        )
        try await eventRepository.appendEvent(
            EventLogEntry(
                id: UUID().uuidString.lowercased(),
                coupleId: request.coupleId,
                type: .taskUpdated,
                actorUserId: request.actorUserId,
                payload: ["dateKey": request.dateKey, "kind": "reorder"],
                createdAt: request.now
            )
        )
    }
}
