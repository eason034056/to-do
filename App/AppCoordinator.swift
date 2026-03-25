import Foundation
import SwiftUI
import CoupleTodoCore
import CoupleTodoFirebase
import UserNotifications
import ActivityKit

@MainActor
final class AppCoordinator: ObservableObject {
    enum Phase: Equatable {
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
        var planningReminderEnabled: Bool
        var settlementReminderEnabled: Bool
        var timeSensitiveAllowed: Bool
        var notificationPermissionStatus: String
        var deviceTimezone: String
        var deviceUtcOffsetMinutes: Int

        init(
            couple: Couple,
            user: UserProfile,
            installation: DeviceInstallation?,
            notificationPermissionStatus: String
        ) {
            planningReminderTime = couple.reminderConfig.planningReminderTime.displayString
            planningCutoffTime = couple.reminderConfig.planningCutoffTime.displayString
            dailySettlementTime = couple.reminderConfig.dailySettlementTime.displayString
            dailySettlementGraceMinutes = couple.reminderConfig.dailySettlementGraceMinutes
            penaltyAmount = NSDecimalNumber(decimal: couple.penaltyPolicy.amount).stringValue
            currency = couple.penaltyPolicy.currency
            planningMissPenaltyEnabled = couple.penaltyPolicy.planningMissPenaltyEnabled
            weekStartsOn = couple.weekStartsOn
            planningReminderEnabled = user.notificationPreferences.planningReminderEnabled
            settlementReminderEnabled = user.notificationPreferences.settlementReminderEnabled
            timeSensitiveAllowed = user.notificationPreferences.timeSensitiveAllowed
            self.notificationPermissionStatus = notificationPermissionStatus
            deviceTimezone = installation?.timezone ?? user.currentTimezone
            deviceUtcOffsetMinutes = installation?.utcOffsetMinutes ?? user.currentUtcOffsetMinutes
        }
    }

    struct SettlementHistoryEntry: Identifiable {
        let dateKey: String
        let records: [PaymentRecord]
        let grossOwesAmount: Decimal
        let grossReceivableAmount: Decimal
        let netAmount: Decimal

        var id: String { dateKey }
    }

    let environment: AppEnvironment

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
    @Published var currentSession: AuthSession?
    @Published var currentUserId: String?
    @Published var pairingCouple: Couple?
    @Published var authInFlightProvider: AuthenticationProvider?
    @Published var isPairingActionInFlight = false
    @Published var paymentRecords: [PaymentRecord] = []
    @Published var cachedFCMToken: String?
    @Published var cachedAPNsToken: String?
    @Published var notificationPermissionGranted = false

    private var deferredRoute: AppRoute?
    private var dashboardSyncTask: Task<Void, Never>?
    private let dashboardSyncIntervalNanoseconds: UInt64 = 20_000_000_000

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func bootstrapIfNeeded() async {
        guard isBootstrapped == false else { return }
        isBootstrapped = true
        await bootstrap()
    }

    func bootstrap() async {
        stopDashboardSync()
        phase = .loading
        dashboardSnapshot = nil
        paymentRecords = []
        pairingCouple = nil
        path = []
        fullScreenRoute = nil

        guard let session = environment.authService.currentSession() else {
            currentSession = nil
            currentUserId = nil
            phase = .auth
            return
        }

        currentSession = session
        currentUserId = session.userId

        do {
            let profile = try await environment.profileBootstrapper.ensureProfile(
                for: session,
                now: environment.now(),
                timezone: .current
            )
            await syncCurrentDeviceInstallation(for: profile)
            await requestNotificationPermission()

            if let coupleId = profile.coupleId,
               let couple = try await environment.coupleRepository.fetchCouple(coupleId: coupleId) {
                pairingCouple = couple
                if couple.status != .active || couple.memberIds.count < 2 {
                    phase = .pairing
                    return
                }
            } else {
                phase = .pairing
                return
            }

            guard let userId = currentUserId else {
                phase = .auth
                return
            }

            let snapshot = try await environment.loadDashboardUseCase.execute(
                LoadDashboardRequest(userId: userId, now: environment.now())
            )
            let resolvedSnapshot = await applyPlanningMissIfNeeded(snapshot) ?? snapshot
            dashboardSnapshot = resolvedSnapshot
            pairingCouple = snapshot.couple
            try? environment.sharedSnapshotWriter.write(from: resolvedSnapshot)
            rewardDraftText = resolvedSnapshot.currentRewardWeek?.rewardText ?? ""
            phase = .ready
            startDashboardSyncIfNeeded()

            await refreshPlanningDraft()
            await refreshPayments()
            await refreshSettingsDraft()
            updateLiveActivitiesIfNeeded()

            if let gate = resolvedSnapshot.pendingGate {
                switch gate {
                case let .planning(dateKey):
                    fullScreenRoute = .planning(dateKey: dateKey)
                case let .settlement(dateKey):
                    fullScreenRoute = .settlement(dateKey: dateKey)
                }
            } else {
                applyDeferredRouteIfPossible()
            }
        } catch LoadDashboardError.userNotFound {
            stopDashboardSync()
            phase = .auth
        } catch LoadDashboardError.coupleNotFound, LoadDashboardError.partnerNotFound {
            stopDashboardSync()
            phase = .pairing
        } catch {
            latestError = error.localizedDescription
            stopDashboardSync()
            phase = .pairing
        }
    }

    func signIn(with provider: AuthenticationProvider) async {
        guard authInFlightProvider == nil else { return }
        authInFlightProvider = provider
        latestError = nil
        defer { authInFlightProvider = nil }

        do {
            _ = try await environment.authService.signIn(with: provider)
            isBootstrapped = false
            await bootstrap()
        } catch {
            latestError = error.localizedDescription
            phase = .auth
        }
    }

    func signOut() {
        latestError = nil
        stopDashboardSync()

        do {
            try environment.authService.signOut()
            resetToSignedOutState()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func createCouple() async {
        guard isPairingActionInFlight == false else { return }
        isPairingActionInFlight = true
        defer { isPairingActionInFlight = false }

        do {
            _ = try await environment.coupleLifecycleGateway.createCouple(
                weekStartsOn: .monday,
                reminderConfig: .default,
                penaltyPolicy: .default
            )
            isBootstrapped = false
            await bootstrap()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func joinCouple(inviteCode: String) async {
        let trimmedInviteCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmedInviteCode.isEmpty == false else {
            latestError = "Invite code cannot be empty."
            return
        }
        guard isPairingActionInFlight == false else { return }
        isPairingActionInFlight = true
        defer { isPairingActionInFlight = false }

        do {
            _ = try await environment.coupleLifecycleGateway.joinCouple(inviteCode: trimmedInviteCode)
            isBootstrapped = false
            await bootstrap()
        } catch {
            latestError = error.localizedDescription
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

    func canDismissCurrentFullScreenRoute() -> Bool {
        canDismiss(route: fullScreenRoute)
    }

    func dismissFullScreenRoute() {
        guard canDismiss(route: fullScreenRoute) else {
            latestError = "Please acknowledge settlement before leaving this screen."
            return
        }
        fullScreenRoute = nil
    }

    func handleIncomingURL(_ url: URL) {
        if environment.authService.handleOpenURL(url) {
            return
        }
        handleDeepLink(url)
    }

    func isAuthenticating(with provider: AuthenticationProvider) -> Bool {
        authInFlightProvider == provider
    }

    private func handleDeepLink(_ url: URL) {
        guard let route = DeepLinkRouter.route(for: url) else { return }

        if route.requiresAuthentication, currentSession == nil {
            deferredRoute = route
            phase = .auth
            return
        }

        if route.requiresActiveCouple, phase != .ready {
            deferredRoute = route
            if currentSession != nil {
                phase = .pairing
            }
            return
        }

        navigate(to: route)
    }

    func refreshDashboard() async {
        guard let userId = currentUserId else { return }

        do {
            let snapshot = try await environment.loadDashboardUseCase.execute(
                LoadDashboardRequest(userId: userId, now: environment.now())
            )
            let resolvedSnapshot = await applyPlanningMissIfNeeded(snapshot) ?? snapshot
            dashboardSnapshot = resolvedSnapshot
            pairingCouple = resolvedSnapshot.couple
            try? environment.sharedSnapshotWriter.write(from: resolvedSnapshot)
            await refreshPayments()
            await refreshSettingsDraft()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func refreshPlanningDraft() async {
        guard let snapshot = dashboardSnapshot, let userId = currentUserId else { return }
        do {
            planningDraftTasks = try await environment.taskRepository.fetchTasks(
                userId: userId,
                dateKey: snapshot.planningTargetDateKey
            )
            noRequiredTasksConfirmed = planningDraftTasks.contains(where: { $0.bucket == .required }) == false
        } catch {
            latestError = error.localizedDescription
        }
    }

    func refreshPayments() async {
        guard let snapshot = dashboardSnapshot, let userId = currentUserId else {
            paymentRecords = []
            return
        }

        do {
            paymentRecords = try await environment.paymentRepository.fetchPayments(
                coupleId: snapshot.couple.id,
                userId: userId
            )
        } catch {
            latestError = error.localizedDescription
        }
    }

    func carryOverOptionalTasks() async {
        guard let snapshot = dashboardSnapshot,
              let userId = currentUserId else { return }
        guard let timezone = TimeZone(identifier: snapshot.user.currentTimezone) else { return }

        let existingTitles = Set(
            planningDraftTasks
                .filter { $0.bucket == .optional && $0.deleted == false }
                .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        let sourceTasks = snapshot.selfOptional.filter { task in
            task.deleted == false &&
            task.status != .completed &&
            existingTitles.contains(task.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) == false
        }
        guard sourceTasks.isEmpty == false else {
            latestError = "No optional tasks to carry over."
            return
        }

        do {
            let now = environment.now()
            let context = LocalTimeContextFactory.make(from: now, timezone: timezone)
            var nextSortOrder = try await self.nextSortOrder(for: snapshot.planningTargetDateKey)

            for sourceTask in sourceTasks {
                let carriedTask = TodoTask(
                    id: "task_\(UUID().uuidString.lowercased())",
                    ownerUserId: userId,
                    dateKey: snapshot.planningTargetDateKey,
                    localTimezone: snapshot.user.currentTimezone,
                    title: sourceTask.title,
                    notes: sourceTask.notes,
                    bucket: .optional,
                    priority: sourceTask.priority,
                    status: .pending,
                    sortOrder: nextSortOrder,
                    completedAtServer: nil,
                    localUtcOffsetMinutes: context.utcOffsetMinutes,
                    completedAtClient: nil,
                    carriedFromTaskId: sourceTask.id,
                    deleted: false,
                    syncState: .localPending
                )
                nextSortOrder += 1000

                _ = try await environment.createTaskUseCase.execute(
                    CreateTaskRequest(
                        actorUserId: userId,
                        coupleId: snapshot.couple.id,
                        task: carriedTask,
                        now: now
                    )
                )
            }

            await refreshPlanningDraft()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func submitPlanningDraft() async {
        guard let snapshot = dashboardSnapshot,
              let userId = currentUserId else { return }

        do {
            _ = try await environment.submitNextDayPlanUseCase.execute(
                SubmitNextDayPlanRequest(
                    userId: userId,
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
        guard let snapshot = dashboardSnapshot,
              let userId = currentUserId else { return false }

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
                ownerUserId: userId,
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
                        actorUserId: userId,
                        coupleId: snapshot.couple.id,
                        task: task,
                        now: now
                    )
                )
            } else {
                _ = try await environment.updateTaskUseCase.execute(
                    UpdateTaskRequest(
                        actorUserId: userId,
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
        guard let snapshot = dashboardSnapshot,
              let userId = currentUserId else { return }

        do {
            try await environment.deleteTaskUseCase.execute(
                DeleteTaskRequest(
                    actorUserId: userId,
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
        guard let snapshot = dashboardSnapshot,
              let userId = currentUserId else { return }

        do {
            _ = try await environment.toggleTaskCompletionUseCase.execute(
                ToggleTaskCompletionRequest(
                    actorUserId: userId,
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
        guard let snapshot = dashboardSnapshot,
              let userId = currentUserId else { return }

        do {
            let tasks = try await environment.taskRepository.fetchTasks(userId: userId, dateKey: task.dateKey)
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
                    actorUserId: userId,
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
        guard let settlement = dashboardSnapshot?.latestSettlement,
              let userId = currentUserId else { return }

        do {
            _ = try await environment.acknowledgeSettlementUseCase.execute(
                AcknowledgeSettlementRequest(
                    coupleId: settlement.coupleId,
                    settlementId: settlement.id,
                    userId: userId
                )
            )
            await refreshDashboard()
            dismissFullScreenRoute()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func paymentRecord(for recordId: String) -> PaymentRecord? {
        paymentRecords.first(where: { $0.id == recordId })
    }

    func settlementHistoryEntries() -> [SettlementHistoryEntry] {
        guard let userId = currentUserId else { return [] }

        let grouped = Dictionary(grouping: paymentRecords, by: \.sourceDateKey)
        return grouped.keys.sorted(by: >).compactMap { dateKey in
            let records = grouped[dateKey, default: []]
            let grossOwes = records
                .filter { $0.debtorUserId == userId }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let grossReceivable = records
                .filter { $0.creditorUserId == userId }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let net = grossOwes - grossReceivable
            return SettlementHistoryEntry(
                dateKey: dateKey,
                records: records.sorted(by: { $0.updatedAt > $1.updatedAt }),
                grossOwesAmount: grossOwes,
                grossReceivableAmount: grossReceivable,
                netAmount: net
            )
        }
    }

    func markPaymentPaid(recordId: String) async {
        guard let snapshot = dashboardSnapshot,
              let userId = currentUserId else { return }

        do {
            _ = try await environment.markPaymentPaidUseCase.execute(
                MarkPaymentPaidRequest(
                    coupleId: snapshot.couple.id,
                    recordId: recordId,
                    debtorUserId: userId,
                    paidAt: environment.now()
                )
            )
            await refreshDashboard()
            await refreshPayments()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func resolvePayment(recordId: String, status: PaymentStatus) async {
        guard let snapshot = dashboardSnapshot,
              let userId = currentUserId else { return }

        do {
            _ = try await environment.resolvePaymentStatusUseCase.execute(
                ResolvePaymentStatusRequest(
                    coupleId: snapshot.couple.id,
                    recordId: recordId,
                    creditorUserId: userId,
                    status: status,
                    resolvedAt: environment.now()
                )
            )
            await refreshDashboard()
            await refreshPayments()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func saveRewardDraft() async {
        guard let snapshot = dashboardSnapshot,
              let userId = currentUserId,
              let timezone = TimeZone(identifier: snapshot.user.currentTimezone) else { return }

        do {
            _ = try await environment.saveNextWeekRewardUseCase.execute(
                SaveNextWeekRewardRequest(
                    coupleId: snapshot.couple.id,
                    actorUserId: userId,
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
            var user = snapshot.user
            user.notificationPreferences = NotificationPreferences(
                planningReminderEnabled: draft.planningReminderEnabled,
                settlementReminderEnabled: draft.settlementReminderEnabled,
                timeSensitiveAllowed: draft.timeSensitiveAllowed
            )
            user.updatedAt = environment.now()
            try await environment.userRepository.upsertUser(user)

            let installation = try await currentDeviceInstallation(for: user.id)
            draft = SettingsDraft(
                couple: couple,
                user: user,
                installation: installation,
                notificationPermissionStatus: await notificationPermissionStatusDescription()
            )
            settingsDraft = draft
            await refreshDashboard()
        } catch {
            latestError = error.localizedDescription
        }
    }

    func clearLatestError() {
        latestError = nil
    }

    // MARK: - Push Token Sync

    func handleFCMTokenUpdate(_ token: String) {
        cachedFCMToken = token
        Task { await syncPushTokensIfNeeded() }
    }

    func handleAPNsTokenUpdate(_ token: String) {
        cachedAPNsToken = token
        Task { await syncPushTokensIfNeeded() }
    }

    func requestNotificationPermission() async {
        let granted = await NotificationService.requestAuthorization()
        notificationPermissionGranted = granted
    }

    // MARK: - Live Activity Lifecycle

    func updateLiveActivitiesIfNeeded() {
        guard let snapshot = dashboardSnapshot else { return }

        let reminderConfig = snapshot.couple.reminderConfig
        let selfTimezone = TimeZone(identifier: snapshot.user.currentTimezone) ?? .current
        let now = environment.now()

        if isPlanningWindowOpen(reminderConfig: reminderConfig, now: now, timezone: selfTimezone) {
            let remaining = planningRemainingMinutes(
                cutoffTime: reminderConfig.planningCutoffTime,
                now: now,
                timezone: selfTimezone
            )
            let state = PlanningReminderAttributes.ContentState(
                selfSubmitted: snapshot.selfSubmittedNextPlan,
                partnerSubmitted: snapshot.partnerSubmittedNextPlan,
                cutoffTime: reminderConfig.planningCutoffTime.displayString,
                remainingMinutes: remaining
            )
            startOrUpdatePlanningActivity(
                dateKey: snapshot.planningTargetDateKey,
                state: state
            )
        } else {
            endPlanningActivity()
        }

        if let settlement = snapshot.latestSettlement,
           settlement.pendingAcknowledgementUserIds.contains(snapshot.user.id) {
            let state = DailySettlementAttributes.ContentState(
                selfOutcome: settlement.subjectResult.outcome.rawValue,
                partnerOutcome: settlement.counterpartySnapshot.latestKnownOutcome?.rawValue,
                selfOwesAmount: settlement.subjectResult.owesAmount,
                partnerOwesAmount: 0,
                needsAck: true
            )
            startOrUpdateSettlementActivity(dateKey: settlement.dateKey, state: state)
        } else {
            endSettlementActivity()
        }
    }

    // MARK: - App Intent Route Handling

    func handlePendingIntentRoute() {
        guard let route = CoupleTodoIntentRouter.shared.consumeRoute() else { return }
        guard phase == .ready else { return }

        switch route {
        case .dashboard:
            break
        case .planning:
            if let dateKey = dashboardSnapshot?.planningTargetDateKey {
                navigate(to: .planning(dateKey: dateKey))
            }
        case .settlement:
            if let dateKey = dashboardSnapshot?.latestSettlement?.dateKey {
                navigate(to: .settlement(dateKey: dateKey))
            }
        case .rewards:
            if let weekKey = dashboardSnapshot?.selfContext.weekKey {
                navigate(to: .rewards(weekKey: weekKey))
            }
        }
    }

    // MARK: - Foreground Gate

    func handleAppBecameActive() async {
        guard phase == .ready else { return }
        await refreshDashboard()

        if let snapshot = dashboardSnapshot, let gate = snapshot.pendingGate {
            switch gate {
            case let .planning(dateKey):
                fullScreenRoute = .planning(dateKey: dateKey)
            case let .settlement(dateKey):
                fullScreenRoute = .settlement(dateKey: dateKey)
            }
        }

        updateLiveActivitiesIfNeeded()
        handlePendingIntentRoute()
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

    private func refreshSettingsDraft() async {
        guard let snapshot = dashboardSnapshot else { return }

        do {
            let installation = try await currentDeviceInstallation(for: snapshot.user.id)
            let permissionStatus = await notificationPermissionStatusDescription()
            settingsDraft = SettingsDraft(
                couple: snapshot.couple,
                user: snapshot.user,
                installation: installation,
                notificationPermissionStatus: permissionStatus
            )
        } catch {
            latestError = error.localizedDescription
        }
    }

    private func currentDeviceInstallation(for userId: String) async throws -> DeviceInstallation? {
        let installations = try await environment.deviceInstallationRepository.fetchInstallations(userId: userId)
        return installations.sorted(by: { $0.updatedAt > $1.updatedAt }).first
    }

    private func notificationPermissionStatusDescription() async -> String {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus.displayText)
            }
        }
    }

    private func applyPlanningMissIfNeeded(_ snapshot: DashboardSnapshot) async -> DashboardSnapshot? {
        guard snapshot.selfSubmittedNextPlan == false,
              let userId = currentUserId,
              let timezone = TimeZone(identifier: snapshot.user.currentTimezone) else {
            return nil
        }
        guard hasPassedPlanningCutoff(
            reminderConfig: snapshot.couple.reminderConfig,
            now: environment.now(),
            timezone: timezone
        ) else {
            return nil
        }

        do {
            _ = try await environment.markPlanningMissedUseCase.execute(
                MarkPlanningMissedRequest(
                    userId: userId,
                    coupleId: snapshot.couple.id,
                    dateKey: snapshot.planningTargetDateKey,
                    timezone: timezone,
                    now: environment.now()
                )
            )
            return try await environment.loadDashboardUseCase.execute(
                LoadDashboardRequest(userId: userId, now: environment.now())
            )
        } catch {
            latestError = error.localizedDescription
            return nil
        }
    }

    private func hasPassedPlanningCutoff(
        reminderConfig: ReminderConfig,
        now: Date,
        timezone: TimeZone
    ) -> Bool {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timezone

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = reminderConfig.planningCutoffTime.hour
        components.minute = reminderConfig.planningCutoffTime.minute
        components.second = 0

        guard let cutoff = calendar.date(from: components) else { return false }
        return now > cutoff
    }

    private func canDismiss(route: AppRoute?) -> Bool {
        guard let route else { return true }
        switch route {
        case .settlement:
            guard let settlement = dashboardSnapshot?.latestSettlement,
                  let userId = currentUserId else {
                return true
            }
            return settlement.pendingAcknowledgementUserIds.contains(userId) == false
        default:
            return true
        }
    }

    private func startDashboardSyncIfNeeded() {
        guard dashboardSyncTask == nil else { return }
        guard phase == .ready else { return }

        dashboardSyncTask = Task { [weak self] in
            while Task.isCancelled == false {
                do {
                    try await Task.sleep(nanoseconds: self?.dashboardSyncIntervalNanoseconds ?? 0)
                } catch {
                    break
                }
                guard Task.isCancelled == false else { break }
                await self?.refreshDashboard()
            }
        }
    }

    private func stopDashboardSync() {
        dashboardSyncTask?.cancel()
        dashboardSyncTask = nil
    }

    private func syncCurrentDeviceInstallation(for user: UserProfile) async {
        let timezone = TimeZone.current
        let now = environment.now()
        let context = LocalTimeContextFactory.make(from: now, timezone: timezone)
        let timeSensitive = await NotificationService.isTimeSensitiveAuthorized()
        let installation = DeviceInstallation(
            id: "ios_\(user.id)",
            userId: user.id,
            fcmToken: cachedFCMToken,
            apnsToken: cachedAPNsToken,
            timezone: timezone.identifier,
            utcOffsetMinutes: context.utcOffsetMinutes,
            lastLocalDateKey: context.dateKey,
            supportsLiveActivities: true,
            supportsTimeSensitive: timeSensitive,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            updatedAt: now
        )

        do {
            try await environment.deviceInstallationRepository.upsertInstallation(installation)
        } catch {
            latestError = error.localizedDescription
        }
    }

    private func syncPushTokensIfNeeded() async {
        guard let userId = currentUserId else { return }
        guard let user = try? await environment.userRepository.fetchUser(userId: userId) else { return }
        await syncCurrentDeviceInstallation(for: user)
    }

    // MARK: - Live Activity Helpers

    private func startOrUpdatePlanningActivity(
        dateKey: String,
        state: PlanningReminderAttributes.ContentState
    ) {
        let existingActivities = Activity<PlanningReminderAttributes>.activities
        if let existing = existingActivities.first {
            Task {
                await existing.update(
                    ActivityContent(state: state, staleDate: nil)
                )
            }
        } else {
            let attributes = PlanningReminderAttributes(dateKey: dateKey)
            let content = ActivityContent(state: state, staleDate: nil)
            _ = try? Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        }
    }

    private func endPlanningActivity() {
        for activity in Activity<PlanningReminderAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func startOrUpdateSettlementActivity(
        dateKey: String,
        state: DailySettlementAttributes.ContentState
    ) {
        let existingActivities = Activity<DailySettlementAttributes>.activities
        if let existing = existingActivities.first {
            Task {
                await existing.update(
                    ActivityContent(state: state, staleDate: nil)
                )
            }
        } else {
            let attributes = DailySettlementAttributes(dateKey: dateKey)
            let content = ActivityContent(state: state, staleDate: nil)
            _ = try? Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        }
    }

    private func endSettlementActivity() {
        for activity in Activity<DailySettlementAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func isPlanningWindowOpen(
        reminderConfig: ReminderConfig,
        now: Date,
        timezone: TimeZone
    ) -> Bool {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timezone
        var components = calendar.dateComponents([.year, .month, .day], from: now)

        components.hour = reminderConfig.planningReminderTime.hour
        components.minute = reminderConfig.planningReminderTime.minute
        components.second = 0
        guard let reminderStart = calendar.date(from: components) else { return false }

        components.hour = 23
        components.minute = 59
        components.second = 59
        guard let windowEnd = calendar.date(from: components) else { return false }

        return now >= reminderStart && now <= windowEnd
    }

    private func planningRemainingMinutes(
        cutoffTime: LocalClockTime,
        now: Date,
        timezone: TimeZone
    ) -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timezone
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = cutoffTime.hour
        components.minute = cutoffTime.minute
        components.second = 0
        guard let cutoff = calendar.date(from: components) else { return 0 }
        let remaining = Int(cutoff.timeIntervalSince(now) / 60)
        return max(remaining, 0)
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
        guard let userId = currentUserId else { return 1000 }
        let tasks = try await environment.taskRepository.fetchTasks(userId: userId, dateKey: dateKey)
        let maxSortOrder = tasks.map { $0.sortOrder }.max() ?? 0
        return ((maxSortOrder / 1000) + 1) * 1000
    }

    private func applyDeferredRouteIfPossible() {
        guard let route = deferredRoute, phase == .ready else { return }
        deferredRoute = nil
        navigate(to: route)
    }

    private func resetToSignedOutState() {
        stopDashboardSync()
        deferredRoute = nil
        isBootstrapped = false
        path = []
        fullScreenRoute = nil
        dashboardSnapshot = nil
        paymentRecords = []
        planningDraftTasks = []
        rewardDraftText = ""
        settingsDraft = nil
        noRequiredTasksConfirmed = false
        currentSession = nil
        currentUserId = nil
        pairingCouple = nil
        authInFlightProvider = nil
        isPairingActionInFlight = false
        phase = .auth
    }
}

private extension AppRoute {
    var requiresAuthentication: Bool {
        switch self {
        case .auth:
            return false
        default:
            return true
        }
    }

    var requiresActiveCouple: Bool {
        switch self {
        case .planning, .settlement, .settlementHistory, .payment, .rewards, .dashboard, .settings:
            return true
        case .auth, .pairing:
            return false
        }
    }
}

private extension UNAuthorizationStatus {
    var displayText: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
}

private extension String {
    var normalizedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
