import SwiftUI
import CoupleTodoCore

struct RewardsView: View {
    @ObservedObject var coordinator: AppCoordinator
    let weekKey: String
    @State private var isSavingReward = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
                if let rewardWeek = coordinator.dashboardSnapshot?.currentRewardWeek {
                    currentWeekSection(rewardWeek)
                }
                nextWeekDraftSection
            }
            .padding(.horizontal, CoupleTheme.screenHorizontalPadding)
            .padding(.vertical, 16)
        }
        .navigationTitle("Rewards")
    }

    private func currentWeekSection(_ rewardWeek: RewardWeek) -> some View {
        let emphasis: CoupleTheme.Emphasis = rewardWeek.status == .earned ? .success : .active

        return VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            Text("Current Week")
                .font(.sectionTitle)
                .fontDesign(.rounded)

            CoupleCard(emphasis: emphasis) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        StatusPill(text: rewardWeek.status.rawValue.capitalized, emphasis: emphasis)

                        Text(rewardWeek.rewardText)
                            .font(.title3.bold())
                            .fontDesign(.rounded)

                        Text("Week \(rewardWeek.weekKey)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                ForEach(rewardWeek.eligibility.keys.sorted(), id: \.self) { memberId in
                    let eligible = rewardWeek.eligibility[memberId] ?? false
                    HStack {
                        Text(memberId == coordinator.currentUserId ? "You" : "Partner")
                            .font(.body)
                        Spacer()
                        StatusPill(
                            text: eligible ? "On track" : "Missed",
                            emphasis: eligible ? .success : .urgent
                        )
                    }
                }
                .accessibilityIdentifier("eligibilityMatrix")
            }
        }
    }

    private var nextWeekDraftSection: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            Text("Next Week's Reward")
                .font(.sectionTitle)
                .fontDesign(.rounded)

            CoupleCard(emphasis: .active) {
                TextField("What should the reward be?", text: $coordinator.rewardDraftText, axis: .vertical)
                    .lineLimit(2...4)

                Button("Save Reward") {
                    Task {
                        isSavingReward = true
                        await coordinator.saveRewardDraft()
                        isSavingReward = false
                    }
                }
                .buttonStyle(PulseButtonStyle(.active))
                .disabled(coordinator.rewardDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingReward)
                .sensoryFeedback(.success, trigger: isSavingReward)
            }
        }
    }
}
