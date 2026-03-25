import ActivityKit
import WidgetKit
import SwiftUI
import CoupleTodoCore

struct PlanningReminderAttributes: ActivityAttributes {
    /// Fixed context that doesn't change during the activity's lifetime.
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

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Tomorrow Plan", systemImage: "pencil.and.list.clipboard")
                    .font(.headline)
                Text("Cutoff: \(context.state.cutoffTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 8) {
                    statusBadge(label: "You", submitted: context.state.selfSubmitted)
                    statusBadge(label: "Partner", submitted: context.state.partnerSubmitted)
                }

                if context.state.remainingMinutes > 0 {
                    Text("\(context.state.remainingMinutes) min left")
                        .font(.caption.bold())
                        .foregroundStyle(context.state.remainingMinutes <= 15 ? .red : .orange)
                } else {
                    Text("Cutoff passed")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
    }

    private func statusBadge(label: String, submitted: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(submitted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
        }
    }
}
