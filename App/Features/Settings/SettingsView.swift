import SwiftUI
import CoupleTodoCore

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            if let settingsDraft = coordinator.settingsDraft {
                Form {
                    Section("Planning Window") {
                        TextField(
                            "Planning reminder time",
                            text: Binding(
                                get: { coordinator.settingsDraft?.planningReminderTime ?? settingsDraft.planningReminderTime },
                                set: { coordinator.settingsDraft?.planningReminderTime = $0 }
                            )
                        )
                        TextField(
                            "Planning cutoff time",
                            text: Binding(
                                get: { coordinator.settingsDraft?.planningCutoffTime ?? settingsDraft.planningCutoffTime },
                                set: { coordinator.settingsDraft?.planningCutoffTime = $0 }
                            )
                        )
                    }

                    Section("Settlement") {
                        TextField(
                            "Daily settlement time",
                            text: Binding(
                                get: { coordinator.settingsDraft?.dailySettlementTime ?? settingsDraft.dailySettlementTime },
                                set: { coordinator.settingsDraft?.dailySettlementTime = $0 }
                            )
                        )
                        Stepper(
                            "Grace minutes: \(coordinator.settingsDraft?.dailySettlementGraceMinutes ?? settingsDraft.dailySettlementGraceMinutes)",
                            value: Binding(
                                get: { coordinator.settingsDraft?.dailySettlementGraceMinutes ?? settingsDraft.dailySettlementGraceMinutes },
                                set: { coordinator.settingsDraft?.dailySettlementGraceMinutes = $0 }
                            ),
                            in: 0...15
                        )
                    }

                    Section("Penalty") {
                        TextField(
                            "Penalty amount",
                            text: Binding(
                                get: { coordinator.settingsDraft?.penaltyAmount ?? settingsDraft.penaltyAmount },
                                set: { coordinator.settingsDraft?.penaltyAmount = $0 }
                            )
                        )
                        TextField(
                            "Currency",
                            text: Binding(
                                get: { coordinator.settingsDraft?.currency ?? settingsDraft.currency },
                                set: { coordinator.settingsDraft?.currency = $0 }
                            )
                        )
                        Toggle(
                            "Planning miss penalty enabled",
                            isOn: Binding(
                                get: { coordinator.settingsDraft?.planningMissPenaltyEnabled ?? settingsDraft.planningMissPenaltyEnabled },
                                set: { coordinator.settingsDraft?.planningMissPenaltyEnabled = $0 }
                            )
                        )
                    }

                    Section("Week Start") {
                        Picker(
                            "Week starts on",
                            selection: Binding(
                                get: { coordinator.settingsDraft?.weekStartsOn ?? settingsDraft.weekStartsOn },
                                set: { coordinator.settingsDraft?.weekStartsOn = $0 }
                            )
                        ) {
                            ForEach(WeekStart.allCases, id: \.self) { value in
                                Text(value.rawValue.capitalized).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        Button("Save Settings") {
                            Task {
                                await coordinator.saveSettings()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .navigationTitle("Settings")
            } else {
                ProgressView("Loading Settings")
            }
        }
    }
}
