import Foundation

struct DashboardSnapshot {
    let selfDateLabel: String
    let partnerDateLabel: String
    let selfRequired: [TodoTask]
    let partnerRequired: [TodoTask]
    let latestSettlement: SettlementSummary
}

enum MockDashboardService {
    static func makeSnapshot() -> DashboardSnapshot {
        let selfContext = LocalTimeContextFactory.make()
        let partnerTimezone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let partnerContext = LocalTimeContextFactory.make(timezone: partnerTimezone)

        let selfTasks = [
            TodoTask(
                id: "t1",
                ownerUserId: "usr_self",
                dateKey: selfContext.dateKey,
                localTimezone: selfContext.timezoneIdentifier,
                title: "完成今天的核心工作",
                notes: nil,
                bucket: .required,
                priority: .p0,
                status: .pending,
                sortOrder: 1,
                completedAtServer: nil
            )
        ]

        let partnerTasks = [
            TodoTask(
                id: "t2",
                ownerUserId: "usr_partner",
                dateKey: partnerContext.dateKey,
                localTimezone: partnerContext.timezoneIdentifier,
                title: "30 分鐘運動",
                notes: nil,
                bucket: .required,
                priority: .p1,
                status: .completed,
                sortOrder: 1,
                completedAtServer: Date()
            )
        ]

        let settlement = SettlementSummary(
            id: "usr_self_\(selfContext.dateKey)",
            subjectUserId: "usr_self",
            counterpartyUserId: "usr_partner",
            dateKey: selfContext.dateKey,
            localTimezone: selfContext.timezoneIdentifier,
            requiredTotal: 4,
            requiredCompleted: 3,
            owesAmount: 50,
            isPass: false
        )

        return DashboardSnapshot(
            selfDateLabel: "Today - \(selfContext.dateKey) (\(shortLabel(for: selfContext.timezoneIdentifier)))",
            partnerDateLabel: "Partner Today - \(partnerContext.dateKey) (\(shortLabel(for: partnerContext.timezoneIdentifier)))",
            selfRequired: selfTasks,
            partnerRequired: partnerTasks,
            latestSettlement: settlement
        )
    }

    private static func shortLabel(for identifier: String) -> String {
        TimeZone(identifier: identifier)?.abbreviation() ?? identifier
    }
}
