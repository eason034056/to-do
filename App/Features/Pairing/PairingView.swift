import SwiftUI

struct PairingView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pairing")
                .font(.largeTitle.bold())
            Text("The core couple lifecycle use cases are in place. The app shell is currently seeded with a demo paired couple through `DemoAppEnvironment`.")
                .foregroundStyle(.secondary)

            Button("Enter Demo Dashboard") {
                Task {
                    await coordinator.bootstrap()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
