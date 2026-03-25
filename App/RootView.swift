import SwiftUI

struct RootView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.phase {
            case .loading:
                ProgressView("Loading Couple Todo")
                    .task {
                        await coordinator.bootstrapIfNeeded()
                    }
            case .auth:
                AuthView(coordinator: coordinator)
            case .pairing:
                PairingView(coordinator: coordinator)
            case .ready:
                NavigationStack(path: $coordinator.path) {
                    DashboardView(coordinator: coordinator)
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
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
        .alert(
            "CoupleTodo",
            isPresented: Binding(
                get: { coordinator.latestError != nil },
                set: { newValue in
                    if newValue == false {
                        coordinator.clearLatestError()
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    coordinator.clearLatestError()
                }
            },
            message: {
                Text(coordinator.latestError ?? "")
            }
        )
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .auth:
            AuthView(coordinator: coordinator)
        case .pairing:
            PairingView(coordinator: coordinator)
        case .dashboard:
            DashboardView(coordinator: coordinator)
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
