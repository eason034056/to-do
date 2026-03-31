import SwiftUI

struct AuthView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(CoupleTheme.youColor.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CoupleTheme.youColor, CoupleTheme.partnerColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                }

                Text("CoupleTodo")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)

                Text("Plan together, grow together.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await coordinator.signIn(with: .apple) }
                } label: {
                    Label(
                        coordinator.isAuthenticating(with: .apple) ? "Signing In..." : "Continue with Apple",
                        systemImage: "apple.logo"
                    )
                }
                .buttonStyle(PulseButtonStyle(color: .primary))
                .disabled(coordinator.authInFlightProvider != nil)

                Button {
                    Task { await coordinator.signIn(with: .google) }
                } label: {
                    Label(
                        coordinator.isAuthenticating(with: .google) ? "Signing In..." : "Continue with Google",
                        systemImage: "globe"
                    )
                }
                .buttonStyle(SecondaryButtonStyle(.calm))
                .disabled(coordinator.authInFlightProvider != nil)
            }
            .padding(.bottom, 48)
        }
        .padding(CoupleTheme.screenHorizontalPadding)
        .background {
            LinearGradient(
                colors: [
                    CoupleTheme.youColor.opacity(0.06),
                    CoupleTheme.partnerColor.opacity(0.04),
                    Color(.systemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .task {
            withAnimation(CoupleAnimations.cardAppear) {
                appeared = true
            }
        }
    }
}
