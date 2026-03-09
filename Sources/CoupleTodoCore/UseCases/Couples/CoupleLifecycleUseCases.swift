import Foundation

public struct CreateCoupleRequest: Sendable {
    public let creatorUserId: String
    public let now: Date
    public let weekStartsOn: WeekStart
    public let penaltyPolicy: PenaltyPolicy
    public let reminderConfig: ReminderConfig

    public init(
        creatorUserId: String,
        now: Date,
        weekStartsOn: WeekStart = .monday,
        penaltyPolicy: PenaltyPolicy = .default,
        reminderConfig: ReminderConfig = .default
    ) {
        self.creatorUserId = creatorUserId
        self.now = now
        self.weekStartsOn = weekStartsOn
        self.penaltyPolicy = penaltyPolicy
        self.reminderConfig = reminderConfig
    }
}

public struct CreateCoupleResult: Sendable, Equatable {
    public let couple: Couple
    public let inviteCode: String

    public init(couple: Couple, inviteCode: String) {
        self.couple = couple
        self.inviteCode = inviteCode
    }
}

public enum CreateCoupleError: Error, Equatable {
    case userNotFound
    case userAlreadyPaired
}

public struct CreateCoupleUseCase: Sendable {
    private let userRepository: UserRepository
    private let coupleRepository: CoupleRepository

    public init(userRepository: UserRepository, coupleRepository: CoupleRepository) {
        self.userRepository = userRepository
        self.coupleRepository = coupleRepository
    }

    public func execute(_ request: CreateCoupleRequest) async throws -> CreateCoupleResult {
        guard var user = try await userRepository.fetchUser(userId: request.creatorUserId) else {
            throw CreateCoupleError.userNotFound
        }
        if user.coupleId != nil {
            throw CreateCoupleError.userAlreadyPaired
        }

        let inviteCode = Self.generateInviteCode()
        let couple = Couple(
            id: "cpl_\(UUID().uuidString.lowercased())",
            memberIds: [request.creatorUserId],
            status: .pending,
            weekStartsOn: request.weekStartsOn,
            penaltyPolicy: request.penaltyPolicy,
            reminderConfig: request.reminderConfig,
            inviteCode: inviteCode,
            createdAt: request.now,
            updatedAt: request.now
        )

        user.coupleId = couple.id
        user.updatedAt = request.now

        try await coupleRepository.upsertCouple(couple)
        try await userRepository.upsertUser(user)

        return CreateCoupleResult(couple: couple, inviteCode: inviteCode)
    }

    private static func generateInviteCode() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
    }
}

public struct JoinCoupleRequest: Sendable {
    public let userId: String
    public let inviteCode: String
    public let now: Date

    public init(userId: String, inviteCode: String, now: Date) {
        self.userId = userId
        self.inviteCode = inviteCode
        self.now = now
    }
}

public enum JoinCoupleError: Error, Equatable {
    case userNotFound
    case inviteNotFound
    case userAlreadyPaired
    case coupleFull
}

public struct JoinCoupleUseCase: Sendable {
    private let userRepository: UserRepository
    private let coupleRepository: CoupleRepository

    public init(userRepository: UserRepository, coupleRepository: CoupleRepository) {
        self.userRepository = userRepository
        self.coupleRepository = coupleRepository
    }

    public func execute(_ request: JoinCoupleRequest) async throws -> Couple {
        guard var user = try await userRepository.fetchUser(userId: request.userId) else {
            throw JoinCoupleError.userNotFound
        }
        if user.coupleId != nil {
            throw JoinCoupleError.userAlreadyPaired
        }

        guard var couple = try await coupleRepository.findCouple(inviteCode: request.inviteCode) else {
            throw JoinCoupleError.inviteNotFound
        }
        if couple.memberIds.count >= 2 {
            throw JoinCoupleError.coupleFull
        }

        if couple.memberIds.contains(request.userId) == false {
            couple.memberIds.append(request.userId)
        }
        couple.status = .active
        couple.updatedAt = request.now

        user.coupleId = couple.id
        user.updatedAt = request.now

        try await coupleRepository.upsertCouple(couple)
        try await userRepository.upsertUser(user)

        return couple
    }
}
