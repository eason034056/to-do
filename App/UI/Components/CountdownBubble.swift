import SwiftUI

struct CountdownBubble: View {
    let minutes: Int
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPulsing = false

    private var isUrgent: Bool { minutes <= 15 }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.callout)
                .foregroundStyle(isUrgent ? CoupleTheme.urgent : .secondary)
                .symbolEffect(.variableColor.iterative, isActive: isUrgent && !reduceMotion)

            Text("\(minutes)m")
                .font(.title3.bold())
                .fontDesign(.rounded)
                .contentTransition(.numericText())
                .foregroundStyle(isUrgent ? CoupleTheme.urgent : .primary)

            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isUrgent ? AnyShapeStyle(CoupleTheme.urgent.opacity(0.08)) : AnyShapeStyle(.regularMaterial))
        .clipShape(Capsule())
        .scaleEffect(isPulsing && isUrgent && !reduceMotion ? 1.03 : 1)
        .task {
            guard isUrgent, !reduceMotion else { return }
            withAnimation(CoupleAnimations.pulse) {
                isPulsing = true
            }
        }
    }
}
