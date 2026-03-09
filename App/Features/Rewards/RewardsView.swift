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
                }
            }

            Section("Next Week Draft") {
                TextField("Reward text", text: $coordinator.rewardDraftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Save Next Week Reward") {
                    Task {
                        await coordinator.saveRewardDraft()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Rewards")
    }
}
