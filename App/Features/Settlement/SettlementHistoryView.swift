import SwiftUI

struct SettlementHistoryView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        let entries = coordinator.settlementHistoryEntries()

        Group {
            if entries.isEmpty {
                ContentUnavailableView("No history yet", systemImage: "clock.arrow.circlepath")
            } else {
                historyList(entries)
            }
        }
        .navigationTitle("History")
        .task {
            await coordinator.refreshPayments()
        }
    }

    private func historyList(_ entries: [AppCoordinator.SettlementHistoryEntry]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CoupleTheme.sectionSpacing) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
                        Text(entry.dateKey)
                            .font(.sectionTitle)
                            .fontDesign(.rounded)

                        CoupleCard(emphasis: .calm) {
                            LabeledContent("Owed") {
                                Text(currency(entry.grossOwesAmount))
                            }
                            LabeledContent("Receivable") {
                                Text(currency(entry.grossReceivableAmount))
                            }
                            LabeledContent("Net") {
                                Text(currency(entry.netAmount))
                                    .bold()
                                    .foregroundStyle(entry.netAmount > 0 ? CoupleTheme.urgent : CoupleTheme.success)
                            }
                        }

                        ForEach(entry.records) { record in
                            NavigationLink(value: AppRoute.payment(recordId: record.id)) {
                                CoupleCard(emphasis: record.status == .acknowledged ? .success : .urgent) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(currency(record.amount)) \(record.currency)")
                                                .font(.headline)
                                            Text(record.debtorUserId == coordinator.currentUserId ? "You owe" : "Partner owes")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        StatusPill(
                                            text: record.status.rawValue.capitalized,
                                            emphasis: record.status == .acknowledged ? .success : .urgent
                                        )
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, CoupleTheme.screenHorizontalPadding)
            .padding(.vertical, 16)
        }
    }

    private func currency(_ amount: Decimal) -> String {
        NSDecimalNumber(decimal: amount).stringValue
    }
}
