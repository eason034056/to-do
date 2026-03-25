import Foundation

public struct MarkPlanningMissedRequest: Sendable {
    public let userId: String
    public let coupleId: String
    public let dateKey: String
    public let timezone: TimeZone
    public let now: Date

    public init(userId: String, coupleId: String, dateKey: String, timezone: TimeZone, now: Date) {
        self.userId = userId
        self.coupleId = coupleId
        self.dateKey = dateKey
        self.timezone = timezone
        self.now = now
    }
}

public struct MarkPlanningMissedUseCase: Sendable {
    private let planRepository: PlanRepository
    private let eventRepository: EventRepository

    public init(planRepository: PlanRepository, eventRepository: EventRepository) {
        self.planRepository = planRepository
        self.eventRepository = eventRepository
    }

    @discardableResult
    public func execute(_ request: MarkPlanningMissedRequest) async throws -> DailyPlan {
        if let existing = try await planRepository.fetchPlan(userId: request.userId, dateKey: request.dateKey),
           existing.planningMissed {
            return existing
        }

        var plan = try await planRepository.fetchPlan(userId: request.userId, dateKey: request.dateKey) ?? DailyPlan(
            id: "\(request.userId)_\(request.dateKey)",
            userId: request.userId,
            coupleId: request.coupleId,
            dateKey: request.dateKey,
            localTimezone: request.timezone.identifier,
            submittedAt: nil,
            planningMissed: false,
            localUtcOffsetMinutes: request.timezone.secondsFromGMT(for: request.now) / 60,
            lastEditedAt: request.now,
            requiredCount: 0,
            optionalCount: 0,
            version: 1
        )
        plan.planningMissed = true
        plan.lastEditedAt = request.now
        plan.version += 1

        try await planRepository.upsertPlan(plan)
        try await eventRepository.appendEvent(
            EventLogEntry(
                id: UUID().uuidString.lowercased(),
                coupleId: request.coupleId,
                type: .planningMissed,
                actorUserId: request.userId,
                subjectId: plan.id,
                payload: ["dateKey": request.dateKey],
                createdAt: request.now
            )
        )

        return plan
    }
}
