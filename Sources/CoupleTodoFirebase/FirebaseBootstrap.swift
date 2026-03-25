import FirebaseCore
@preconcurrency import FirebaseFirestore

public enum FirebaseBootstrap {
    public static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        configureFirestorePersistence()
    }

    private static func configureFirestorePersistence() {
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber)
        Firestore.firestore().settings = settings
    }
}
