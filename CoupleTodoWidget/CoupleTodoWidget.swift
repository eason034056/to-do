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
            pendingPaymentCount: snapshot.payments?.pendingCount ?? 0,
            rewardStatus: snapshot.reward?.status,
            rewardText: snapshot.reward?.rewardText,
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
    let pendingPaymentCount: Int
    let rewardStatus: String?
    let rewardText: String?
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
        pendingPaymentCount: 0,
        rewardStatus: nil,
        rewardText: nil,
        isPlaceholder: true
    )

    var selfTotal: Int { selfRequiredCompleted + selfRequiredRemaining }
    var partnerTotal: Int { partnerRequiredCompleted + partnerRequiredRemaining }
    var selfProgress: Double { selfTotal == 0 ? 1 : Double(selfRequiredCompleted) / Double(selfTotal) }
    var partnerProgress: Double { partnerTotal == 0 ? 1 : Double(partnerRequiredCompleted) / Double(partnerTotal) }
}

// MARK: - Palette

private enum WidgetPalette {
    static let accent = Color(red: 0.21, green: 0.345, blue: 0.447)
    static let youColor = accent
    static let partnerColor = accent.opacity(0.55)
    static let success = Color(red: 0.30, green: 0.50, blue: 0.38)
    static let active = accent
    static let urgent = Color(red: 0.65, green: 0.25, blue: 0.22)
    static let calm = Color.secondary
}

private func widgetAccent(for entry: CoupleTodoEntry) -> Color {
    if entry.isPendingAck || entry.pendingPaymentCount > 0 { return WidgetPalette.urgent }
    if entry.rewardStatus == "earned" { return WidgetPalette.success }
    if entry.selfSubmitted == false { return WidgetPalette.active }
    return WidgetPalette.calm
}

private func widgetStatusText(for entry: CoupleTodoEntry) -> String {
    if entry.isPlaceholder { return "Open app to sync" }
    if entry.isPendingAck { return "Recap pending" }
    if entry.pendingPaymentCount > 0 { return "\(entry.pendingPaymentCount) payment" }
    if entry.rewardStatus == "earned" { return "Reward earned!" }
    if entry.selfRequiredRemaining == 0, entry.selfRequiredCompleted > 0 { return "All done!" }
    if entry.selfSubmitted == false { return "Plan tomorrow" }
    return "\(entry.selfRequiredRemaining) left"
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: CoupleTodoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                smallRing(progress: entry.selfProgress, color: WidgetPalette.youColor)
                smallRing(progress: entry.partnerProgress, color: WidgetPalette.partnerColor)
                Spacer()
            }

            Text("\(entry.selfRequiredCompleted)/\(entry.selfTotal)")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(widgetStatusText(for: entry))
                .font(.caption.bold())
                .foregroundStyle(widgetAccent(for: entry))
        }
        .widgetURL(URL(string: "coupletodo://dashboard"))
    }

    private func smallRing(progress: Double, color: Color) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 3)
            Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: CoupleTodoEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CoupleTodo")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    memberColumn(
                        label: "You",
                        completed: entry.selfRequiredCompleted,
                        total: entry.selfTotal,
                        progress: entry.selfProgress,
                        color: WidgetPalette.youColor,
                        submitted: entry.selfSubmitted
                    )
                    memberColumn(
                        label: "Partner",
                        completed: entry.partnerRequiredCompleted,
                        total: entry.partnerTotal,
                        progress: entry.partnerProgress,
                        color: WidgetPalette.partnerColor,
                        submitted: entry.partnerSubmitted
                    )
                }
            }

            Spacer()

            if entry.selfTopTasks.isEmpty == false {
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(entry.selfTopTasks.prefix(3), id: \.self) { task in
                        Text(task)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .widgetURL(URL(string: "coupletodo://dashboard"))
    }

    private func memberColumn(label: String, completed: Int, total: Int, progress: Double, color: Color, submitted: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 4)
                Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(completed)/\(total)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .frame(width: 40, height: 40)

            Text(label)
                .font(.caption2.bold())

            Image(systemName: submitted ? "checkmark.circle.fill" : "clock")
                .font(.caption2)
                .foregroundStyle(submitted ? WidgetPalette.success : .secondary)
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: CoupleTodoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CoupleTodo")
                    .font(.headline.bold())
                    .fontDesign(.rounded)
                Spacer()
                Text(entry.selfDateKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                largeRing(
                    label: "You",
                    completed: entry.selfRequiredCompleted,
                    total: entry.selfTotal,
                    progress: entry.selfProgress,
                    color: WidgetPalette.youColor
                )
                largeRing(
                    label: "Partner",
                    completed: entry.partnerRequiredCompleted,
                    total: entry.partnerTotal,
                    progress: entry.partnerProgress,
                    color: WidgetPalette.partnerColor
                )
            }
            .frame(maxWidth: .infinity)

            Text("Your Tasks")
                .font(.callout.bold())

            if entry.selfTopTasks.isEmpty {
                Text("No tasks to show")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.selfTopTasks.prefix(5), id: \.self) { task in
                    HStack(spacing: 8) {
                        Circle()
                            .stroke(WidgetPalette.active, lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                        Text(task)
                            .font(.callout)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            HStack {
                Text(widgetStatusText(for: entry))
                    .font(.caption.bold())
                    .foregroundStyle(widgetAccent(for: entry))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: entry.selfSubmitted ? "checkmark.circle.fill" : "calendar.badge.plus")
                        .foregroundStyle(entry.selfSubmitted ? WidgetPalette.success : WidgetPalette.active)
                    Text(entry.selfSubmitted ? "Planned" : "Not planned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .widgetURL(URL(string: "coupletodo://dashboard"))
    }

    private func largeRing(label: String, completed: Int, total: Int, progress: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 6)
                Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(completed)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("/\(total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)

            Text(label)
                .font(.caption.bold())
        }
    }
}

// MARK: - Accessory Rectangular

struct AccessoryRectangularView: View {
    let entry: CoupleTodoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("CoupleTodo", systemImage: "heart.fill")
                .font(.caption.bold())
            Text(entry.isPlaceholder ? "--" : widgetStatusText(for: entry))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "coupletodo://dashboard"))
    }
}

// MARK: - Accessory Circular

struct AccessoryCircularView: View {
    let entry: CoupleTodoEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Gauge(value: entry.selfProgress) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
            }
            .gaugeStyle(.accessoryCircular)
        }
        .widgetURL(URL(string: "coupletodo://dashboard"))
    }
}

// MARK: - Widget Definition

struct CoupleTodoWidget: Widget {
    let kind = "CoupleTodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleTodoTimelineProvider()) { entry in
            CoupleTodoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Couple Board")
        .description("Track your shared progress and upcoming tasks together.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular
        ])
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
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
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
