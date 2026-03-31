#if os(iOS)
import Foundation

public protocol CrashReportingService: Sendable {
    func setUserId(_ userId: String?)
    func log(_ message: String)
    func recordError(_ error: Error, context: [String: String])
}

public final class FirebaseCrashReportingService: CrashReportingService, @unchecked Sendable {
    public init() {}

    public func setUserId(_ userId: String?) {
        // Crashlytics.crashlytics().setUserID(userId ?? "")
        #if DEBUG
        print("[Crash] setUserId: \(userId ?? "nil")")
        #endif
    }

    public func log(_ message: String) {
        // Crashlytics.crashlytics().log(message)
        #if DEBUG
        print("[Crash] log: \(message)")
        #endif
    }

    public func recordError(_ error: Error, context: [String: String] = [:]) {
        // Crashlytics.crashlytics().record(error: error, userInfo: context)
        #if DEBUG
        print("[Crash] error: \(error.localizedDescription) context: \(context)")
        #endif
    }
}

public final class StubCrashReportingService: CrashReportingService, @unchecked Sendable {
    public var recordedErrors: [(error: Error, context: [String: String])] = []

    public init() {}

    public func setUserId(_ userId: String?) {}

    public func log(_ message: String) {}

    public func recordError(_ error: Error, context: [String: String] = [:]) {
        recordedErrors.append((error: error, context: context))
    }
}
#endif
