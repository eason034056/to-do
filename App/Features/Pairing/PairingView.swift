import SwiftUI
import CoupleTodoCore

struct PairingView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var inviteCode = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Link Up")
                        .font(.largeTitle.bold())
                        .fontDesign(.rounded)
                    Text("Connect with your partner to start your shared board.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let couple = coordinator.pairingCouple {
                    coupleStatusCard(couple)
                } else {
                    createCoupleCard
                }

                joinCoupleCard

                if coordinator.pairingCouple?.status == .active {
                    Button("Continue") {
                        Task { await coordinator.bootstrap() }
                    }
                    .buttonStyle(PulseButtonStyle(.success))
                }

                Spacer()

                Button("Sign Out", role: .destructive) {
                    coordinator.signOut()
                }
                .frame(maxWidth: .infinity)
                .font(.callout)
            }
            .padding(CoupleTheme.screenHorizontalPadding)
        }
        .background {
            LinearGradient(
                colors: [
                    CoupleTheme.youColor.opacity(0.04),
                    CoupleTheme.partnerColor.opacity(0.03),
                    Color(.systemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func coupleStatusCard(_ couple: Couple) -> some View {
        let isActive = couple.status == .active

        return CoupleCard(emphasis: isActive ? .success : .active) {
            StatusPill(
                text: isActive ? "Linked" : "Waiting",
                emphasis: isActive ? .success : .active
            )

            Text(isActive ? "You're connected!" : "Waiting for partner to join")
                .font(.headline)
                .fontDesign(.rounded)

            if let code = couple.inviteCode {
                Text(code)
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundStyle(CoupleTheme.accent(for: .success))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }

            Text("Members: \(couple.memberIds.count)/2")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var createCoupleCard: some View {
        CoupleCard(emphasis: .active) {
            Label("Create a new couple", systemImage: "person.2.fill")
                .font(.headline)
                .fontDesign(.rounded)

            Text("Generate an invite code to share with your partner.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Create Invite Code") {
                Task { await coordinator.createCouple() }
            }
            .buttonStyle(PulseButtonStyle(.active))
            .disabled(coordinator.isPairingActionInFlight)
        }
    }

    private var joinCoupleCard: some View {
        CoupleCard(emphasis: .calm) {
            Label("Join with invite code", systemImage: "link")
                .font(.headline)
                .fontDesign(.rounded)

            TextField("Enter code", text: $inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(12)
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 12))

            Button("Join Couple") {
                Task { await coordinator.joinCouple(inviteCode: inviteCode) }
            }
            .buttonStyle(SecondaryButtonStyle(.calm))
            .disabled(coordinator.isPairingActionInFlight)
        }
    }
}
