import SwiftUI

struct SettlementHistoryView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        let entries = coordinator.settlementHistoryEntries()

        Group {
            if entries.isEmpty {
                ContentUnavailableView("No settlement history", systemImage: "clock.arrow.circlepath")
            } else {
                List(entries) { entry in
                    Section(entry.dateKey) {
                        Text("Gross owed: \(currency(entry.grossOwesAmount))")
                        Text("Gross receivable: \(currency(entry.grossReceivableAmount))")
                        Text("Net: \(currency(entry.netAmount))")
                            .font(.body.weight(.semibold))

                        ForEach(entry.records) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(currency(record.amount)) · \(record.status.rawValue)")
                                Text("Debtor: \(record.debtorUserId == coordinator.currentUserId ? "You" : "Partner")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Open Payment") {
                                    coordinator.navigate(to: .payment(recordId: record.id))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Settlement History")
        .task {
            await coordinator.refreshPayments()
        }
    }

    private func currency(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }
}
