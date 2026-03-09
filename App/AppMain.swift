import SwiftUI

@main
struct CoupleTodoApp: App {
    @StateObject private var coordinator = AppCoordinator(environment: .demo())

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
        }
    }
}
