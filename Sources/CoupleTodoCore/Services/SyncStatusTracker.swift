import Foundation

public enum SyncStatus: String, Sendable, Equatable {
    case idle
    case syncing
    case syncFailed
    case pendingRetry
}

@MainActor
public final class SyncStatusTracker: ObservableObject, Sendable {
    @Published public private(set) var status: SyncStatus = .idle
    @Published public private(set) var lastSyncedAt: Date?
    @Published public private(set) var lastErrorMessage: String?
    @Published public private(set) var consecutiveFailureCount: Int = 0

    private static let maxRetryDelaySeconds: Double = 300

    public init() {}

    public func markSyncing() {
        status = .syncing
        lastErrorMessage = nil
    }

    public func markSuccess(at date: Date) {
        status = .idle
        lastSyncedAt = date
        lastErrorMessage = nil
        consecutiveFailureCount = 0
    }

    public func markFailed(error: String) {
        consecutiveFailureCount += 1
        lastErrorMessage = error

        if consecutiveFailureCount >= 3 {
            status = .syncFailed
        } else {
            status = .pendingRetry
        }
    }

    public func reset() {
        status = .idle
        lastSyncedAt = nil
        lastErrorMessage = nil
        consecutiveFailureCount = 0
    }

    public var retryDelay: TimeInterval {
        let base = pow(2.0, Double(min(consecutiveFailureCount, 8)))
        return min(base, Self.maxRetryDelaySeconds)
    }

    public var shouldDisplayOfflineBanner: Bool {
        status == .syncFailed
    }
}
