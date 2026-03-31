import SwiftUI
import CoupleTodoCore

struct SettlementView: View {
    @ObservedObject var coordinator: AppCoordinator
    let dateKey: String

    var body: some View {
        Group {
            if let settlement = coordinator.dashboardSnapshot?.latestSettlement {
                settlementContent(settlement)
            } else {
                ContentUnavailableView("No recap yet", systemImage: "chart.bar.doc.horizontal")
            }
        }
        .navigationTitle("Daily Recap")
    }

    private func settlementContent(_ settlement: DailySettlement) -> some View {
        let snapshot = coordinator.dashboardSnapshot

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
                heroSection(settlement)
                statsSection(settlement)

                if let impact = settlement.rewardImpact {
                    rewardImpactSection(impact)
                }

                let payments = coordinator.paymentRecords.filter { $0.sourceDateKey == settlement.dateKey }
                if payments.isEmpty == false {
                    relatedPaymentsSection(payments)
                }

                actionsSection(settlement)
            }
            .padding(.horizontal, CoupleTheme.screenHorizontalPadding)
            .padding(.vertical, 16)
        }
    }

    private func heroSection(_ settlement: DailySettlement) -> some View {
        let emphasis = SettlementPresenter.heroEmphasis(for: settlement, userId: coordinator.currentUserId ?? "")
        let outcomeColor = settlement.subjectResult.outcome == .pass ? CoupleTheme.success : CoupleTheme.urgent

        return VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            StatusPill(
                text: SettlementPresenter.outcomeLabel(for: settlement.subjectResult.outcome),
                emphasis: settlement.subjectResult.outcome == .pass ? .success : .urgent
            )

            Text(SettlementPresenter.summaryText(for: settlement.subjectResult.outcome))
                .font(.title2.bold())
                .fontDesign(.rounded)

            Text("Settlement for \(dateKey)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(CoupleTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [outcomeColor.opacity(0.12), outcomeColor.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: CoupleTheme.heroCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: CoupleTheme.heroCornerRadius)
                .strokeBorder(CoupleGradients.cardBorderGradient, lineWidth: 0.5)
        }
        .shadow(
            color: CoupleTheme.cardShadowColor,
            radius: CoupleTheme.cardShadowRadius,
            y: CoupleTheme.cardShadowY
        )
    }

    private func statsSection(_ settlement: DailySettlement) -> some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            Text("Breakdown")
                .font(.sectionTitle)
                .fontDesign(.rounded)

            HStack(spacing: CoupleTheme.itemSpacing) {
                statCard(
                    title: "Required",
                    value: "\(settlement.subjectResult.requiredCompleted)/\(settlement.subjectResult.requiredTotal)",
                    detail: "\(settlement.subjectResult.missedRequiredCount) missed",
                    emphasis: settlement.subjectResult.outcome == .pass ? .success : .urgent
                )
                statCard(
                    title: "Penalty",
                    value: NSDecimalNumber(decimal: settlement.subjectResult.owesAmount).stringValue,
                    detail: settlement.subjectResult.owesAmount > 0 ? "Amount owed" : "No penalty",
                    emphasis: settlement.subjectResult.owesAmount > 0 ? .urgent : .success
                )
            }
        }
    }

    private func statCard(title: String, value: String, detail: String, emphasis: CoupleTheme.Emphasis) -> some View {
        CoupleCard(emphasis: emphasis) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .fontDesign(.rounded)
                .foregroundStyle(CoupleTheme.accent(for: emphasis))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func rewardImpactSection(_ impact: RewardImpact) -> some View {
        CoupleCard(emphasis: impact.stillEligible ? .success : .urgent) {
            HStack(spacing: 10) {
                Image(systemName: impact.stillEligible ? "star.fill" : "star.slash.fill")
                    .font(.title3)
                    .foregroundStyle(impact.stillEligible ? CoupleTheme.success : CoupleTheme.urgent)
                    .symbolEffect(.bounce, value: impact.stillEligible)

                VStack(alignment: .leading, spacing: 2) {
                    Text(impact.stillEligible ? "Still on track for this week's reward" : "This breaks reward eligibility")
                        .font(.callout)

                    Text("Week \(impact.weekKey)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func relatedPaymentsSection(_ payments: [PaymentRecord]) -> some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            Text("Related Payments")
                .font(.sectionTitle)
                .fontDesign(.rounded)

            ForEach(payments) { payment in
                NavigationLink(value: AppRoute.payment(recordId: payment.id)) {
                    CoupleCard(emphasis: .urgent) {
                        HStack {
                            Label(
                                "\(NSDecimalNumber(decimal: payment.amount).stringValue) \(payment.currency)",
                                systemImage: "creditcard.fill"
                            )
                            .font(.headline)
                            Spacer()
                            StatusPill(text: payment.status.rawValue.capitalized, emphasis: .urgent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionsSection(_ settlement: DailySettlement) -> some View {
        let needsAck = settlement.pendingAcknowledgementUserIds.contains(coordinator.currentUserId ?? "")

        return VStack(spacing: CoupleTheme.itemSpacing) {
            if needsAck {
                Button("Acknowledge") {
                    Task { await coordinator.acknowledgeLatestSettlement() }
                }
                .buttonStyle(PulseButtonStyle(.urgent))
                .sensoryFeedback(.success, trigger: needsAck)
            }

            NavigationLink(value: AppRoute.settlementHistory) {
                Text("View Settlement History")
                    .font(.callout.bold())
                    .foregroundStyle(CoupleTheme.calm)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
}
