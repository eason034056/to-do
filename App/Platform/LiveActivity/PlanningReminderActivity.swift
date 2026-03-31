import ActivityKit
import WidgetKit
import SwiftUI
import CoupleTodoCore

struct PlanningReminderAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var selfSubmitted: Bool
        var partnerSubmitted: Bool
        var cutoffTime: String
        var remainingMinutes: Int
    }

    let dateKey: String
}

struct PlanningReminderLiveActivityView: View {
    let context: ActivityViewContext<PlanningReminderAttributes>

    private var isUrgent: Bool { context.state.remainingMinutes <= 15 }
    private var accentColor: Color { isUrgent ? Color(red: 0.65, green: 0.25, blue: 0.22) : Color(red: 0.21, green: 0.345, blue: 0.447) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Plan Tomorrow", systemImage: "calendar.badge.plus")
                    .font(.headline.bold())
                    .fontDesign(.rounded)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                    Text(context.state.remainingMinutes > 0 ? "\(context.state.remainingMinutes)m" : "0m")
                        .font(.title3.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())
                }
            }

            HStack(spacing: 12) {
                statusPill(label: "You", submitted: context.state.selfSubmitted)
                statusPill(label: "Partner", submitted: context.state.partnerSubmitted)
                Spacer()
                Text("Cutoff: \(context.state.cutoffTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func statusPill(label: String, submitted: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: submitted ? "checkmark.circle.fill" : "clock")
                .font(.caption)
                .foregroundStyle(submitted ? Color(red: 0.30, green: 0.50, blue: 0.38) : .secondary)
            Text(label)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial)
        .clipShape(Capsule())
    }
}
