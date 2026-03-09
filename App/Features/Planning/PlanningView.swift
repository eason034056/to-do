import SwiftUI
import CoupleTodoCore

struct PlanningView: View {
    @ObservedObject var coordinator: AppCoordinator
    let dateKey: String
    @State private var taskEditorState: TaskEditorSheetState?

    var body: some View {
        List {
            Section {
                Text("Planning for \(dateKey)")
                Text("Submit only during your reminder window. The use case enforces the cutoff.")
                    .foregroundStyle(.secondary)
                if let snapshot = coordinator.dashboardSnapshot {
                    Text("Partner submitted: \(snapshot.partnerSubmittedNextPlan ? "Yes" : "No")")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Required") {
                Button("Add Required Task") {
                    if let timezone = coordinator.dashboardSnapshot?.user.currentTimezone {
                        taskEditorState = .create(dateKey: dateKey, localTimezone: timezone, bucket: .required)
                    }
                }

                ForEach(coordinator.planningDraftTasks.filter { $0.bucket == .required && $0.deleted == false }) { task in
                    planningTaskRow(task)
                }
            }

            Section("Optional") {
                Button("Add Optional Task") {
                    if let timezone = coordinator.dashboardSnapshot?.user.currentTimezone {
                        taskEditorState = .create(dateKey: dateKey, localTimezone: timezone, bucket: .optional)
                    }
                }

                ForEach(coordinator.planningDraftTasks.filter { $0.bucket == .optional && $0.deleted == false }) { task in
                    planningTaskRow(task)
                }
            }

            Section {
                Toggle("I have no required tasks tomorrow", isOn: $coordinator.noRequiredTasksConfirmed)
                Button("Submit Tomorrow Plan") {
                    Task {
                        await coordinator.submitPlanningDraft()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Tomorrow Planning")
        .task {
            await coordinator.refreshPlanningDraft()
        }
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
    }

    private func planningTaskRow(_ task: TodoTask) -> some View {
        HStack(spacing: 12) {
            Button {
                taskEditorState = .edit(task)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(task.priority.rawValue.uppercased())
                            .font(.caption.monospaced())
                        Text(task.bucket.rawValue.capitalized)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                Button {
                    Task {
                        await coordinator.moveTask(task, direction: .up)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(coordinator.canMoveTask(task, direction: .up) == false)

                Button {
                    Task {
                        await coordinator.moveTask(task, direction: .down)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(coordinator.canMoveTask(task, direction: .down) == false)
            }
            .buttonStyle(.borderless)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    await coordinator.deleteTask(task)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
