#if os(iOS)
import CoupleTodoCore
@preconcurrency import FirebaseFunctions
import Foundation

public struct PairingResult: Equatable, Sendable {
    public let coupleId: String
    public let memberIds: [String]
    public let status: CoupleStatus
    public let inviteCode: String?

    public init(coupleId: String, memberIds: [String], status: CoupleStatus, inviteCode: String?) {
        self.coupleId = coupleId
        self.memberIds = memberIds
        self.status = status
        self.inviteCode = inviteCode
    }
}

public protocol CoupleLifecycleGateway: AnyObject {
    func createCouple(
        weekStartsOn: WeekStart,
        reminderConfig: ReminderConfig,
        penaltyPolicy: PenaltyPolicy
    ) async throws -> PairingResult
    func joinCouple(inviteCode: String) async throws -> PairingResult
    func deleteAccount() async throws
}

public final class FirebaseCoupleLifecycleGateway: CoupleLifecycleGateway {
    private let functions: Functions

    public init(functions: Functions = Functions.functions()) {
        self.functions = functions
    }

    public func createCouple(
        weekStartsOn: WeekStart,
        reminderConfig: ReminderConfig,
        penaltyPolicy: PenaltyPolicy
    ) async throws -> PairingResult {
        try await call(
            functionName: "createCouple",
            data: [
                "weekStartsOn": weekStartsOn.rawValue,
                "reminderConfig": ReminderConfigDocument.encode(reminderConfig),
                "penaltyPolicy": PenaltyPolicyDocument.encode(penaltyPolicy)
            ]
        )
    }

    public func joinCouple(inviteCode: String) async throws -> PairingResult {
        try await call(
            functionName: "joinCouple",
            data: [
                "inviteCode": inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            ]
        )
    }

    public func deleteAccount() async throws {
        _ = try await functions.httpsCallable("deleteAccount").call([:])
    }

    private func call(functionName: String, data: [String: Any]) async throws -> PairingResult {
        let result = try await functions.httpsCallable(functionName).call(data)
        return try Self.decodePairingResult(result.data)
    }

    private static func decodePairingResult(_ raw: Any) throws -> PairingResult {
        guard let data = raw as? [String: Any] else {
            throw FirestoreDecodingError.invalidField("callableResponse")
        }
        return PairingResult(
            coupleId: try FirestoreDocumentValue.requiredString(data, "coupleId"),
            memberIds: try FirestoreDocumentValue.requiredStringArray(data, "memberIds"),
            status: CoupleStatus(rawValue: try FirestoreDocumentValue.requiredString(data, "status")) ?? .pending,
            inviteCode: FirestoreDocumentValue.optionalString(data, "inviteCode")
        )
    }
}
#endif
