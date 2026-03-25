import SwiftUI

struct PairingView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var inviteCode = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Pairing")
                        .font(.largeTitle.bold())
                    Spacer()
                    Button("Sign Out", role: .destructive) {
                        coordinator.signOut()
                    }
                    .buttonStyle(.bordered)
                }

                if let couple = coordinator.pairingCouple {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(couple.status == .active ? "Couple Linked" : "Waiting for Partner")
                            .font(.headline)
                        Text(couple.status == .active ? "Your couple is active. Reload to continue into the dashboard." : "Share the invite code below with your partner so they can join.")
                            .foregroundStyle(.secondary)

                        if let inviteCode = couple.inviteCode {
                            Text(inviteCode)
                                .font(.title.monospaced().bold())
                        }

                        Text("Members: \(couple.memberIds.count)/2")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create a Couple")
                            .font(.headline)
                        Text("This creates your couple record in Firestore and generates an invite code.")
                            .foregroundStyle(.secondary)

                        Button("Create Invite Code") {
                            Task {
                                await coordinator.createCouple()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(coordinator.isPairingActionInFlight)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Join with Invite Code")
                        .font(.headline)
                    TextField("ABC123", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Button("Join Couple") {
                        Task {
                            await coordinator.joinCouple(inviteCode: inviteCode)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(coordinator.isPairingActionInFlight)
                }

                if coordinator.pairingCouple?.status == .active {
                    Button("Refresh Couple Status") {
                        Task {
                            await coordinator.bootstrap()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
    }
}
