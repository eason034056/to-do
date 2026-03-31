import SwiftUI
import CoupleTodoCore

struct UsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var showSettlementDetail = false

    var body: some View {
        Group {
            if let snapshot = coordinator.dashboardSnapshot {
                usContent(snapshot)
            } else {
                ContentUnavailableView(
                    "Loading",
                    systemImage: "heart.fill",
                    description: Text("Waiting for data to load...")
                )
            }
        }
        .navigationTitle("Us")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.settlementHistory) {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }
        }
    }

    private func usContent(_ snapshot: DashboardSnapshot) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
                settlementSection(snapshot)
                rewardSection(snapshot)
                paymentsSection(snapshot)
            }
            .padding(.horizontal, CoupleTheme.screenHorizontalPadding)
            .padding(.bottom, CoupleTheme.screenBottomPadding)
        }
        .refreshable {
            await coordinator.refreshDashboard()
            await coordinator.refreshPayments()
        }
    }

    // MARK: - Settlement

    private func settlementSection(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            Text("Daily Recap")
                .font(.sectionTitle)
                .fontDesign(.rounded)

            if let settlement = snapshot.latestSettlement {
                let needsAck = settlement.pendingAcknowledgementUserIds.contains(snapshot.user.id)
                let emphasis: CoupleTheme.Emphasis = needsAck ? .urgent : (settlement.subjectResult.outcome == .pass ? .success : .calm)

                CoupleCard(emphasis: emphasis) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            StatusPill(
                                text: settlement.subjectResult.outcome == .pass ? "PASS" : "MISS",
                                emphasis: settlement.subjectResult.outcome == .pass ? .success : .urgent
                            )

                            Text("You: \(settlement.subjectResult.requiredCompleted)/\(settlement.subjectResult.requiredTotal)")
                                .font(.headline)
                                .fontDesign(.rounded)

                            if settlement.subjectResult.owesAmount > 0 {
                                Text("Owes: \(snapshot.couple.penaltyPolicy.currency) \(NSDecimalNumber(decimal: settlement.subjectResult.owesAmount).stringValue)")
                                    .font(.callout)
                                    .foregroundStyle(CoupleTheme.urgent)
                            } else {
                                Text("No penalty today!")
                                    .font(.callout)
                                    .foregroundStyle(CoupleTheme.success)
                            }
                        }
                        Spacer()
                        StatusPill(text: settlement.dateKey, emphasis: .calm)
                    }

                    if needsAck {
                        Button("Acknowledge") {
                            Task { await coordinator.acknowledgeLatestSettlement() }
                        }
                        .buttonStyle(PulseButtonStyle(.urgent))
                        .sensoryFeedback(.success, trigger: needsAck)
                    }

                    Button("See Details") {
                        coordinator.navigate(
                            to: .settlement(dateKey: settlement.dateKey)
                        )
                    }
                    .buttonStyle(SecondaryButtonStyle(.calm))
                }
            } else {
                CoupleCard(emphasis: .calm) {
                    Label("No recap yet today", systemImage: "moon.zzz.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Reward

    private func rewardSection(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            Text("Weekly Reward")
                .font(.sectionTitle)
                .fontDesign(.rounded)

            if let rewardWeek = snapshot.currentRewardWeek {
                let emphasis: CoupleTheme.Emphasis = rewardWeek.status == .earned ? .success : .active

                CoupleCard(emphasis: emphasis) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            StatusPill(text: rewardWeek.status.rawValue.capitalized, emphasis: emphasis)

                            Text(rewardWeek.rewardText)
                                .font(.headline)
                                .fontDesign(.rounded)
                        }
                        Spacer()
                        StatusPill(text: rewardWeek.weekKey, emphasis: .calm)
                    }

                    weeklyProgressDots(rewardWeek, snapshot: snapshot)

                    NavigationLink(value: AppRoute.rewards(weekKey: snapshot.selfContext.weekKey)) {
                        Text("View Reward Details")
                            .font(.callout.bold())
                            .foregroundStyle(CoupleTheme.accent(for: emphasis))
                    }
                }
            } else {
                CoupleCard(emphasis: .calm) {
                    Label("No active reward this week", systemImage: "gift")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    NavigationLink(value: AppRoute.rewards(weekKey: snapshot.selfContext.weekKey)) {
                        Text("Set Up a Reward")
                            .font(.callout.bold())
                            .foregroundStyle(CoupleTheme.accent)
                    }
                }
            }
        }
    }

    private func weeklyProgressDots(_ rewardWeek: RewardWeek, snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rewardWeek.eligibility.keys.sorted(), id: \.self) { memberId in
                let isMe = memberId == coordinator.currentUserId
                let eligible = rewardWeek.eligibility[memberId] ?? false
                HStack(spacing: 8) {
                    Text(isMe ? "You" : "Partner")
                        .font(.callout)
                        .frame(width: 60, alignment: .leading)

                    Image(systemName: eligible ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(eligible ? CoupleTheme.success : CoupleTheme.urgent)
                        .font(.title3)

                    Text(eligible ? "On track" : "Missed")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Payments

    private func paymentsSection(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            Text("Pending Payments")
                .font(.sectionTitle)
                .fontDesign(.rounded)

            if snapshot.pendingPayments.isEmpty {
                CoupleCard(emphasis: .calm) {
                    Label("No pending payments", systemImage: "checkmark.seal.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(snapshot.pendingPayments) { payment in
                    NavigationLink(value: AppRoute.payment(recordId: payment.id)) {
                        CoupleCard(emphasis: .urgent) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(payment.currency) \(NSDecimalNumber(decimal: payment.amount).stringValue)")
                                        .font(.headline.bold())
                                        .fontDesign(.rounded)

                                    Text(payment.sourceDateKey)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusPill(
                                    text: payment.status.rawValue.capitalized,
                                    emphasis: payment.markedPaidAt == nil ? .urgent : .active
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
