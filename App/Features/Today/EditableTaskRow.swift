import SwiftUI
import CoupleTodoCore

struct EditableTaskRow: View {
    let task: TodoTask
    let coordinator: AppCoordinator
    let onEdit: () -> Void
    let onCelebrationCheck: () -> Void

    @State private var deleteTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TaskRow(
            task: task,
            isEditable: true,
            onToggle: handleToggle,
            onTap: onEdit
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: handleDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                )
        )
        .sensoryFeedback(.impact(flexibility: .soft), trigger: task.status)
        .sensoryFeedback(.warning, trigger: deleteTrigger)
    }

    private func handleToggle() {
        withAnimation(CoupleAnimations.checkboxBounce) {
            coordinator.toggleTaskOptimistically(task)
        }
        onCelebrationCheck()
        Task {
            let success = await coordinator.toggleTaskInBackground(task)
            if !success {
                withAnimation(CoupleAnimations.checkboxBounce) {
                    coordinator.toggleTaskOptimistically(task)
                }
            }
        }
    }

    private func handleDelete() {
        let savedTask = task
        deleteTrigger += 1
        withAnimation(CoupleAnimations.taskRemoveAnimation(reduceMotion)) {
            coordinator.removeTaskOptimistically(task.id)
        }
        Task {
            let success = await coordinator.deleteTaskInBackground(savedTask)
            if !success {
                withAnimation(CoupleAnimations.taskInsertAnimation(reduceMotion)) {
                    coordinator.insertTaskOptimistically(savedTask)
                }
            }
        }
    }
}
