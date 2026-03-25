@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseFunctions
import Foundation

extension Auth {
    func signInAsync(with credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: FirebaseAsyncError.missingResult("AuthDataResult"))
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }
}

extension UserProfileChangeRequest {
    func commitChangesAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            commitChanges { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}

extension DocumentReference {
    func getDocumentAsync() async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: FirebaseAsyncError.missingResult("DocumentSnapshot"))
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    func setDataAsync(_ data: [String: Any], merge: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func updateDataAsync(_ fields: [AnyHashable: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            updateData(fields) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func deleteAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            delete { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}

extension Query {
    func getDocumentsAsync() async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: FirebaseAsyncError.missingResult("QuerySnapshot"))
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }
}

extension WriteBatch {
    func commitAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            commit { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}

enum FirebaseAsyncError: LocalizedError {
    case missingResult(String)

    var errorDescription: String? {
        switch self {
        case let .missingResult(typeName):
            return "Missing Firebase async result for \(typeName)."
        }
    }
}
