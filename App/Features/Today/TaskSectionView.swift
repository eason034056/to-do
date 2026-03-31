import SwiftUI
import CoupleTodoCore

struct TaskSectionView: View {
    enum Kind {
        case required
        case optional
    }

    let kind: Kind
    let tasks: [TodoTask]
    let coordinator: AppCoordinator
    var onOpenEditor: ((TaskBucket) -> Void)?
    let onCelebrationCheck: () -> Void
    let onEditTask: (TodoTask) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: CoupleTheme.itemSpacing) {
            TaskSectionHeaderView(
                title: kind == .required ? "Required" : "Optional",
                count: tasks.count,
                onAdd: onOpenEditor.map { editor in
                    { editor(kind == .required ? .required : .optional) }
                }
            )

            if tasks.isEmpty && kind == .required {
                ContentUnavailableView {
                    Label("No required tasks", systemImage: "sparkles")
                } description: {
                    Text("Enjoy the free time!")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else {
                ForEach(tasks) { task in
                    EditableTaskRow(
                        task: task,
                        coordinator: coordinator,
                        onEdit: { onEditTask(task) },
                        onCelebrationCheck: onCelebrationCheck
                    )
                }
            }

            if onOpenEditor != nil {
                QuickAddRow(
                    placeholder: kind == .required ? "Add a required task..." : "Add an optional task...",
                    defaultBucket: kind == .required ? .required : .optional
                ) { title in
                    handleQuickAdd(title: title)
                }
            }
        }
    }

    private func handleQuickAdd(title: String) {
        guard let optimisticTask = coordinator.buildOptimisticTask(
            title: title,
            bucket: kind == .required ? .required : .optional
        ) else { return }

        withAnimation(CoupleAnimations.taskInsertAnimation(reduceMotion)) {
            coordinator.insertTaskOptimistically(optimisticTask)
        }

        Task {
            let success = await coordinator.saveTaskDraft(
                TaskEditorDraft(
                    title: title,
                    bucket: kind == .required ? .required : .optional,
                    priority: .p2
                ),
                existingTask: nil,
                dateKey: optimisticTask.dateKey,
                localTimezone: optimisticTask.localTimezone
            )
            if !success {
                withAnimation(CoupleAnimations.taskRemoveAnimation(reduceMotion)) {
                    coordinator.removeTaskOptimistically(optimisticTask.id)
                }
            }
        }
    }
}
