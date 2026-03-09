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

    public init(
        userRepository: UserRepository,
        coupleRepository: CoupleRepository,
        planRepository: PlanRepository,
        taskRepository: TaskRepository,
        settlementRepository: SettlementRepository,
        rewardWeekRepository: RewardWeekRepository
    ) {
        self.userRepository = userRepository
        self.coupleRepository = coupleRepository
        self.planRepository = planRepository
        self.taskRepository = taskRepository
        self.settlementRepository = settlementRepository
        self.rewardWeekRepository = rewardWeekRepository
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
        let rewardWeek = try await rewardWeekRepository.fetchRewardWeek(coupleId: couple.id, weekKey: selfContext.weekKey)

        return DashboardSnapshot(
            user: user,
            partner: partner,
            couple: couple,
            selfContext: selfContext,
            partnerContext: partnerContext,
            selfRequired: filteredTasks(selfTasks, bucket: .required),
            selfOptional: filteredTasks(selfTasks, bucket: .optional),
            partnerRequired: filteredTasks(partnerTasks, bucket: .required),
            partnerOptional: filteredTasks(partnerTasks, bucket: .optional),
            selfSubmittedNextPlan: selfPlan?.submittedAt != nil,
            partnerSubmittedNextPlan: partnerPlan?.submittedAt != nil,
            planningTargetDateKey: selfPlanningDateKey,
            latestSettlement: latestSettlement,
            currentRewardWeek: rewardWeek,
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

    private func filteredTasks(_ tasks: [TodoTask], bucket: TaskBucket) -> [TodoTask] {
        TaskSortingService.sort(tasks.filter { $0.bucket == bucket && $0.deleted == false })
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
           plan?.submittedAt == nil {
            return .planning(dateKey: planningDateKey)
        }

        return nil
    }
}
