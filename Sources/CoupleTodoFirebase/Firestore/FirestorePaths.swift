import Foundation

public enum FirestorePaths {
    public static let users = "users"
    public static let deviceInstallations = "deviceInstallations"
    public static let couples = "couples"
    public static let plans = "plans"
    public static let tasks = "tasks"
    public static let settlements = "settlements"
    public static let rewardWeeks = "rewardWeeks"
    public static let payments = "payments"
    public static let events = "events"

    public static func userDocument(_ userId: String) -> String {
        "\(users)/\(userId)"
    }

    public static func deviceInstallationDocument(_ installationId: String) -> String {
        "\(deviceInstallations)/\(installationId)"
    }

    public static func coupleDocument(_ coupleId: String) -> String {
        "\(couples)/\(coupleId)"
    }

    public static func planDocument(coupleId: String, planId: String) -> String {
        "\(coupleDocument(coupleId))/\(plans)/\(planId)"
    }

    public static func taskDocument(coupleId: String, planId: String, taskId: String) -> String {
        "\(planDocument(coupleId: coupleId, planId: planId))/\(tasks)/\(taskId)"
    }

    public static func settlementDocument(coupleId: String, settlementId: String) -> String {
        "\(coupleDocument(coupleId))/\(settlements)/\(settlementId)"
    }

    public static func rewardWeekDocument(coupleId: String, weekKey: String) -> String {
        "\(coupleDocument(coupleId))/\(rewardWeeks)/\(weekKey)"
    }

    public static func paymentDocument(coupleId: String, recordId: String) -> String {
        "\(coupleDocument(coupleId))/\(payments)/\(recordId)"
    }

    public static func eventDocument(coupleId: String, eventId: String) -> String {
        "\(coupleDocument(coupleId))/\(events)/\(eventId)"
    }

    public static func planId(userId: String, dateKey: String) -> String {
        "\(userId)_\(dateKey)"
    }
}
