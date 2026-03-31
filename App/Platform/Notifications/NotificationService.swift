import Foundation
import UserNotifications

enum NotificationCategory: String, CaseIterable {
    case planningReminder = "planning_reminder"
    case planningEscalation = "planning_escalation"
    case settlementReady = "settlement_ready"
    case rewardEarned = "reward_earned"
    case paymentPending = "payment_pending"
}

enum NotificationService {

    static func registerCategories() {
        let planningReminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.planningReminder.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: "open_planning",
                    title: NotificationCopy.actionTitle(for: .planningReminder),
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let planningEscalationCategory = UNNotificationCategory(
            identifier: NotificationCategory.planningEscalation.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: "open_planning",
                    title: NotificationCopy.actionTitle(for: .planningEscalation),
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let settlementReadyCategory = UNNotificationCategory(
            identifier: NotificationCategory.settlementReady.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: "open_settlement",
                    title: NotificationCopy.actionTitle(for: .settlementReady),
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let rewardEarnedCategory = UNNotificationCategory(
            identifier: NotificationCategory.rewardEarned.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: "open_rewards",
                    title: NotificationCopy.actionTitle(for: .rewardEarned),
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let paymentPendingCategory = UNNotificationCategory(
            identifier: NotificationCategory.paymentPending.rawValue,
            actions: [
                UNNotificationAction(
                    identifier: "open_payment",
                    title: NotificationCopy.actionTitle(for: .paymentPending),
                    options: .foreground
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            planningReminderCategory,
            planningEscalationCategory,
            settlementReadyCategory,
            rewardEarnedCategory,
            paymentPendingCategory
        ])
    }

    static func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func isTimeSensitiveAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.timeSensitiveSetting == .enabled
    }

    static func deepLinkURL(from userInfo: [AnyHashable: Any]) -> URL? {
        if let deepLink = userInfo["deepLink"] as? String {
            return URL(string: deepLink)
        }
        if let aps = userInfo["aps"] as? [String: Any],
           let deepLink = aps["deepLink"] as? String {
            return URL(string: deepLink)
        }
        return nil
    }
}
