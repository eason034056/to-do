import SwiftUI
import CoupleTodoCore

struct DashboardView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        TodayView(coordinator: coordinator)
    }
}
