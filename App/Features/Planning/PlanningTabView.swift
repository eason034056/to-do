import SwiftUI
import CoupleTodoCore

struct PlanningTabView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            if let snapshot = coordinator.dashboardSnapshot {
                PlanningView(
                    coordinator: coordinator,
                    dateKey: snapshot.planningTargetDateKey
                )
            } else {
                ContentUnavailableView(
                    "Loading",
                    systemImage: "calendar.badge.clock",
                    description: Text("Waiting for data to load...")
                )
            }
        }
    }
}
