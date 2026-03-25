import SwiftUI

struct AuthView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sign In")
                .font(.largeTitle.bold())
            Text("Use Sign in with Apple or Google to restore your CoupleTodo session and bootstrap your profile in Firestore.")
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await coordinator.signIn(with: .apple)
                }
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                    Text(coordinator.isAuthenticating(with: .apple) ? "Signing In..." : "Continue with Apple")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.authInFlightProvider != nil)

            Button {
                Task {
                    await coordinator.signIn(with: .google)
                }
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text(coordinator.isAuthenticating(with: .google) ? "Signing In..." : "Continue with Google")
                }
            }
            .buttonStyle(.bordered)
            .disabled(coordinator.authInFlightProvider != nil)
        }
        .padding(24)
    }
}
