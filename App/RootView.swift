import SwiftUI

struct RootView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.phase {
            case .loading:
                ProgressView("Loading...")
                    .task {
                        await coordinator.bootstrapIfNeeded()
                    }
            case .auth:
                AuthView(coordinator: coordinator)
            case .pairing:
                PairingView(coordinator: coordinator)
            case .ready:
                mainTabView
                    .task {
                        await coordinator.bootstrapIfNeeded()
                    }
            }
        }
        .onOpenURL { url in
            coordinator.handleIncomingURL(url)
        }
        .fullScreenCover(item: $coordinator.fullScreenRoute) { route in
            NavigationStack {
                destination(for: route)
                    .toolbar {
                        if coordinator.canDismissCurrentFullScreenRoute() {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") {
                                    coordinator.dismissFullScreenRoute()
                                }
                            }
                        }
                    }
            }
            .interactiveDismissDisabled(coordinator.canDismissCurrentFullScreenRoute() == false)
        }
        .sensoryFeedback(.selection, trigger: coordinator.selectedTab)
        .alert(
            "CoupleTodo",
            isPresented: Binding(
                get: { coordinator.latestError != nil },
                set: { if $0 == false { coordinator.clearLatestError() } }
            )
        ) {
            Button("OK", role: .cancel) {
                coordinator.clearLatestError()
            }
        } message: {
            Text(coordinator.latestError ?? "")
        }
    }

    private var mainTabView: some View {
        TabView(selection: $coordinator.selectedTab) {
            Tab("Today", systemImage: "checklist", value: AppCoordinator.AppTab.today) {
                NavigationStack(path: $coordinator.path) {
                    TodayView(coordinator: coordinator)
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
            }

            Tab("Plan", systemImage: "calendar.badge.plus", value: AppCoordinator.AppTab.plan) {
                NavigationStack {
                    PlanningTabView(coordinator: coordinator)
                }
            }

            Tab("Us", systemImage: "heart.fill", value: AppCoordinator.AppTab.us) {
                NavigationStack {
                    UsView(coordinator: coordinator)
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppCoordinator.AppTab.settings) {
                NavigationStack {
                    SettingsView(coordinator: coordinator)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .auth:
            AuthView(coordinator: coordinator)
        case .pairing:
            PairingView(coordinator: coordinator)
        case .dashboard:
            TodayView(coordinator: coordinator)
        case let .planning(dateKey):
            PlanningView(coordinator: coordinator, dateKey: dateKey)
        case let .settlement(dateKey):
            SettlementView(coordinator: coordinator, dateKey: dateKey)
        case .settlementHistory:
            SettlementHistoryView(coordinator: coordinator)
        case let .payment(recordId):
            PaymentAcknowledgementView(coordinator: coordinator, recordId: recordId)
        case let .rewards(weekKey):
            RewardsView(coordinator: coordinator, weekKey: weekKey)
        case .settings:
            SettingsView(coordinator: coordinator)
        }
    }
}
