import Foundation

public enum ConnectivityStatus: String, Sendable {
    case online
    case offline
    case unknown
}

public protocol NetworkMonitor: Sendable {
    var currentStatus: ConnectivityStatus { get }
    func statusStream() -> AsyncStream<ConnectivityStatus>
}

public final class StubNetworkMonitor: NetworkMonitor, @unchecked Sendable {
    public var currentStatus: ConnectivityStatus = .online

    public init() {}

    public func statusStream() -> AsyncStream<ConnectivityStatus> {
        AsyncStream { continuation in
            continuation.yield(.online)
        }
    }
}
