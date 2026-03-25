import Foundation

enum AppRoute: Hashable, Identifiable {
    case auth
    case pairing
    case dashboard
    case planning(dateKey: String)
    case settlement(dateKey: String)
    case settlementHistory
    case payment(recordId: String)
    case rewards(weekKey: String)
    case settings

    var id: String {
        switch self {
        case .auth:
            return "auth"
        case .pairing:
            return "pairing"
        case .dashboard:
            return "dashboard"
        case let .planning(dateKey):
            return "planning_\(dateKey)"
        case let .settlement(dateKey):
            return "settlement_\(dateKey)"
        case .settlementHistory:
            return "settlement_history"
        case let .payment(recordId):
            return "payment_\(recordId)"
        case let .rewards(weekKey):
            return "rewards_\(weekKey)"
        case .settings:
            return "settings"
        }
    }
}
