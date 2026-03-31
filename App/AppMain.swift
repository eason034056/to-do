import SwiftUI
import CoupleTodoFirebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    weak var coordinator: AppCoordinator?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfNeeded()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        NotificationService.registerCategories()
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - APNs token relay

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            coordinator?.handleAPNsTokenUpdate(tokenString)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // APNs registration failed; push notifications will not work on this device.
    }

    // MARK: - FCM token refresh

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            coordinator?.handleFCMTokenUpdate(fcmToken)
        }
    }

    // MARK: - Foreground notification display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: - Notification tap routing

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let url = NotificationService.deepLinkURL(from: userInfo) {
            await MainActor.run {
                coordinator?.handleIncomingURL(url)
            }
        }
    }
}

@main
struct CoupleTodoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var coordinator = AppCoordinator(environment: .live())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .onAppear {
                    delegate.coordinator = coordinator
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await coordinator.handleAppBecameActive()
                        }
                    }
                }
        }
    }
}
