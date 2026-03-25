import FirebaseCore

public enum FirebaseBootstrap {
    public static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}
