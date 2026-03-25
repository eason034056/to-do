import Foundation

public struct AuthSession: Equatable, Sendable {
    public let userId: String
    public let email: String?
    public let displayName: String?
    public let photoURL: String?

    public init(
        userId: String,
        email: String? = nil,
        displayName: String? = nil,
        photoURL: String? = nil
    ) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
    }
}

public enum AuthenticationProvider: String, CaseIterable, Sendable {
    case apple
    case google
}

@MainActor
public protocol AuthenticationService: AnyObject {
    func currentSession() -> AuthSession?
    func signIn(with provider: AuthenticationProvider) async throws -> AuthSession
    func handleOpenURL(_ url: URL) -> Bool
    func signOut() throws
}
