import XCTest
@testable import CoupleTodoFirebase
import CoupleTodoCore

@MainActor
final class UserProfileBootstrapperTests: XCTestCase {
    func testEnsureProfileCreatesUserAndPreservesLaterCoupleMembership() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let repository = TestUserRepository()
        let bootstrapper = UserProfileBootstrapper(userRepository: repository)

        let created = try await bootstrapper.ensureProfile(
            for: AuthSession(userId: "usr_1", displayName: "W"),
            now: now,
            timezone: TimeZone(identifier: "America/Chicago") ?? .current
        )

        var paired = created
        paired.coupleId = "cpl_1"
        try await repository.upsertUser(paired)

        let refreshed = try await bootstrapper.ensureProfile(
            for: AuthSession(userId: "usr_1", displayName: "W Updated"),
            now: now.addingTimeInterval(60),
            timezone: TimeZone(identifier: "Asia/Tokyo") ?? .current
        )

        XCTAssertEqual(refreshed.id, "usr_1")
        XCTAssertEqual(refreshed.displayName, "W Updated")
        XCTAssertEqual(refreshed.coupleId, "cpl_1")
        XCTAssertEqual(refreshed.currentTimezone, "Asia/Tokyo")
    }
}

private actor TestUserRepository: UserRepository {
    private var storage: [String: UserProfile] = [:]

    func fetchUser(userId: String) async throws -> UserProfile? {
        storage[userId]
    }

    func upsertUser(_ user: UserProfile) async throws {
        storage[user.id] = user
    }
}
