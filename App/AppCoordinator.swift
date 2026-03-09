import Foundation
import SwiftUI
import CoupleTodoCore

@MainActor
final class AppCoordinator: ObservableObject {
    enum Phase {
        case loading
        case auth
        case pairing
        case ready
    }

    enum TaskMoveDirection {
        case up
        case down
    }

    struct SettingsDraft {
        var planningReminderTime: String
        var planningCutoffTime: String
        var dailySettlementTime: String
        var dailySettlementGraceMinutes: Int
        var penaltyAmount: String
        var currency: String
        var planningMissPenaltyEnabled: Bool
        var weekStartsOn: WeekStart

        init(couple: Couple) {
            planningReminderTime = couple.reminderConfig.planningReminderTime.displayString
            planningCutoffTime = couple.reminderConfig.planningCutoffTime.displayString
            dailySettlementTime = couple.reminderConfig.dailySettlementTime.displayString
            dailySettlementGraceMinutes = couple.reminderConfig.dailySettlementGraceMinutes
            penaltyAmount = NSDecimalNumber(decimal: couple.penaltyPolicy.amount).stringValue
            currency = couple.penaltyPolicy.currency
            planningMissPenaltyEnabled = couple.penaltyPolicy.planningMissPenaltyEnabled
            weekStartsOn = couple.weekStartsOn
        }
    }

    let environment: DemoAppEnvironment
    let currentUserId: String

    @Published var phase: Phase = .loading
    @Published var path: [AppRoute] = []
    @Published var fullScreenRoute: AppRoute?
    @Published var dashboardSnapshot: DashboardSnapshot?
    @Published var planningDraftTasks: [TodoTask] = []
    @Published var rewardDraftText = ""
    @Published var settingsDraft: SettingsDraft?
    @Published var latestError: String?
    @Published var isBootstrapped = false
    @Published var noRequiredTasksConfirmed = false

    init(environment: DemoAppEnvironment, currentUserId: String = DemoAppEnvironment.defaultCurrentUserId) {
        self.environment = environment
        self.currentUserId = currentUserId
    }

    func bootstrapIfNeeded() async {
        guard isBootstrapped == false else { return }
        isBootstrapped = true
        await bootstrap()
    }

    func bootstrap() async {
        phase = .loading

        do {
            let snapshot = try await environment.loadDashboardUseCase.execute(
                LoadDashboardRequest(userId: currentUserId, now: environment.now())
            )
            dashboardSnapshot = snapshot
            try? environment.sharedSnapshotWriter.write(from: snapshot)
            settingsDraft = SettingsDraft(couple: snapshot.couple)
            rewardDraftText = snapshot.currentRewardWeek?.rewardText ?? ""
            phase = .ready
            await refreshPlanningDraft()

            if let gate = snapshot.pendingGate {
                switch gate {
                case let .planning(dateKey):
                    fullScreenRoute = .planning(dateKey: dateKey)
                case let .settlement(dateKey):
                    fullScreenRoute = .settlement(dateKey: dateKey)
                }
            }
        } catch LoadDashboardError.userNotFound {
            phase = .auth
        } catch {
            latestError = error.localizedDescription
            phase = .pairing
        }
    }

    func navigate(to route: AppRoute) {
        switch route {
        case .planning, .settlement:
            fullScreenRoute = route
        default:
            path.append(route)
        }
    }

    func dismissFullScreenRoute() {
        fullScreenRoute = nil
    }

    func handle(url: URL) {
        guard let route = DeepLinkRouter.route(for: url) else { return }
        navigate(to: route)
    }

    func refreshDashboard() async {
        do {
            let snapshot = try await environment.loadDashboardUseCase.execute(
                LoadDashboardRequest(userId: currentUserId, now: environment.now())
            )
            dashboardSnapshot = snapshot
            try? environment.sharedSnapshotWriter.write(from: snapshot)
            if let couple = dashboardSnapshot?.couple {
                settingsDraft = SettingsDraft(couple: couple)
            }
        } catch {
            latestError = error.localizedDescription
        }
    }

    func refreshPlanningDraft() async {
        guard let snapshot = dashboardSnapshot else { return }
        do {
            planningDraftTasks = try await environment.taskRepository.fetchTasks(
                userId: currentUserId,
                dateKey: snapshot.planningTargetDateKey
            )
            noRequiredTasksConfirmed = planningDraftTasks.contains(where: { $0.bucket == .required }) == false
        } catch {
            latestError = error.localizedDescription
        }
    }

    func submitPlanningDraft() async {
        guard let snapshot = dashboardSnapshot else { return }

        do {
            _ = try await environment.submitNextDayPlanUseCase.execute(
                SubmitNextDayPlanRequest(
                    userId: currentUserId,
                    coupleId: snapshot.couple.id,
                    submittedAt: environment.now(),
                    now: environment.now(),
                    timezone: TimeZone(identifier: snapshot.user.currentTimezone) ?? .current,
                    planningWindowPolicy: PlanningWindowPolicy(
                        reminderTime: snapshot.couple.reminderConfig.planningReminderTime,
                        cutoffTime: snapshot.couple.reminderConfig.planningCutoffTime
                    ),
                    tasks: planningDraftTasks,
                    noRequiredTasksConfirmed: noRequiredTasksConfirmed
                )
            )
            await refreshDashboard()
            dismissFullScreenRoute()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func saveTaskDraft(
        _ draft: TaskEditorDraft,
        existingTask: TodoTask?,
        dateKey: String,
        localTimezone: String
    ) async -> Bool {
        guard let snapshot = dashboardSnapshot else { return false }

        let trimmedTitle = draft.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else {
            latestError = "Task title cannot be empty."
            return false
        }
        guard let timezone = TimeZone(identifier: localTimezone) else {
            latestError = "Task timezone is invalid."
            return false
        }

        do {
            let now = environment.now()
            let context = LocalTimeContextFactory.make(from: now, timezone: timezone)
            let sortOrder = try await nextSortOrder(for: dateKey)

            let task = TodoTask(
                id: existingTask?.id ?? "task_\(UUID().uuidString.lowercased())",
                ownerUserId: currentUserId,
                dateKey: dateKey,
                localTimezone: localTimezone,
                title: trimmedTitle,
                notes: draft.notes.normalizedNilIfEmpty,
                bucket: draft.bucket,
                priority: draft.priority,
                status: existingTask?.status ?? .pending,
                sortOrder: existingTask?.sortOrder ?? sortOrder,
                completedAtServer: existingTask?.completedAtServer,
                localUtcOffsetMinutes: context.utcOffsetMinutes,
                createdAt: existingTask?.createdAt,
                updatedAt: existingTask?.updatedAt,
                completedAtClient: existingTask?.completedAtClient,
                carriedFromTaskId: existingTask?.carriedFromTaskId,
                deleted: false,
                syncState: existingTask?.syncState ?? .localPending
            )

            if existingTask == nil {
                _ = try await environment.createTaskUseCase.execute(
                    CreateTaskRequest(
                        actorUserId: currentUserId,
                        coupleId: snapshot.couple.id,
                        task: task,
                        now: now
                    )
                )
            } else {
                _ = try await environment.updateTaskUseCase.execute(
                    UpdateTaskRequest(
                        actorUserId: currentUserId,
                        coupleId: snapshot.couple.id,
                        task: task,
                        now: now
                    )
                )
            }

            await refreshTaskState(for: dateKey)
            return true
        } catch {
            latestError = error.localizedDescription
            return false
        }
    }

    func deleteTask(_ task: TodoTask) async {
        guard let snapshot = dashboardSnapshot else { return }

        do {
            try await environment.deleteTaskUseCase.execute(
                DeleteTaskRequest(
                    actorUserId: currentUserId,
                    coupleId: snapshot.couple.id,
                    taskId: task.id,
                    ownerUserId: task.ownerUserId,
                    dateKey: task.dateKey,
                    now: environment.now()
                )
            )
            await refreshTaskState(for: task.dateKey)
        } catch {
            latestError = error.localizedDescription
        }
    }

    func toggleTaskCompletion(_ task: TodoTask) async {
        guard let snapshot = dashboardSnapshot else { return }

        do {
            _ = try await environment.toggleTaskCompletionUseCase.execute(
                ToggleTaskCompletionRequest(
                    actorUserId: currentUserId,
                    coupleId: snapshot.couple.id,
                    taskId: task.id,
                    dateKey: task.dateKey,
                    completed: task.status != .completed,
                    now: environment.now()
                )
            )
            await refreshTaskState(for: task.dateKey)
        } catch {
            latestError = error.localizedDescription
        }
    }

    func moveTask(_ task: TodoTask, direction: TaskMoveDirection) async {
        guard let snapshot = dashboardSnapshot else { return }

        do {
            let tasks = try await environment.taskRepository.fetchTasks(userId: currentUserId, dateKey: task.dateKey)
            let movableTasks = tasks.filter { candidate in
                candidate.deleted == false &&
                candidate.bucket == task.bucket &&
                candidate.priority == task.priority
            }
            let sortedMovableTasks = TaskSortingService.sort(movableTasks)
            var orderedIds = sortedMovableTasks.map { $0.id }

            guard let currentIndex = orderedIds.firstIndex(of: task.id) else { return }

            let targetIndex: Int
            switch direction {
            case .up:
                targetIndex = currentIndex - 1
            case .down:
                targetIndex = currentIndex + 1
            }

            guard orderedIds.indices.contains(targetIndex) else { return }
            orderedIds.swapAt(currentIndex, targetIndex)

            try await environment.reorderTasksUseCase.execute(
                ReorderTasksRequest(
                    actorUserId: currentUserId,
                    coupleId: snapshot.couple.id,
                    dateKey: task.dateKey,
                    orderedTaskIds: orderedIds,
                    now: environment.now()
                )
            )
            await refreshTaskState(for: task.dateKey)
        } catch {
            latestError = error.localizedDescription
        }
    }

    func acknowledgeLatestSettlement() async {
        guard let settlement = dashboardSnapshot?.latestSettlement else { return }

        do {
            _ = try await environment.acknowledgeSettlementUseCase.execute(
                AcknowledgeSettlementRequest(
                    coupleId: settlement.coupleId,
                    settlementId: settlement.id,
                    userId: currentUserId
                )
            )
            await refreshDashboard()
            dismissFullScreenRoute()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func saveRewardDraft() async {
        guard let snapshot = dashboardSnapshot,
              let timezone = TimeZone(identifier: snapshot.user.currentTimezone) else { return }

        do {
            _ = try await environment.saveNextWeekRewardUseCase.execute(
                SaveNextWeekRewardRequest(
                    coupleId: snapshot.couple.id,
                    actorUserId: currentUserId,
                    rewardText: rewardDraftText,
                    now: environment.now(),
                    timezone: timezone
                )
            )
            await refreshDashboard()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func saveSettings() async {
        guard let snapshot = dashboardSnapshot,
              var draft = settingsDraft,
              let reminderTime = Self.parseClockTime(draft.planningReminderTime),
              let cutoffTime = Self.parseClockTime(draft.planningCutoffTime),
              let settlementTime = Self.parseClockTime(draft.dailySettlementTime),
              let amount = Decimal(string: draft.penaltyAmount) else {
            latestError = "Settings contain invalid values."
            return
        }

        do {
            var couple = snapshot.couple
            couple.weekStartsOn = draft.weekStartsOn
            couple.reminderConfig = ReminderConfig(
                planningReminderTime: reminderTime,
                planningCutoffTime: cutoffTime,
                planningEscalationEveryMinutes: couple.reminderConfig.planningEscalationEveryMinutes,
                dailySettlementTime: settlementTime,
                dailySettlementGraceMinutes: draft.dailySettlementGraceMinutes
            )
            couple.penaltyPolicy.amount = amount
            couple.penaltyPolicy.currency = draft.currency
            couple.penaltyPolicy.planningMissPenaltyEnabled = draft.planningMissPenaltyEnabled
            couple.updatedAt = environment.now()

            try await environment.coupleRepository.upsertCouple(couple)
            draft = SettingsDraft(couple: couple)
            settingsDraft = draft
            await refreshDashboard()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func clearLatestError() {
        latestError = nil
    }

    func canMoveTask(_ task: TodoTask, direction: TaskMoveDirection) -> Bool {
        let tasks = tasksForDisplay(on: task.dateKey)
            .filter { $0.bucket == task.bucket && $0.priority == task.priority }
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            return false
        }

        switch direction {
        case .up:
            return index > 0
        case .down:
            return index < tasks.count - 1
        }
    }

    func tasksForDisplay(on dateKey: String) -> [TodoTask] {
        if let snapshot = dashboardSnapshot, snapshot.selfContext.dateKey == dateKey {
            return TaskSortingService.sort(snapshot.selfRequired + snapshot.selfOptional)
        }
        if planningDraftTasks.first?.dateKey == dateKey || dashboardSnapshot?.planningTargetDateKey == dateKey {
            return TaskSortingService.sort(planningDraftTasks.filter { $0.deleted == false })
        }
        return []
    }

    private static func parseClockTime(_ value: String) -> LocalClockTime? {
        let components = value.split(separator: ":").map(String.init)
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        let time = LocalClockTime(hour: hour, minute: minute)
        return time.isValid ? time : nil
    }

    private func refreshTaskState(for dateKey: String) async {
        await refreshDashboard()
        if dashboardSnapshot?.planningTargetDateKey == dateKey {
            await refreshPlanningDraft()
        }
    }

    private func nextSortOrder(for dateKey: String) async throws -> Int {
        let tasks = try await environment.taskRepository.fetchTasks(userId: currentUserId, dateKey: dateKey)
        let maxSortOrder = tasks.map { $0.sortOrder }.max() ?? 0
        return ((maxSortOrder / 1000) + 1) * 1000
    }
}

private extension String {
    var normalizedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
