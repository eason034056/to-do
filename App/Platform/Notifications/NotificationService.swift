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
                UNNotificationAction(identifier: "open_planning", title: "Open Planning", options: .foreground)
            ],
            intentIdentifiers: [],
            options: []
        )

        let planningEscalationCategory = UNNotificationCategory(
            identifier: NotificationCategory.planningEscalation.rawValue,
            actions: [
                UNNotificationAction(identifier: "open_planning", title: "Submit Now", options: .foreground)
            ],
            intentIdentifiers: [],
            options: []
        )

        let settlementReadyCategory = UNNotificationCategory(
            identifier: NotificationCategory.settlementReady.rawValue,
            actions: [
                UNNotificationAction(identifier: "open_settlement", title: "View Settlement", options: .foreground)
            ],
            intentIdentifiers: [],
            options: []
        )

        let rewardEarnedCategory = UNNotificationCategory(
            identifier: NotificationCategory.rewardEarned.rawValue,
            actions: [
                UNNotificationAction(identifier: "open_rewards", title: "View Reward", options: .foreground)
            ],
            intentIdentifiers: [],
            options: []
        )

        let paymentPendingCategory = UNNotificationCategory(
            identifier: NotificationCategory.paymentPending.rawValue,
            actions: [
                UNNotificationAction(identifier: "open_payment", title: "View Payment", options: .foreground)
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

    /// Extracts a deep link URL from the push notification payload.
    /// Backend attaches `deepLink` as a string in the `aps` custom data or top-level payload.
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
