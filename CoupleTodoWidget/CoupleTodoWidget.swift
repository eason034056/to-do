import WidgetKit
import SwiftUI
import CoupleTodoCore

// MARK: - Timeline Provider

struct CoupleTodoTimelineProvider: TimelineProvider {
    private let reader = SharedSnapshotReader()

    func placeholder(in context: Context) -> CoupleTodoEntry {
        CoupleTodoEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CoupleTodoEntry) -> Void) {
        completion(entry(from: reader.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoupleTodoEntry>) -> Void) {
        let currentEntry = entry(from: reader.read())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [currentEntry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func entry(from snapshot: SharedSnapshot?) -> CoupleTodoEntry {
        guard let snapshot else { return .placeholder }
        return CoupleTodoEntry(
            date: snapshot.generatedAt,
            selfDateKey: snapshot.today.selfDateKey,
            partnerDateKey: snapshot.today.partnerDateKey,
            selfRequiredRemaining: snapshot.today.`self`.requiredRemaining,
            selfRequiredCompleted: snapshot.today.`self`.requiredCompleted,
            partnerRequiredRemaining: snapshot.today.partner.requiredRemaining,
            partnerRequiredCompleted: snapshot.today.partner.requiredCompleted,
            selfTopTasks: snapshot.today.`self`.topTasks,
            planningTargetDateKey: snapshot.planning.targetDateKey,
            selfSubmitted: snapshot.planning.selfSubmitted,
            partnerSubmitted: snapshot.planning.partnerSubmitted,
            isPendingAck: snapshot.settlement.isPendingAck,
            selfOwesAmount: snapshot.settlement.selfOwesAmount,
            isPlaceholder: false
        )
    }
}

// MARK: - Timeline Entry

struct CoupleTodoEntry: TimelineEntry {
    let date: Date
    let selfDateKey: String
    let partnerDateKey: String
    let selfRequiredRemaining: Int
    let selfRequiredCompleted: Int
    let partnerRequiredRemaining: Int
    let partnerRequiredCompleted: Int
    let selfTopTasks: [String]
    let planningTargetDateKey: String
    let selfSubmitted: Bool
    let partnerSubmitted: Bool
    let isPendingAck: Bool
    let selfOwesAmount: Decimal
    let isPlaceholder: Bool

    static let placeholder = CoupleTodoEntry(
        date: Date(),
        selfDateKey: "--",
        partnerDateKey: "--",
        selfRequiredRemaining: 0,
        selfRequiredCompleted: 0,
        partnerRequiredRemaining: 0,
        partnerRequiredCompleted: 0,
        selfTopTasks: [],
        planningTargetDateKey: "--",
        selfSubmitted: false,
        partnerSubmitted: false,
        isPendingAck: false,
        selfOwesAmount: 0,
        isPlaceholder: true
    )
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: CoupleTodoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("CoupleTodo")
                    .font(.caption.bold())
            }

            if entry.isPlaceholder {
                Text("Open app to sync")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(entry.selfRequiredCompleted)/\(entry.selfRequiredCompleted + entry.selfRequiredRemaining) done")
                    .font(.title3.bold())

                if entry.isPendingAck {
                    Label("Settlement pending", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if entry.selfRequiredRemaining == 0, entry.selfRequiredCompleted > 0 {
                    Label("All clear!", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                } else {
                    Text("\(entry.selfRequiredRemaining) remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.selfSubmitted ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(entry.selfSubmitted ? "Plan ✓" : "Plan needed")
                        .font(.caption2)
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "coupletodo://dashboard"))
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: CoupleTodoEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("You · \(entry.selfDateKey)")
                    .font(.caption.bold())
                Text("\(entry.selfRequiredCompleted)/\(entry.selfRequiredCompleted + entry.selfRequiredRemaining) required")
                    .font(.headline)

                if entry.selfTopTasks.isEmpty == false {
                    ForEach(entry.selfTopTasks.prefix(2), id: \.self) { task in
                        HStack(spacing: 4) {
                            Image(systemName: "circle")
                                .font(.caption2)
                            Text(task)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.selfSubmitted ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(entry.selfSubmitted ? "Plan submitted" : "Plan needed")
                        .font(.caption2)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Partner · \(entry.partnerDateKey)")
                    .font(.caption.bold())
                Text("\(entry.partnerRequiredCompleted)/\(entry.partnerRequiredCompleted + entry.partnerRequiredRemaining) required")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.partnerSubmitted ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(entry.partnerSubmitted ? "Plan submitted" : "Plan needed")
                        .font(.caption2)
                }

                if entry.isPendingAck {
                    Label("Settlement pending", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "coupletodo://dashboard"))
    }
}

// MARK: - Lock Screen / Accessory Widget

struct AccessoryWidgetView: View {
    let entry: CoupleTodoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: entry.isPendingAck ? "exclamationmark.triangle" : "checkmark.circle")
                Text("CoupleTodo")
                    .font(.headline)
            }
            if entry.isPlaceholder {
                Text("--")
            } else {
                Text("\(entry.selfRequiredRemaining) left")
            }
        }
        .widgetURL(URL(string: "coupletodo://dashboard"))
    }
}

// MARK: - Widget Definition

struct CoupleTodoWidget: Widget {
    let kind = "CoupleTodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleTodoTimelineProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                CoupleTodoWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                CoupleTodoWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Couple Todo")
        .description("Track daily tasks for you and your partner.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct CoupleTodoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoupleTodoEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle Entry Point

@main
struct CoupleTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoupleTodoWidget()
    }
}
