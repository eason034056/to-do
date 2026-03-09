import Foundation
import CoupleTodoCore
#if canImport(WidgetKit)
import WidgetKit
#endif

struct SharedSnapshotWriter {
    let appGroupIdentifier: String
    let filename: String

    init(
        appGroupIdentifier: String = "group.com.coupletodo.shared",
        filename: String = "shared_snapshot.json"
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.filename = filename
    }

    func write(from snapshot: DashboardSnapshot) throws {
        let sharedSnapshot = SharedSnapshot(
            generatedAt: Date(),
            today: SharedSnapshot.TodaySnapshot(
                selfDateKey: snapshot.selfContext.dateKey,
                partnerDateKey: snapshot.partnerContext.dateKey,
                selfSummary: .init(
                    timezone: snapshot.selfContext.timezoneIdentifier,
                    requiredRemaining: snapshot.selfRequired.filter { $0.status != .completed }.count,
                    requiredCompleted: snapshot.selfRequired.filter { $0.status == .completed }.count,
                    topTasks: Array(snapshot.selfRequired.prefix(3)).map(\.title)
                ),
                partner: .init(
                    timezone: snapshot.partnerContext.timezoneIdentifier,
                    requiredRemaining: snapshot.partnerRequired.filter { $0.status != .completed }.count,
                    requiredCompleted: snapshot.partnerRequired.filter { $0.status == .completed }.count,
                    topTasks: Array(snapshot.partnerRequired.prefix(3)).map(\.title)
                )
            ),
            planning: SharedSnapshot.PlanningSnapshot(
                targetDateKey: snapshot.planningTargetDateKey,
                selfSubmitted: snapshot.selfSubmittedNextPlan,
                partnerSubmitted: snapshot.partnerSubmittedNextPlan
            ),
            settlement: SharedSnapshot.SettlementSnapshot(
                selfDateKey: snapshot.latestSettlement?.dateKey ?? snapshot.selfContext.dateKey,
                partnerLatestDateKey: snapshot.latestSettlement?.counterpartySnapshot.latestKnownDateKey,
                isPendingAck: snapshot.latestSettlement?.pendingAcknowledgementUserIds.contains(snapshot.user.id) ?? false,
                selfOutcome: snapshot.latestSettlement?.subjectResult.outcome,
                partnerOutcome: snapshot.latestSettlement?.counterpartySnapshot.latestKnownOutcome,
                selfOwesAmount: snapshot.latestSettlement?.subjectResult.owesAmount ?? 0
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(sharedSnapshot)

        let directoryURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
