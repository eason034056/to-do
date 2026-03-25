import Foundation

public enum FirestoreCollection: String, CaseIterable, Sendable {
    case users
    case deviceInstallations
    case couples
    case invites
    case plans
    case tasks
    case settlements
    case rewardWeeks
    case events
}

public enum FirestoreDocumentID {
    public static func plan(userId: String, dateKey: String) -> String {
        "\(userId)_\(dateKey)"
    }

    public static func settlement(subjectUserId: String, dateKey: String) -> String {
        "\(subjectUserId)_\(dateKey)"
    }

    public static func rewardWeek(_ weekKey: String) -> String {
        weekKey
    }

    public static func invite(_ inviteCode: String) -> String {
        inviteCode.uppercased()
    }
}

public enum FirestorePath {
    public static func user(_ userId: String) -> String {
        "\(FirestoreCollection.users.rawValue)/\(userId)"
    }

    public static func deviceInstallation(_ installationId: String) -> String {
        "\(FirestoreCollection.deviceInstallations.rawValue)/\(installationId)"
    }

    public static func couple(_ coupleId: String) -> String {
        "\(FirestoreCollection.couples.rawValue)/\(coupleId)"
    }

    public static func invite(_ inviteCode: String) -> String {
        "\(FirestoreCollection.invites.rawValue)/\(FirestoreDocumentID.invite(inviteCode))"
    }

    public static func plan(coupleId: String, userId: String, dateKey: String) -> String {
        "\(couple(coupleId))/\(FirestoreCollection.plans.rawValue)/\(FirestoreDocumentID.plan(userId: userId, dateKey: dateKey))"
    }

    public static func task(coupleId: String, userId: String, dateKey: String, taskId: String) -> String {
        "\(plan(coupleId: coupleId, userId: userId, dateKey: dateKey))/\(FirestoreCollection.tasks.rawValue)/\(taskId)"
    }

    public static func settlement(coupleId: String, subjectUserId: String, dateKey: String) -> String {
        "\(couple(coupleId))/\(FirestoreCollection.settlements.rawValue)/\(FirestoreDocumentID.settlement(subjectUserId: subjectUserId, dateKey: dateKey))"
    }

    public static func rewardWeek(coupleId: String, weekKey: String) -> String {
        "\(couple(coupleId))/\(FirestoreCollection.rewardWeeks.rawValue)/\(FirestoreDocumentID.rewardWeek(weekKey))"
    }

    public static func event(coupleId: String, eventId: String) -> String {
        "\(couple(coupleId))/\(FirestoreCollection.events.rawValue)/\(eventId)"
    }
}
