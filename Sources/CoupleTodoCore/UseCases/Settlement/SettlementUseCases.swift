import Foundation

public struct AcknowledgeSettlementRequest: Sendable {
    public let coupleId: String
    public let settlementId: String
    public let userId: String

    public init(coupleId: String, settlementId: String, userId: String) {
        self.coupleId = coupleId
        self.settlementId = settlementId
        self.userId = userId
    }
}

public enum AcknowledgeSettlementError: Error, Equatable {
    case settlementNotFound
}

public struct AcknowledgeSettlementUseCase: Sendable {
    private let settlementRepository: SettlementRepository

    public init(settlementRepository: SettlementRepository) {
        self.settlementRepository = settlementRepository
    }

    @discardableResult
    public func execute(_ request: AcknowledgeSettlementRequest) async throws -> DailySettlement {
        guard try await settlementRepository.fetchSettlement(coupleId: request.coupleId, settlementId: request.settlementId) != nil else {
            throw AcknowledgeSettlementError.settlementNotFound
        }

        try await settlementRepository.acknowledgeSettlement(
            coupleId: request.coupleId,
            settlementId: request.settlementId,
            userId: request.userId
        )

        guard let settlement = try await settlementRepository.fetchSettlement(coupleId: request.coupleId, settlementId: request.settlementId) else {
            throw AcknowledgeSettlementError.settlementNotFound
        }
        return settlement
    }
}

public struct FinalizeDailySettlementRequest: Sendable {
    public let coupleId: String
    public let subjectUserId: String
    public let counterpartyUserId: String
    public let dateKey: String
    public let timezone: TimeZone
    public let cutoff: Date
    public let finalizedAt: Date

    public init(
        coupleId: String,
        subjectUserId: String,
        counterpartyUserId: String,
        dateKey: String,
        timezone: TimeZone,
        cutoff: Date,
        finalizedAt: Date
    ) {
        self.coupleId = coupleId
        self.subjectUserId = subjectUserId
        self.counterpartyUserId = counterpartyUserId
        self.dateKey = dateKey
        self.timezone = timezone
        self.cutoff = cutoff
        self.finalizedAt = finalizedAt
    }
}

public enum FinalizeDailySettlementError: Error, Equatable {
    case coupleNotFound
}

public struct FinalizeDailySettlementUseCase: Sendable {
    private let coupleRepository: CoupleRepository
    private let planRepository: PlanRepository
    private let taskRepository: TaskRepository
    private let settlementRepository: SettlementRepository
    private let rewardWeekRepository: RewardWeekRepository
    private let eventRepository: EventRepository

    public init(
        coupleRepository: CoupleRepository,
        planRepository: PlanRepository,
        taskRepository: TaskRepository,
        settlementRepository: SettlementRepository,
        rewardWeekRepository: RewardWeekRepository,
        eventRepository: EventRepository
    ) {
        self.coupleRepository = coupleRepository
        self.planRepository = planRepository
        self.taskRepository = taskRepository
        self.settlementRepository = settlementRepository
        self.rewardWeekRepository = rewardWeekRepository
        self.eventRepository = eventRepository
    }

    @discardableResult
    public func execute(_ request: FinalizeDailySettlementRequest) async throws -> DailySettlement {
        guard let couple = try await coupleRepository.fetchCouple(coupleId: request.coupleId) else {
            throw FinalizeDailySettlementError.coupleNotFound
        }

        let tasks = try await taskRepository.fetchTasks(userId: request.subjectUserId, dateKey: request.dateKey)
        let plan = try await planRepository.fetchPlan(userId: request.subjectUserId, dateKey: request.dateKey)
        let engine = SettlementEngine(penaltyAmount: couple.penaltyPolicy.enabled ? couple.penaltyPolicy.amount : 0)
        let settlementResult = engine.computeUserSettlement(
            for: request.subjectUserId,
            on: request.dateKey,
            cutoff: request.cutoff,
            tasks: tasks
        )

        let weekKey = LocalTimeContextFactory.weekKey(from: request.finalizedAt, timezone: request.timezone)
        let latestCounterpartySettlement = try await settlementRepository.fetchLatestSettlement(
            coupleId: request.coupleId,
            subjectUserId: request.counterpartyUserId
        )

        var rewardImpact: RewardImpact?
        if var rewardWeek = try await rewardWeekRepository.fetchRewardWeek(coupleId: request.coupleId, weekKey: weekKey) {
            let eligible = settlementResult.outcome == .pass && plan?.planningMissed != true && (rewardWeek.eligibility[request.subjectUserId] ?? true)
            rewardWeek.eligibility[request.subjectUserId] = eligible
            rewardWeek.memberLocalWeekKeys[request.subjectUserId] = weekKey
            if rewardWeek.status == .draft {
                rewardWeek.status = .active
            }
            rewardWeek.updatedAt = request.finalizedAt
            try await rewardWeekRepository.upsertRewardWeek(rewardWeek)
            rewardImpact = RewardImpact(weekKey: weekKey, stillEligible: eligible)
        }

        let settlement = DailySettlement(
            id: "\(request.subjectUserId)_\(request.dateKey)",
            coupleId: request.coupleId,
            subjectUserId: request.subjectUserId,
            counterpartyUserId: request.counterpartyUserId,
            dateKey: request.dateKey,
            localTimezone: request.timezone.identifier,
            localWeekKey: weekKey,
            state: .finalized,
            computedAt: request.finalizedAt,
            graceAppliedUntil: request.cutoff,
            subjectResult: settlementResult,
            counterpartySnapshot: CounterpartySettlementSnapshot(
                latestKnownDateKey: latestCounterpartySettlement?.dateKey,
                latestKnownOutcome: latestCounterpartySettlement?.subjectResult.outcome
            ),
            pendingAcknowledgementUserIds: couple.memberIds,
            rewardImpact: rewardImpact
        )

        try await settlementRepository.upsertSettlement(settlement)
        try await eventRepository.appendEvent(
            EventLogEntry(
                id: UUID().uuidString.lowercased(),
                coupleId: request.coupleId,
                type: .settlementFinalized,
                actorUserId: "system",
                subjectId: settlement.id,
                payload: ["dateKey": request.dateKey, "subjectUserId": request.subjectUserId],
                createdAt: request.finalizedAt
            )
        )

        return settlement
    }
}
