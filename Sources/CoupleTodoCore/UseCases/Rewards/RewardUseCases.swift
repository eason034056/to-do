import Foundation

public struct SaveNextWeekRewardRequest: Sendable {
    public let coupleId: String
    public let actorUserId: String
    public let rewardText: String
    public let now: Date
    public let timezone: TimeZone

    public init(coupleId: String, actorUserId: String, rewardText: String, now: Date, timezone: TimeZone) {
        self.coupleId = coupleId
        self.actorUserId = actorUserId
        self.rewardText = rewardText
        self.now = now
        self.timezone = timezone
    }
}

public enum SaveNextWeekRewardError: Error, Equatable, LocalizedError {
    case coupleNotFound
    case forbidden
    case emptyRewardText
    case rewardLocked

    public var errorDescription: String? {
        switch self {
        case .coupleNotFound: "Couple not found."
        case .forbidden: "You don't have permission to edit this reward."
        case .emptyRewardText: "Reward text cannot be empty."
        case .rewardLocked: "This reward is locked. You can only edit rewards that are still in draft."
        }
    }
}

public struct SaveNextWeekRewardUseCase: Sendable {
    private let coupleRepository: CoupleRepository
    private let rewardWeekRepository: RewardWeekRepository
    private let eventRepository: EventRepository

    public init(
        coupleRepository: CoupleRepository,
        rewardWeekRepository: RewardWeekRepository,
        eventRepository: EventRepository
    ) {
        self.coupleRepository = coupleRepository
        self.rewardWeekRepository = rewardWeekRepository
        self.eventRepository = eventRepository
    }

    @discardableResult
    public func execute(_ request: SaveNextWeekRewardRequest) async throws -> RewardWeek {
        let trimmedRewardText = request.rewardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedRewardText.isEmpty == false else {
            throw SaveNextWeekRewardError.emptyRewardText
        }
        guard let couple = try await coupleRepository.fetchCouple(coupleId: request.coupleId) else {
            throw SaveNextWeekRewardError.coupleNotFound
        }
        guard couple.memberIds.contains(request.actorUserId) else {
            throw SaveNextWeekRewardError.forbidden
        }

        let currentWeekKey = LocalTimeContextFactory.weekKey(from: request.now, timezone: request.timezone)
        let nextWeekKey = LocalTimeContextFactory.nextWeekKey(from: request.now, timezone: request.timezone)
        let nextWeekDate = Calendar(identifier: .iso8601).date(byAdding: .day, value: 7, to: request.now) ?? request.now
        let effectiveWeekStartDate = LocalTimeContextFactory.dateKey(
            from: LocalTimeContextFactory.startOfWeek(
                from: nextWeekDate,
                weekStartsOn: couple.weekStartsOn,
                timezone: request.timezone
            ),
            timezone: request.timezone
        )

        var rewardWeek = try await rewardWeekRepository.fetchRewardWeek(coupleId: request.coupleId, weekKey: nextWeekKey) ?? RewardWeek(
            id: "\(request.coupleId)_\(nextWeekKey)",
            coupleId: request.coupleId,
            weekKey: nextWeekKey,
            effectiveWeekStartDate: effectiveWeekStartDate,
            draftedInWeekKey: currentWeekKey,
            rewardText: trimmedRewardText,
            status: .draft,
            eligibility: Dictionary(uniqueKeysWithValues: couple.memberIds.map { ($0, true) }),
            memberLocalWeekKeys: [:],
            updatedAt: request.now
        )
        guard rewardWeek.status == .draft else {
            throw SaveNextWeekRewardError.rewardLocked
        }

        rewardWeek.rewardText = trimmedRewardText
        rewardWeek.draftedInWeekKey = currentWeekKey
        rewardWeek.effectiveWeekStartDate = effectiveWeekStartDate
        rewardWeek.updatedAt = request.now

        try await rewardWeekRepository.upsertRewardWeek(rewardWeek)
        try await eventRepository.appendEvent(
            EventLogEntry(
                id: UUID().uuidString.lowercased(),
                coupleId: request.coupleId,
                type: .weeklyRewardDrafted,
                actorUserId: request.actorUserId,
                subjectId: rewardWeek.id,
                payload: ["weekKey": rewardWeek.weekKey],
                createdAt: request.now
            )
        )

        return rewardWeek
    }
}

public struct FinalizeWeeklyRewardRequest: Sendable {
    public let coupleId: String
    public let weekKey: String
    public let memberCurrentWeekKeys: [String: String]
    public let now: Date

    public init(coupleId: String, weekKey: String, memberCurrentWeekKeys: [String: String], now: Date) {
        self.coupleId = coupleId
        self.weekKey = weekKey
        self.memberCurrentWeekKeys = memberCurrentWeekKeys
        self.now = now
    }
}

public enum FinalizeWeeklyRewardError: Error, Equatable {
    case rewardWeekNotFound
    case notReadyToFinalize
}

public struct FinalizeWeeklyRewardUseCase: Sendable {
    private let rewardWeekRepository: RewardWeekRepository
    private let eventRepository: EventRepository

    public init(rewardWeekRepository: RewardWeekRepository, eventRepository: EventRepository) {
        self.rewardWeekRepository = rewardWeekRepository
        self.eventRepository = eventRepository
    }

    @discardableResult
    public func execute(_ request: FinalizeWeeklyRewardRequest) async throws -> RewardWeek {
        guard var rewardWeek = try await rewardWeekRepository.fetchRewardWeek(coupleId: request.coupleId, weekKey: request.weekKey) else {
            throw FinalizeWeeklyRewardError.rewardWeekNotFound
        }

        let allMembersClosedWeek = request.memberCurrentWeekKeys.values.allSatisfy { $0 != request.weekKey }
        guard allMembersClosedWeek else {
            throw FinalizeWeeklyRewardError.notReadyToFinalize
        }

        rewardWeek.memberLocalWeekKeys = request.memberCurrentWeekKeys
        rewardWeek.updatedAt = request.now

        if rewardWeek.eligibility.values.allSatisfy({ $0 }) {
            rewardWeek.status = .earned
            rewardWeek.earnedAt = request.now
        } else {
            rewardWeek.status = .missed
            rewardWeek.missedAt = request.now
        }

        try await rewardWeekRepository.upsertRewardWeek(rewardWeek)
        try await eventRepository.appendEvent(
            EventLogEntry(
                id: UUID().uuidString.lowercased(),
                coupleId: request.coupleId,
                type: rewardWeek.status == .earned ? .weeklyRewardEarned : .weeklyRewardMissed,
                actorUserId: "system",
                subjectId: rewardWeek.id,
                payload: ["weekKey": rewardWeek.weekKey],
                createdAt: request.now
            )
        )

        return rewardWeek
    }
}
