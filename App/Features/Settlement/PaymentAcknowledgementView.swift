import SwiftUI
import CoupleTodoCore

struct PaymentAcknowledgementView: View {
    @ObservedObject var coordinator: AppCoordinator
    let recordId: String

    var body: some View {
        Group {
            if let payment = coordinator.paymentRecord(for: recordId) {
                paymentContent(payment)
            } else {
                ContentUnavailableView("Payment not found", systemImage: "creditcard.trianglebadge.exclamationmark")
            }
        }
        .navigationTitle("Payment")
        .task {
            await coordinator.refreshPayments()
        }
    }

    private func paymentContent(_ payment: PaymentRecord) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
                summarySection(payment)
                timelineSection(payment)
                actionsSection(payment)
            }
            .padding(.horizontal, CoupleTheme.screenHorizontalPadding)
            .padding(.vertical, 16)
        }
    }

    private func summarySection(_ payment: PaymentRecord) -> some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            StatusPill(text: payment.status.rawValue.capitalized, emphasis: .urgent)

            Text("\(NSDecimalNumber(decimal: payment.amount).stringValue) \(payment.currency)")
                .font(.largeTitle.bold())
                .fontDesign(.rounded)

            Text("From \(payment.sourceDateKey)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(CoupleTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [CoupleTheme.urgent.opacity(0.1), CoupleTheme.urgent.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: CoupleTheme.heroCornerRadius))
        .shadow(
            color: CoupleTheme.cardShadowColor,
            radius: CoupleTheme.cardShadowRadius,
            y: CoupleTheme.cardShadowY
        )
    }

    private func timelineSection(_ payment: PaymentRecord) -> some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            Text("Timeline")
                .font(.sectionTitle)
                .fontDesign(.rounded)

            CoupleCard(emphasis: .calm) {
                VStack(alignment: .leading, spacing: 0) {
                    timelineDotRow(
                        title: "Marked paid",
                        value: formatted(payment.markedPaidAt),
                        isCompleted: payment.markedPaidAt != nil,
                        isLast: false
                    )
                    timelineDotRow(
                        title: "Acknowledged",
                        value: formatted(payment.acknowledgedAt),
                        isCompleted: payment.acknowledgedAt != nil,
                        isLast: false
                    )
                    timelineDotRow(
                        title: "Disputed",
                        value: formatted(payment.disputedAt),
                        isCompleted: payment.disputedAt != nil,
                        isLast: true
                    )
                }
            }
        }
    }

    private func actionsSection(_ payment: PaymentRecord) -> some View {
        VStack(spacing: CoupleTheme.itemSpacing) {
            if payment.debtorUserId == coordinator.currentUserId {
                Button("Mark as Paid") {
                    Task { await coordinator.markPaymentPaid(recordId: payment.id) }
                }
                .buttonStyle(PulseButtonStyle(.active))
                .disabled(payment.markedPaidAt != nil)
                .sensoryFeedback(.success, trigger: payment.markedPaidAt != nil)
            }

            if payment.creditorUserId == coordinator.currentUserId {
                Button("Acknowledge Payment") {
                    Task { await coordinator.resolvePayment(recordId: payment.id, status: .acknowledged) }
                }
                .buttonStyle(PulseButtonStyle(.success))
                .disabled(payment.markedPaidAt == nil || payment.status == .acknowledged)

                Button("Dispute", role: .destructive) {
                    Task { await coordinator.resolvePayment(recordId: payment.id, status: .disputed) }
                }
                .buttonStyle(SecondaryButtonStyle(.urgent))
                .disabled(payment.markedPaidAt == nil || payment.status == .disputed)
            }
        }
    }

    private func timelineDotRow(title: String, value: String, isCompleted: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isCompleted ? CoupleTheme.accent : Color.secondary.opacity(0.2))
                    .frame(width: 10, height: 10)

                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 2, height: 32)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(isCompleted ? .primary : .secondary)

                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, isLast ? 0 : 8)

            Spacer()
        }
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.month().day().hour().minute())
    }
}
