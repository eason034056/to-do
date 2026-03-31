import SwiftUI
import CoupleTodoCore

struct QuickAddRow: View {
    let placeholder: String
    let defaultBucket: TaskBucket
    let onAdd: (String) -> Void

    @State private var text = ""
    @State private var iconBounce = false
    @State private var submitCount = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(CoupleTheme.accent)
                .scaleEffect(iconBounce ? 0.85 : 1)

            TextField(placeholder, text: $text)
                .font(.body)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(handleSubmit)

            if text.isEmpty == false {
                Button("Add", action: handleSubmit)
                    .font(.callout.bold())
                    .foregroundStyle(CoupleTheme.accent)
            }
        }
        .padding(.horizontal, CoupleTheme.cardPadding)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isFocused ? CoupleTheme.accent.opacity(0.3) : Color.primary.opacity(0.06),
                    style: isFocused ? StrokeStyle(lineWidth: 1) : StrokeStyle(lineWidth: 1, dash: [6, 4]),
                    antialiased: true
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: submitCount)
    }

    private func handleSubmit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        onAdd(trimmed)
        text = ""
        submitCount += 1
        withAnimation(CoupleAnimations.quickAddBounce) {
            iconBounce = true
        } completion: {
            withAnimation(CoupleAnimations.quickAddBounce) {
                iconBounce = false
            }
        }
    }
}
