import SwiftUI

struct DeadlineBanner: View {
    let deadlineHour: Int
    let isSubmitted: Bool
    @State private var now = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.body.bold())
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, options: .repeating, isActive: isUrgent)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.subheadline.bold())
                    .fontDesign(.rounded)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isSubmitted && !isExpired {
                Text(timeRemaining)
                    .font(.title3.bold())
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(isUrgent ? CoupleTheme.urgent : .primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundStyle)
        .clipShape(.rect(cornerRadius: 14))
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    private var deadlineToday: Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: deadlineHour, minute: 0, second: 0, of: now
        ) ?? now
    }

    private var minutesLeft: Int {
        max(0, Int(deadlineToday.timeIntervalSince(now) / 60))
    }

    private var isExpired: Bool { now >= deadlineToday }
    private var isUrgent: Bool { minutesLeft <= 30 && !isExpired }

    private var iconName: String {
        if isSubmitted { return "checkmark.circle.fill" }
        if isExpired { return "exclamationmark.triangle.fill" }
        return "clock.fill"
    }

    private var statusColor: Color {
        if isSubmitted { return CoupleTheme.success }
        if isExpired { return CoupleTheme.urgent }
        if isUrgent { return CoupleTheme.warning }
        return .secondary
    }

    private var headline: String {
        if isSubmitted { return "Plan submitted" }
        if isExpired { return "Deadline passed" }
        return "Plan due by \(deadlineHour):00 AM"
    }

    private var subtitle: String {
        if isSubmitted { return "You're all set for today" }
        if isExpired { return "Penalty will be applied" }
        if isUrgent { return "Submit your plan soon" }
        return "Submit today's plan before the deadline"
    }

    private var timeRemaining: String {
        let hours = minutesLeft / 60
        let mins = minutesLeft % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    @ViewBuilder
    private var backgroundStyle: some View {
        if isExpired && !isSubmitted {
            LinearGradient(
                colors: [CoupleTheme.urgent.opacity(0.1), CoupleTheme.urgent.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if isUrgent {
            LinearGradient(
                colors: [CoupleTheme.warning.opacity(0.08), CoupleTheme.warning.opacity(0.02)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }
}
