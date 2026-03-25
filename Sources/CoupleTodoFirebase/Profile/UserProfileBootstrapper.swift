import CoupleTodoCore
import Foundation

@MainActor
public struct UserProfileBootstrapper {
    private let userRepository: UserRepository

    public init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    public func ensureProfile(for session: AuthSession, now: Date = Date(), timezone: TimeZone = .current) async throws -> UserProfile {
        let context = LocalTimeContextFactory.make(from: now, timezone: timezone)
        let existing = try await userRepository.fetchUser(userId: session.userId)

        var profile = existing ?? UserProfile(
            id: session.userId,
            displayName: session.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Partner",
            photoURL: session.photoURL,
            coupleId: nil,
            currentTimezone: timezone.identifier,
            currentUtcOffsetMinutes: context.utcOffsetMinutes,
            lastLocalDateKey: context.dateKey,
            lastLocalWeekKey: context.weekKey,
            createdAt: now,
            updatedAt: now
        )

        if let displayName = session.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            profile.displayName = displayName
        }
        profile.photoURL = session.photoURL ?? profile.photoURL
        profile.currentTimezone = timezone.identifier
        profile.currentUtcOffsetMinutes = context.utcOffsetMinutes
        profile.lastLocalDateKey = context.dateKey
        profile.lastLocalWeekKey = context.weekKey
        profile.updatedAt = now

        try await userRepository.upsertUser(profile)
        return profile
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
