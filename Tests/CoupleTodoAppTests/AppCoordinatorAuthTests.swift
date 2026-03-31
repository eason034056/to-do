import XCTest
@testable import CoupleTodo
import CoupleTodoCore
import CoupleTodoFirebase

@MainActor
final class AppCoordinatorAuthTests: XCTestCase {
    func testSignOutClearsSessionAndReturnsToAuth() {
        let authService = StubAuthenticationService(session: AuthSession(userId: "usr_self"))
        let coordinator = AppCoordinator(environment: makeEnvironment(authService: authService))

        coordinator.currentSession = AuthSession(userId: "usr_self")
        coordinator.currentUserId = "usr_self"
        coordinator.phase = AppCoordinator.Phase.pairing
        coordinator.latestError = "Old error"

        coordinator.signOut()

        XCTAssertEqual(authService.signOutCallCount, 1)
        XCTAssertNil(coordinator.currentSession)
        XCTAssertNil(coordinator.currentUserId)
        XCTAssertNil(coordinator.pairingCouple)
        XCTAssertNil(coordinator.dashboardSnapshot)
        XCTAssertNil(coordinator.latestError)
        XCTAssertEqual(coordinator.phase, AppCoordinator.Phase.auth)
    }

    func testSignInWithGoogleFailureClearsAuthInFlightProvider() async {
        let coordinator = AppCoordinator(
            environment: makeEnvironment(
                authService: StubAuthenticationService(
                    signInHandler: { _ in throw StubAuthError.signInFailed }
                )
            )
        )

        await coordinator.signIn(with: .google)

        XCTAssertNil(coordinator.authInFlightProvider)
        XCTAssertEqual(coordinator.phase, AppCoordinator.Phase.auth)
        XCTAssertEqual(coordinator.latestError, StubAuthError.signInFailed.localizedDescription)
    }

    func testHandleIncomingURLDoesNotRouteWhenHandledByAuthenticationService() {
        let authService = StubAuthenticationService(handleOpenURLResult: true)
        let coordinator = AppCoordinator(environment: makeEnvironment(authService: authService))
        let url = URL(string: "coupletodo://planning/2026-03-25")!

        coordinator.handleIncomingURL(url)

        XCTAssertEqual(authService.handledURLs, [url])
        XCTAssertNil(coordinator.fullScreenRoute)
        XCTAssertTrue(coordinator.path.isEmpty)
    }

    func testHandleIncomingURLFallsBackToDeepLinkRoutingWhenAuthenticationServiceReturnsFalse() {
        let coordinator = AppCoordinator(
            environment: makeEnvironment(authService: StubAuthenticationService(handleOpenURLResult: false))
        )
        let url = URL(string: "coupletodo://planning/2026-03-25")!

        coordinator.currentSession = AuthSession(userId: "usr_self")
        coordinator.phase = AppCoordinator.Phase.ready
        coordinator.handleIncomingURL(url)

        XCTAssertEqual(coordinator.fullScreenRoute, AppRoute.planning(dateKey: "2026-03-25"))
    }

    private func makeEnvironment(authService: any AuthenticationService) -> AppEnvironment {
        AppEnvironment(
            authService: authService,
            coupleLifecycleGateway: StubCoupleLifecycleGateway(),
            userRepository: MemoryUserRepository(seed: []),
            coupleRepository: MemoryCoupleRepository(seed: []),
            deviceInstallationRepository: MemoryDeviceInstallationRepository(seed: []),
            planRepository: MemoryPlanRepository(seed: []),
            taskRepository: MemoryTaskRepository(seed: [:]),
            settlementRepository: MemorySettlementRepository(seed: []),
            rewardWeekRepository: MemoryRewardWeekRepository(seed: []),
            paymentRepository: MemoryPaymentRepository(seed: []),
            eventRepository: MemoryEventRepository(seed: []),
            sharedSnapshotWriter: SharedSnapshotWriter(),
            networkMonitor: StubNetworkMonitor(),
            nowProvider: Date.init
        )
    }
}

@MainActor
private final class StubAuthenticationService: AuthenticationService {
    private let signInHandler: @MainActor (AuthenticationProvider) async throws -> AuthSession
    private let session: AuthSession?
    private let handleOpenURLResult: Bool
    private let signOutHandler: () throws -> Void
    private(set) var handledURLs: [URL] = []
    private(set) var signOutCallCount = 0

    init(
        session: AuthSession? = nil,
        handleOpenURLResult: Bool = false,
        signOutHandler: @escaping () throws -> Void = {},
        signInHandler: @escaping @MainActor (AuthenticationProvider) async throws -> AuthSession = { provider in
            AuthSession(userId: "usr_\(provider.rawValue)")
        }
    ) {
        self.session = session
        self.handleOpenURLResult = handleOpenURLResult
        self.signOutHandler = signOutHandler
        self.signInHandler = signInHandler
    }

    func currentSession() -> AuthSession? {
        session
    }

    func signIn(with provider: AuthenticationProvider) async throws -> AuthSession {
        try await signInHandler(provider)
    }

    func handleOpenURL(_ url: URL) -> Bool {
        handledURLs.append(url)
        return handleOpenURLResult
    }

    func signOut() throws {
        signOutCallCount += 1
        try signOutHandler()
    }
}

private final class StubCoupleLifecycleGateway: CoupleLifecycleGateway {
    func createCouple(
        weekStartsOn: WeekStart,
        reminderConfig: ReminderConfig,
        penaltyPolicy: PenaltyPolicy
    ) async throws -> PairingResult {
        PairingResult(coupleId: "cpl_1", memberIds: ["usr_self"], status: .pending, inviteCode: "ABC123")
    }

    func joinCouple(inviteCode: String) async throws -> PairingResult {
        PairingResult(coupleId: "cpl_1", memberIds: ["usr_self", "usr_partner"], status: .active, inviteCode: inviteCode)
    }

    func deleteAccount() async throws {}
}

private enum StubAuthError: LocalizedError {
    case signInFailed

    var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "Sign in failed."
        }
    }
}
