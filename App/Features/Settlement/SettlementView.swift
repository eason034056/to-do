import SwiftUI
import CoupleTodoCore

struct SettlementView: View {
    @ObservedObject var coordinator: AppCoordinator
    let dateKey: String

    var body: some View {
        Group {
            if let settlement = coordinator.dashboardSnapshot?.latestSettlement {
                List {
                    Section {
                        Text("Settlement for \(dateKey)")
                            .font(.title2.bold())
                        Text(settlement.subjectResult.outcome == .pass ? "You passed today." : "You failed today.")
                            .foregroundStyle(settlement.subjectResult.outcome == .pass ? .green : .red)
                    }

                    Section("Required Tasks") {
                        Text("Required total: \(settlement.subjectResult.requiredTotal)")
                        Text("Required completed: \(settlement.subjectResult.requiredCompleted)")
                        Text("Missed required: \(settlement.subjectResult.missedRequiredCount)")
                    }

                    Section("Penalty") {
                        Text("Amount owed: \(NSDecimalNumber(decimal: settlement.subjectResult.owesAmount).stringValue)")
                        if let impact = settlement.rewardImpact {
                            Text("Reward week \(impact.weekKey) eligible: \(impact.stillEligible ? "Yes" : "No")")
                        }
                    }

                    Section {
                        Button("Acknowledge") {
                            Task {
                                await coordinator.acknowledgeLatestSettlement()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .navigationTitle("Settlement")
            } else {
                ContentUnavailableView("No settlement", systemImage: "checkmark.seal")
            }
        }
    }
}
