import Foundation

enum DeepLinkRouter {
    static func route(for url: URL) -> AppRoute? {
        guard url.scheme == "coupletodo" else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }

        switch url.host {
        case "planning":
            return components.first.map { .planning(dateKey: $0) }
        case "settlement":
            return components.first.map { .settlement(dateKey: $0) }
        case "rewards":
            return components.first.map { .rewards(weekKey: $0) }
        case "settings":
            return .settings
        case "pairing":
            return .pairing
        case "auth":
            return .auth
        case "dashboard":
            return .dashboard
        default:
            return nil
        }
    }
}
