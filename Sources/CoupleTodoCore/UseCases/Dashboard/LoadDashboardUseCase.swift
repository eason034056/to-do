import Foundation

public struct LoadDashboardRequest: Sendable {
    public let userId: String
    public let now: Date

    public init(userId: String, now: Date) {
        self.userId = userId
        self.now = now
    }
}

public enum LoadDashboardError: Error, Equatable {
    case userNotFound
    case coupleNotFound
    case partnerNotFound
    case invalidTimezone(String)
}

public struct LoadDashboardUseCase: Sendable {
    private let userRepository: UserRepository
    private let coupleRepository: CoupleRepository
    private let planRepository: PlanRepository
    private let taskRepository: TaskRepository
    private let settlementRepository: SettlementRepository
    private let rewardWeekRepository: RewardWeekRepository
    private let paymentRepository: PaymentRepository

    public init(
        userRepository: UserRepository,
        coupleRepository: CoupleRepository,
        planRepository: PlanRepository,
        taskRepository: TaskRepository,
        settlementRepository: SettlementRepository,
        rewardWeekRepository: RewardWeekRepository,
        paymentRepository: PaymentRepository
    ) {
        self.userRepository = userRepository
        self.coupleRepository = coupleRepository
        self.planRepository = planRepository
        self.taskRepository = taskRepository
        self.settlementRepository = settlementRepository
        self.rewardWeekRepository = rewardWeekRepository
        self.paymentRepository = paymentRepository
    }

    public func execute(_ request: LoadDashboardRequest) async throws -> DashboardSnapshot {
        guard let user = try await userRepository.fetchUser(userId: request.userId) else {
            throw LoadDashboardError.userNotFound
        }
        guard let coupleId = user.coupleId,
              let couple = try await coupleRepository.fetchCouple(coupleId: coupleId) else {
            throw LoadDashboardError.coupleNotFound
        }
        guard let partnerId = couple.memberIds.first(where: { $0 != user.id }),
              let partner = try await userRepository.fetchUser(userId: partnerId) else {
            throw LoadDashboardError.partnerNotFound
        }

        guard let userTimezone = TimeZone(identifier: user.currentTimezone) else {
            throw LoadDashboardError.invalidTimezone(user.currentTimezone)
        }
        guard let partnerTimezone = TimeZone(identifier: partner.currentTimezone) else {
            throw LoadDashboardError.invalidTimezone(partner.currentTimezone)
        }

        let selfContext = LocalTimeContextFactory.make(from: request.now, timezone: userTimezone)
        let partnerContext = LocalTimeContextFactory.make(from: request.now, timezone: partnerTimezone)

        let selfTasks = try await taskRepository.fetchTasks(userId: user.id, dateKey: selfContext.dateKey)
        let partnerTasks = try await taskRepository.fetchTasks(userId: partner.id, dateKey: partnerContext.dateKey)

        let selfPlanningDateKey = LocalTimeContextFactory.nextDateKey(from: request.now, timezone: userTimezone)
        let partnerPlanningDateKey = LocalTimeContextFactory.nextDateKey(from: request.now, timezone: partnerTimezone)

        let selfPlan = try await planRepository.fetchPlan(userId: user.id, dateKey: selfPlanningDateKey)
        let partnerPlan = try await planRepository.fetchPlan(userId: partner.id, dateKey: partnerPlanningDateKey)
        let latestSettlement = try await settlementRepository.fetchLatestSettlement(coupleId: couple.id, subjectUserId: user.id)
        let partnerLatestSettlement = try await settlementRepository.fetchLatestSettlement(coupleId: couple.id, subjectUserId: partner.id)
        let rewardWeek = try await rewardWeekRepository.fetchRewardWeek(coupleId: couple.id, weekKey: selfContext.weekKey)
        let pendingPayments = try await paymentRepository.fetchPayments(coupleId: couple.id, userId: user.id)
            .filter { $0.status == .pending }

        return DashboardSnapshot(
            user: user,
            partner: partner,
            couple: couple,
            selfContext: selfContext,
            partnerContext: partnerContext,
            selfRequired: filteredTasks(
                selfTasks,
                bucket: .required,
                isServerFinal: isServerFinal(settlement: latestSettlement, dateKey: selfContext.dateKey)
            ),
            selfOptional: filteredTasks(
                selfTasks,
                bucket: .optional,
                isServerFinal: isServerFinal(settlement: latestSettlement, dateKey: selfContext.dateKey)
            ),
            partnerRequired: filteredTasks(
                partnerTasks,
                bucket: .required,
                isServerFinal: isServerFinal(settlement: partnerLatestSettlement, dateKey: partnerContext.dateKey)
            ),
            partnerOptional: filteredTasks(
                partnerTasks,
                bucket: .optional,
                isServerFinal: isServerFinal(settlement: partnerLatestSettlement, dateKey: partnerContext.dateKey)
            ),
            selfSubmittedNextPlan: selfPlan?.submittedAt != nil,
            partnerSubmittedNextPlan: partnerPlan?.submittedAt != nil,
            planningTargetDateKey: selfPlanningDateKey,
            selfPlanningCountdownMinutes: countdownMinutesToNext(
                hour: couple.reminderConfig.planningReminderTime.hour,
                minute: couple.reminderConfig.planningReminderTime.minute,
                now: request.now,
                timezone: userTimezone
            ),
            partnerPlanningCountdownMinutes: countdownMinutesToNext(
                hour: couple.reminderConfig.planningReminderTime.hour,
                minute: couple.reminderConfig.planningReminderTime.minute,
                now: request.now,
                timezone: partnerTimezone
            ),
            selfSettlementCountdownMinutes: countdownMinutesToNext(
                hour: couple.reminderConfig.dailySettlementTime.hour,
                minute: couple.reminderConfig.dailySettlementTime.minute,
                additionalMinutes: couple.reminderConfig.dailySettlementGraceMinutes,
                now: request.now,
                timezone: userTimezone
            ),
            partnerSettlementCountdownMinutes: countdownMinutesToNext(
                hour: couple.reminderConfig.dailySettlementTime.hour,
                minute: couple.reminderConfig.dailySettlementTime.minute,
                additionalMinutes: couple.reminderConfig.dailySettlementGraceMinutes,
                now: request.now,
                timezone: partnerTimezone
            ),
            latestSettlement: latestSettlement,
            currentRewardWeek: rewardWeek,
            pendingPayments: pendingPayments,
            pendingGate: pendingGate(
                latestSettlement: latestSettlement,
                couple: couple,
                plan: selfPlan,
                now: request.now,
                timezone: userTimezone,
                planningDateKey: selfPlanningDateKey,
                userId: user.id
            )
        )
    }

    private func filteredTasks(_ tasks: [TodoTask], bucket: TaskBucket, isServerFinal: Bool) -> [TodoTask] {
        let normalized = tasks
            .filter { $0.bucket == bucket && $0.deleted == false }
            .map { task -> TodoTask in
                var task = task
                if isServerFinal {
                    task.syncState = .serverFinal
                } else if task.syncState == .localPending {
                    task.syncState = .synced
                }
                return task
            }
        return TaskSortingService.sort(normalized)
    }

    private func isServerFinal(settlement: DailySettlement?, dateKey: String) -> Bool {
        guard let settlement else { return false }
        return settlement.dateKey == dateKey && settlement.state == .finalized
    }

    private func countdownMinutesToNext(
        hour: Int,
        minute: Int,
        additionalMinutes: Int = 0,
        now: Date,
        timezone: TimeZone
    ) -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timezone

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard var boundary = calendar.date(from: components) else { return 0 }
        if additionalMinutes > 0 {
            boundary = calendar.date(byAdding: .minute, value: additionalMinutes, to: boundary) ?? boundary
        }
        if boundary <= now {
            boundary = calendar.date(byAdding: .day, value: 1, to: boundary) ?? boundary
        }

        return max(0, Int(ceil(boundary.timeIntervalSince(now) / 60.0)))
    }

    private func pendingGate(
        latestSettlement: DailySettlement?,
        couple: Couple,
        plan: DailyPlan?,
        now: Date,
        timezone: TimeZone,
        planningDateKey: String,
        userId: String
    ) -> DashboardPendingGate? {
        if let latestSettlement,
           latestSettlement.pendingAcknowledgementUserIds.contains(userId) {
            return .settlement(dateKey: latestSettlement.dateKey)
        }

        let planningPolicy = PlanningWindowPolicy(
            reminderTime: couple.reminderConfig.planningReminderTime,
            cutoffTime: couple.reminderConfig.planningCutoffTime
        )
        if case .withinWindow = planningPolicy.validate(submittedAt: now, timezone: timezone),
           plan?.submittedAt == nil,
           plan?.planningMissed != true {
            return .planning(dateKey: planningDateKey)
        }

        return nil
    }
}
