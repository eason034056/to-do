import SwiftUI
import CoupleTodoCore

struct PaymentAcknowledgementView: View {
    @ObservedObject var coordinator: AppCoordinator
    let recordId: String

    var body: some View {
        Group {
            if let payment = coordinator.paymentRecord(for: recordId) {
                List {
                    Section("Payment") {
                        Text("Record: \(payment.id)")
                        Text("Source date: \(payment.sourceDateKey)")
                        Text("Amount: \(NSDecimalNumber(decimal: payment.amount).stringValue) \(payment.currency)")
                        Text("Status: \(payment.status.rawValue)")
                    }

                    Section("Timeline") {
                        Text("Marked paid: \(formatted(payment.markedPaidAt))")
                        Text("Acknowledged: \(formatted(payment.acknowledgedAt))")
                        Text("Disputed: \(formatted(payment.disputedAt))")
                    }

                    Section("Actions") {
                        if payment.debtorUserId == coordinator.currentUserId {
                            Button("Mark Paid") {
                                Task {
                                    await coordinator.markPaymentPaid(recordId: payment.id)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(payment.markedPaidAt != nil)
                        }

                        if payment.creditorUserId == coordinator.currentUserId {
                            Button("Acknowledge") {
                                Task {
                                    await coordinator.resolvePayment(recordId: payment.id, status: .acknowledged)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(payment.markedPaidAt == nil || payment.status == .acknowledged)

                            Button("Dispute", role: .destructive) {
                                Task {
                                    await coordinator.resolvePayment(recordId: payment.id, status: .disputed)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(payment.markedPaidAt == nil || payment.status == .disputed)
                        }
                    }
                }
                .navigationTitle("Payment")
            } else {
                ContentUnavailableView("Payment not found", systemImage: "creditcard.trianglebadge.exclamationmark")
            }
        }
        .task {
            await coordinator.refreshPayments()
        }
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
