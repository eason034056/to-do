import SwiftUI
import CoupleTodoCore

struct DashboardView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var taskEditorState: TaskEditorSheetState?

    var body: some View {
        Group {
            if let snapshot = coordinator.dashboardSnapshot {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Couple To-Do")
                                .font(.title.bold())
                            Text("Today for you and your partner stays split by local timezone.")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Button("Tomorrow Plan") {
                                coordinator.navigate(to: .planning(dateKey: snapshot.planningTargetDateKey))
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Rewards") {
                                coordinator.navigate(to: .rewards(weekKey: snapshot.selfContext.weekKey))
                            }
                            .buttonStyle(.bordered)

                            Button("Settings") {
                                coordinator.navigate(to: .settings)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Section("Your Today") {
                        Text("Add and manage tasks for your local day without leaving the dashboard.")
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("New Required") {
                                taskEditorState = .create(
                                    dateKey: snapshot.selfContext.dateKey,
                                    localTimezone: snapshot.user.currentTimezone,
                                    bucket: .required
                                )
                            }
                            .buttonStyle(.borderedProminent)

                            Button("New Optional") {
                                taskEditorState = .create(
                                    dateKey: snapshot.selfContext.dateKey,
                                    localTimezone: snapshot.user.currentTimezone,
                                    bucket: .optional
                                )
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Section("Date Context") {
                        Text("You: \(snapshot.selfContext.dateKey) (\(snapshot.selfContext.timezoneIdentifier))")
                        Text("Partner: \(snapshot.partnerContext.dateKey) (\(snapshot.partnerContext.timezoneIdentifier))")
                    }

                    Section("Planning Status") {
                        Text("Tomorrow date key: \(snapshot.planningTargetDateKey)")
                        Text("You submitted: \(snapshot.selfSubmittedNextPlan ? "Yes" : "No")")
                        Text("Partner submitted: \(snapshot.partnerSubmittedNextPlan ? "Yes" : "No")")
                    }

                    Section("Your Required") {
                        ForEach(snapshot.selfRequired) { task in
                            editableTaskRow(task)
                        }
                    }

                    Section("Your Optional") {
                        ForEach(snapshot.selfOptional) { task in
                            editableTaskRow(task)
                        }
                    }

                    Section("Partner Required") {
                        ForEach(snapshot.partnerRequired) { task in
                            taskRow(task)
                        }
                    }

                    Section("Partner Optional") {
                        ForEach(snapshot.partnerOptional) { task in
                            taskRow(task)
                        }
                    }

                    if let settlement = snapshot.latestSettlement {
                        Section("Latest Settlement") {
                            Text(settlement.subjectResult.outcome == .pass ? "Today passed" : "Today failed")
                            Text("You owe \(NSDecimalNumber(decimal: settlement.subjectResult.owesAmount).stringValue) \(snapshot.couple.penaltyPolicy.currency)")
                            Text("Pending acknowledgement: \(settlement.pendingAcknowledgementUserIds.isEmpty ? "No" : "Yes")")

                            if settlement.pendingAcknowledgementUserIds.contains(snapshot.user.id) {
                                Button("Acknowledge Settlement") {
                                    Task {
                                        await coordinator.acknowledgeLatestSettlement()
                                    }
                                }
                            }
                        }
                    }

                    if let rewardWeek = snapshot.currentRewardWeek {
                        Section("Reward Week") {
                            Text(rewardWeek.rewardText)
                            Text("Status: \(rewardWeek.status.rawValue)")
                            Text("Eligibility: \(rewardWeek.eligibility.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", "))")
                        }
                    }
                }
                .refreshable {
                    await coordinator.refreshDashboard()
                    await coordinator.refreshPlanningDraft()
                }
                .navigationTitle("Dashboard")
                .sheet(item: $taskEditorState) { state in
                    NavigationStack {
                        TaskEditorView(state: state) { draft, task, dateKey, localTimezone in
                            await coordinator.saveTaskDraft(
                                draft,
                                existingTask: task,
                                dateKey: dateKey,
                                localTimezone: localTimezone
                            )
                        }
                    }
                }
            } else {
                ProgressView("Loading Dashboard")
                    .task {
                        await coordinator.bootstrapIfNeeded()
                    }
            }
        }
    }

    private func taskRow(_ task: TodoTask) -> some View {
        HStack {
            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.status == .completed ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                if let notes = task.notes, notes.isEmpty == false {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(task.priority.rawValue.uppercased())
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func editableTaskRow(_ task: TodoTask) -> some View {
        Button {
            taskEditorState = .edit(task)
        } label: {
            taskRow(task)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    await coordinator.deleteTask(task)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task {
                    await coordinator.toggleTaskCompletion(task)
                }
            } label: {
                Label(task.status == .completed ? "Undo" : "Done", systemImage: task.status == .completed ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(task.status == .completed ? .orange : .green)
        }
    }
}
