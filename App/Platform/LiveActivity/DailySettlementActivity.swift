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

    private let successColor = Color(red: 0.30, green: 0.50, blue: 0.38)
    private let urgentColor = Color(red: 0.65, green: 0.25, blue: 0.22)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Daily Recap", systemImage: "chart.bar.doc.horizontal")
                    .font(.headline.bold())
                    .fontDesign(.rounded)
                Spacer()
                Text(context.attributes.dateKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                outcomeColumn(label: "You", outcome: context.state.selfOutcome, amount: context.state.selfOwesAmount)
                outcomeColumn(label: "Partner", outcome: context.state.partnerOutcome, amount: context.state.partnerOwesAmount)
                Spacer()

                if context.state.needsAck {
                    Text("Tap to acknowledge")
                        .font(.caption.bold())
                        .foregroundStyle(urgentColor)
                }
            }
        }
        .padding()
    }

    private func outcomeColumn(label: String, outcome: String?, amount: Decimal) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if let outcome {
                Text(outcome == "pass" ? "PASS" : "MISS")
                    .font(.callout.bold())
                    .foregroundStyle(outcome == "pass" ? successColor : urgentColor)
            }
            if amount > 0 {
                Text("$\(NSDecimalNumber(decimal: amount).stringValue)")
                    .font(.caption)
                    .foregroundStyle(urgentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 10))
    }
}
