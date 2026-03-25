import ActivityKit
import WidgetKit
import SwiftUI
import CoupleTodoCore

struct DailySettlementAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var selfOutcome: String?
        var partnerOutcome: String?
        var selfOwesAmount: Decimal
        var partnerOwesAmount: Decimal
        var needsAck: Bool
    }

    let dateKey: String
}

struct DailySettlementLiveActivityView: View {
    let context: ActivityViewContext<DailySettlementAttributes>

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Settlement", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                Text(context.attributes.dateKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 8) {
                    outcomeBadge(label: "You", outcome: context.state.selfOutcome, amount: context.state.selfOwesAmount)
                    outcomeBadge(label: "Partner", outcome: context.state.partnerOutcome, amount: context.state.partnerOwesAmount)
                }

                if context.state.needsAck {
                    Text("Acknowledgement needed")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
    }

    private func outcomeBadge(label: String, outcome: String?, amount: Decimal) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
            if let outcome {
                Text(outcome == "pass" ? "✓" : "✗")
                    .font(.caption.bold())
                    .foregroundStyle(outcome == "pass" ? .green : .red)
            }
            if amount > 0 {
                Text("$\(NSDecimalNumber(decimal: amount).stringValue)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}
