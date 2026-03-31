import XCTest
@testable import CoupleTodoCore

@MainActor
final class SyncStatusTrackerTests: XCTestCase {

    func testInitialState() {
        let tracker = SyncStatusTracker()
        XCTAssertEqual(tracker.status, .idle)
        XCTAssertNil(tracker.lastSyncedAt)
        XCTAssertEqual(tracker.consecutiveFailureCount, 0)
        XCTAssertFalse(tracker.shouldDisplayOfflineBanner)
    }

    func testMarkSyncing() {
        let tracker = SyncStatusTracker()
        tracker.markSyncing()
        XCTAssertEqual(tracker.status, .syncing, "markSyncing() 後 status 應為 .syncing")
    }

    func testMarkSuccess_resetsFailureCount() {
        let tracker = SyncStatusTracker()
        tracker.markFailed(error: "timeout")
        tracker.markFailed(error: "timeout")
        XCTAssertEqual(tracker.consecutiveFailureCount, 2)

        let now = Date()
        tracker.markSuccess(at: now)
        XCTAssertEqual(tracker.status, .idle, "markSuccess 後 status 回 idle")
        XCTAssertEqual(tracker.consecutiveFailureCount, 0, "成功後計數重置")
        XCTAssertEqual(tracker.lastSyncedAt, now)
    }

    func testMarkFailed_underThreshold_pendingRetry() {
        let tracker = SyncStatusTracker()
        tracker.markFailed(error: "first")
        XCTAssertEqual(tracker.status, .pendingRetry, "第 1 次失敗為 pendingRetry")
        XCTAssertEqual(tracker.consecutiveFailureCount, 1)

        tracker.markFailed(error: "second")
        XCTAssertEqual(tracker.status, .pendingRetry, "第 2 次失敗仍為 pendingRetry")
    }

    func testMarkFailed_atThreshold_syncFailed() {
        let tracker = SyncStatusTracker()
        tracker.markFailed(error: "1")
        tracker.markFailed(error: "2")
        tracker.markFailed(error: "3")
        XCTAssertEqual(tracker.status, .syncFailed, "第 3 次失敗轉為 syncFailed")
        XCTAssertTrue(tracker.shouldDisplayOfflineBanner, "syncFailed 時應顯示 offline banner")
    }

    func testRetryDelay_exponentialBackoff() {
        let tracker = SyncStatusTracker()

        tracker.markFailed(error: "err")
        let delay1 = tracker.retryDelay
        XCTAssertEqual(delay1, 2.0, accuracy: 0.01, "第 1 次失敗: 2^1 = 2 秒")

        tracker.markFailed(error: "err")
        let delay2 = tracker.retryDelay
        XCTAssertEqual(delay2, 4.0, accuracy: 0.01, "第 2 次失敗: 2^2 = 4 秒")

        tracker.markFailed(error: "err")
        let delay3 = tracker.retryDelay
        XCTAssertEqual(delay3, 8.0, accuracy: 0.01, "第 3 次失敗: 2^3 = 8 秒")
    }

    func testRetryDelay_capped() {
        let tracker = SyncStatusTracker()
        for _ in 0..<20 {
            tracker.markFailed(error: "err")
        }
        XCTAssertLessThanOrEqual(tracker.retryDelay, 300.0, "最大重試延遲不超過 300 秒")
    }

    func testReset_clearsAll() {
        let tracker = SyncStatusTracker()
        tracker.markFailed(error: "err")
        tracker.markFailed(error: "err")
        tracker.markFailed(error: "err")
        tracker.reset()

        XCTAssertEqual(tracker.status, .idle)
        XCTAssertNil(tracker.lastSyncedAt)
        XCTAssertEqual(tracker.consecutiveFailureCount, 0)
        XCTAssertNil(tracker.lastErrorMessage)
    }
}
