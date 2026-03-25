#if os(iOS)
import Foundation
import Network
import CoupleTodoCore

public final class NWPathNetworkMonitor: NetworkMonitor, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.coupletodo.network-monitor")
    private let lock = NSLock()
    private var _currentStatus: ConnectivityStatus = .unknown
    private var continuations: [UUID: AsyncStream<ConnectivityStatus>.Continuation] = [:]

    public var currentStatus: ConnectivityStatus {
        lock.lock()
        defer { lock.unlock() }
        return _currentStatus
    }

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let status: ConnectivityStatus = path.status == .satisfied ? .online : .offline
            self.lock.lock()
            self._currentStatus = status
            let activeContinuations = self.continuations
            self.lock.unlock()
            for (_, continuation) in activeContinuations {
                continuation.yield(status)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    public func statusStream() -> AsyncStream<ConnectivityStatus> {
        let id = UUID()
        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            self.lock.lock()
            self.continuations[id] = continuation
            let current = self._currentStatus
            self.lock.unlock()
            continuation.yield(current)

            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations.removeValue(forKey: id)
                self?.lock.unlock()
            }
        }
    }
}
#endif
