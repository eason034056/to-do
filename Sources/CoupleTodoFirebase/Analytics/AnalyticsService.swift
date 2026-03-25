#if os(iOS)
import Foundation
import CoupleTodoCore

public enum AnalyticsEventName: String, Sendable {
    case appLaunch = "app_launch"
    case signIn = "sign_in"
    case signOut = "sign_out"
    case coupleCreated = "couple_created"
    case coupleJoined = "couple_joined"
    case planSubmitted = "plan_submitted"
    case taskCreated = "task_created"
    case taskCompleted = "task_completed"
    case settlementAcknowledged = "settlement_acknowledged"
    case paymentMarkedPaid = "payment_marked_paid"
    case rewardDraftSaved = "reward_draft_saved"
    case offlineDetected = "offline_detected"
    case syncFailed = "sync_failed"
    case syncRecovered = "sync_recovered"
    case timezoneChanged = "timezone_changed"
    case liveActivityStarted = "live_activity_started"
    case widgetViewed = "widget_viewed"
    case deepLinkHandled = "deep_link_handled"
    case notificationTapped = "notification_tapped"
}

public protocol AnalyticsService: Sendable {
    func logEvent(_ name: AnalyticsEventName, parameters: [String: String])
    func setUserId(_ userId: String?)
}

public final class FirebaseAnalyticsService: AnalyticsService, @unchecked Sendable {
    public init() {}

    public func logEvent(_ name: AnalyticsEventName, parameters: [String: String] = [:]) {
        // Firebase Analytics logging placeholder.
        // Requires `FirebaseAnalytics` pod/SPM to be added.
        // Analytics.logEvent(name.rawValue, parameters: parameters)
        #if DEBUG
        print("[Analytics] \(name.rawValue) \(parameters)")
        #endif
    }

    public func setUserId(_ userId: String?) {
        // Analytics.setUserID(userId)
        #if DEBUG
        print("[Analytics] setUserId: \(userId ?? "nil")")
        #endif
    }
}

public final class StubAnalyticsService: AnalyticsService, @unchecked Sendable {
    public var loggedEvents: [(name: AnalyticsEventName, parameters: [String: String])] = []

    public init() {}

    public func logEvent(_ name: AnalyticsEventName, parameters: [String: String] = [:]) {
        loggedEvents.append((name: name, parameters: parameters))
    }

    public func setUserId(_ userId: String?) {}
}
#endif
