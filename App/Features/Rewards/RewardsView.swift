import SwiftUI

struct RewardsView: View {
    @ObservedObject var coordinator: AppCoordinator
    let weekKey: String

    var body: some View {
        List {
            if let rewardWeek = coordinator.dashboardSnapshot?.currentRewardWeek {
                Section("Current Week") {
                    Text("Week key: \(rewardWeek.weekKey)")
                    Text(rewardWeek.rewardText)
                    Text("Status: \(rewardWeek.status.rawValue)")
                    ForEach(rewardWeek.eligibility.keys.sorted(), id: \.self) { memberId in
                        let eligible = rewardWeek.eligibility[memberId] ?? false
                        HStack {
                            Text(memberId == coordinator.currentUserId ? "You" : "Partner")
                            Spacer()
                            Text(eligible ? "Eligible" : "Missed")
                                .foregroundStyle(eligible ? .green : .red)
                        }
                    }
                }
            }

            Section("Next Week Draft") {
                let editable = coordinator.dashboardSnapshot?.currentRewardWeek?.status != .locked
                TextField("Reward text", text: $coordinator.rewardDraftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .disabled(editable == false)
                Button("Save Next Week Reward") {
                    Task {
                        await coordinator.saveRewardDraft()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(editable == false)
            }
        }
        .navigationTitle("Rewards")
    }
}
