#if os(iOS)
import CoupleTodoCore
@preconcurrency import FirebaseFirestore
import Foundation

public struct FirebaseAppServices {
    public let authService: any AuthenticationService
    public let coupleLifecycleGateway: any CoupleLifecycleGateway
    public let userRepository: any UserRepository
    public let coupleRepository: any CoupleRepository
    public let deviceInstallationRepository: any DeviceInstallationRepository
    public let planRepository: any PlanRepository
    public let taskRepository: any TaskRepository
    public let settlementRepository: any SettlementRepository
    public let rewardWeekRepository: any RewardWeekRepository
    public let paymentRepository: any PaymentRepository
    public let eventRepository: any EventRepository

    @MainActor
    public static func live() -> FirebaseAppServices {
        FirebaseBootstrap.configureIfNeeded()

        let database = Firestore.firestore()
        return FirebaseAppServices(
            authService: FirebaseAuthenticationService(),
            coupleLifecycleGateway: FirebaseCoupleLifecycleGateway(),
            userRepository: FirestoreUserRepository(database: database),
            coupleRepository: FirestoreCoupleRepository(database: database),
            deviceInstallationRepository: FirestoreDeviceInstallationRepository(database: database),
            planRepository: FirestorePlanRepository(database: database),
            taskRepository: FirestoreTaskRepository(database: database),
            settlementRepository: FirestoreSettlementRepository(database: database),
            rewardWeekRepository: FirestoreRewardWeekRepository(database: database),
            paymentRepository: FirestorePaymentRepository(database: database),
            eventRepository: FirestoreEventRepository(database: database)
        )
    }
}
#endif
