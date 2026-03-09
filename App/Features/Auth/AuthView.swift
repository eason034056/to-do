import SwiftUI

struct AuthView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign In")
                .font(.largeTitle.bold())
            Text("Demo environment expects a paired sample account. Re-run bootstrap to load the seeded workspace.")
                .foregroundStyle(.secondary)

            Button("Load Demo Workspace") {
                Task {
                    await coordinator.bootstrap()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
