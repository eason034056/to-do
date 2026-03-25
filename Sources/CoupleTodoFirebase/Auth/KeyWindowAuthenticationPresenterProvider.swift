#if os(iOS)
import Foundation
import UIKit

@MainActor
struct KeyWindowAuthenticationPresenterProvider: AuthenticationPresenterProviding {
    func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let rootViewController = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        return Self.resolveTopViewController(from: rootViewController)
    }

    private static func resolveTopViewController(from viewController: UIViewController?) -> UIViewController? {
        if let navigationController = viewController as? UINavigationController {
            return resolveTopViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = viewController as? UITabBarController {
            return resolveTopViewController(from: tabBarController.selectedViewController)
        }
        if let presentedViewController = viewController?.presentedViewController {
            return resolveTopViewController(from: presentedViewController)
        }
        return viewController
    }
}
#endif
