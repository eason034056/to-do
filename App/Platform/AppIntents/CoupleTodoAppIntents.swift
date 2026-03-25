import AppIntents

struct OpenPlanningIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Planning"
    static let description: IntentDescription = "Open the tomorrow planning screen in CoupleTodo."
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await CoupleTodoIntentRouter.shared.requestRoute(.planning)
        return .result()
    }
}

struct OpenDashboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Dashboard"
    static let description: IntentDescription = "Open the dashboard in CoupleTodo."
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await CoupleTodoIntentRouter.shared.requestRoute(.dashboard)
        return .result()
    }
}

struct OpenSettlementIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Settlement"
    static let description: IntentDescription = "Open the settlement screen in CoupleTodo."
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await CoupleTodoIntentRouter.shared.requestRoute(.settlement)
        return .result()
    }
}

struct OpenRewardsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Rewards"
    static let description: IntentDescription = "Open the rewards screen in CoupleTodo."
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await CoupleTodoIntentRouter.shared.requestRoute(.rewards)
        return .result()
    }
}

/// Vended as a `ShortcutsProvider` so Siri/Shortcuts can discover these intents.
struct CoupleTodoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPlanningIntent(),
            phrases: [
                "Open planning in \(.applicationName)",
                "Plan tomorrow in \(.applicationName)"
            ],
            shortTitle: "Open Planning",
            systemImageName: "pencil.and.list.clipboard"
        )
        AppShortcut(
            intent: OpenDashboardIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show today in \(.applicationName)"
            ],
            shortTitle: "Open Dashboard",
            systemImageName: "list.bullet"
        )
    }
}

// MARK: - Intent Router

/// A lightweight singleton that bridges App Intents (which run outside MainActor)
/// to the `AppCoordinator`'s navigation. The coordinator observes `pendingRoute`.
@MainActor
final class CoupleTodoIntentRouter: ObservableObject {
    enum IntentRoute {
        case dashboard
        case planning
        case settlement
        case rewards
    }

    static let shared = CoupleTodoIntentRouter()

    @Published var pendingRoute: IntentRoute?

    private init() {}

    func requestRoute(_ route: IntentRoute) {
        pendingRoute = route
    }

    func consumeRoute() -> IntentRoute? {
        guard let route = pendingRoute else { return nil }
        pendingRoute = nil
        return route
    }
}
