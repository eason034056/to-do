import SwiftUI
import CoupleTodoCore

struct TaskRow: View {
    let task: TodoTask
    let isEditable: Bool
    let onToggle: (() -> Void)?
    let onTap: (() -> Void)?

    @State private var isCompleted: Bool

    init(
        task: TodoTask,
        isEditable: Bool = true,
        onToggle: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.task = task
        self.isEditable = isEditable
        self.onToggle = onToggle
        self.onTap = onTap
        _isCompleted = State(initialValue: task.status == .completed)
    }

    var body: some View {
        HStack(spacing: 12) {
            if isEditable, let onToggle {
                Button(
                    task.status == .completed ? "Mark incomplete" : "Mark complete",
                    action: {
                        withAnimation(CoupleAnimations.checkboxBounce) {
                            isCompleted.toggle()
                        }
                        onToggle()
                    }
                )
                .buttonStyle(CheckboxButtonStyle(isChecked: isCompleted))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? .secondary : .primary)

                if let notes = task.notes, notes.isEmpty == false {
                    Text(notes)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
            .accessibilityAddTraits(onTap != nil ? .isButton : [])

            if task.priority == .p0 || task.priority == .p1 {
                Text(task.priority.displayLabel)
                    .font(.caption)
                    .bold()
                    .fontDesign(.rounded)
                    .foregroundStyle(task.priority == .p0 ? CoupleTheme.urgent : CoupleTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(task.priority.color.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, CoupleTheme.cardPadding)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(CoupleGradients.cardBorderGradient, lineWidth: 0.5)
        }
        .shadow(
            color: CoupleTheme.cardShadowColor,
            radius: 4,
            y: 2
        )
        .onChange(of: task.status) {
            isCompleted = task.status == .completed
        }
    }
}

private struct CheckboxButtonStyle: ButtonStyle {
    let isChecked: Bool

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(
                    isChecked ? CoupleTheme.accent : Color.secondary.opacity(0.25),
                    lineWidth: 2
                )
                .frame(width: 28, height: 28)

            if isChecked {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CoupleTheme.accent, CoupleTheme.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(configuration.isPressed ? 0.85 : 1)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Circle())
        .accessibilityLabel(isChecked ? "Completed" : "Not completed")
    }
}
