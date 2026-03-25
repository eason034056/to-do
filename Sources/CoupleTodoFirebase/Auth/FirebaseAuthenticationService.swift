#if os(iOS)
import AuthenticationServices
import CryptoKit
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseCore
import Foundation
@preconcurrency import GoogleSignIn
import UIKit

public enum FirebaseAuthenticationError: LocalizedError, Equatable {
    case missingIdentityToken
    case invalidIdentityToken
    case unsupportedCredential
    case missingClientID
    case missingIDToken
    case missingAccessToken
    case cancelled
    case unsupportedURL
    case missingPresentationContext

    public var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple Sign-In did not return an identity token."
        case .invalidIdentityToken:
            return "Apple Sign-In returned an invalid identity token."
        case .unsupportedCredential:
            return "The selected sign-in provider returned an unsupported credential."
        case .missingClientID:
            return "Firebase Google Sign-In is missing a client ID."
        case .missingIDToken:
            return "Google Sign-In did not return an ID token."
        case .missingAccessToken:
            return "Google Sign-In did not return an access token."
        case .cancelled:
            return "Sign in was cancelled."
        case .unsupportedURL:
            return "The incoming URL is not a supported authentication callback."
        case .missingPresentationContext:
            return "Could not find a view controller to present authentication."
        }
    }
}

typealias FirebaseAuthCredential = AuthCredential

@MainActor
protocol FirebaseAuthProviding {
    func currentSession() -> AuthSession?
    func signIn(with credential: FirebaseAuthCredential) async throws -> FirebaseAuthenticationResult
    func signOut() throws
}

struct FirebaseAuthenticationResult {
    let session: AuthSession
    let updateDisplayName: @MainActor (String) async throws -> Void
}

@MainActor
protocol AppleSignInAuthorizing {
    func authorize(hashedNonce: String) async throws -> AppleSignInPayload
}

struct AppleSignInPayload {
    let identityToken: Data?
    let fullName: PersonNameComponents?
}

@MainActor
protocol GoogleSignInAuthorizing {
    func signIn(clientID: String, presentingViewController: UIViewController) async throws -> GoogleSignInPayload
    func handle(_ url: URL) -> Bool
    func signOut()
}

struct GoogleSignInPayload {
    let idToken: String?
    let accessToken: String?
}

@MainActor
protocol AuthenticationPresenterProviding {
    func topViewController() -> UIViewController?
}

@MainActor
public final class FirebaseAuthenticationService: NSObject, AuthenticationService {
    private let firebaseAuth: any FirebaseAuthProviding
    private let appleSignInClient: any AppleSignInAuthorizing
    private let googleSignInClient: any GoogleSignInAuthorizing
    private let presenterProvider: any AuthenticationPresenterProviding
    private let clientIDProvider: () -> String?

    public override convenience init() {
        self.init(
            firebaseAuth: LiveFirebaseAuthClient(),
            appleSignInClient: AppleSignInCoordinator(),
            googleSignInClient: GoogleSignInClient(),
            presenterProvider: KeyWindowAuthenticationPresenterProvider(),
            clientIDProvider: { FirebaseApp.app()?.options.clientID }
        )
    }

    init(
        firebaseAuth: any FirebaseAuthProviding,
        appleSignInClient: any AppleSignInAuthorizing,
        googleSignInClient: any GoogleSignInAuthorizing,
        presenterProvider: any AuthenticationPresenterProviding,
        clientIDProvider: @escaping () -> String?
    ) {
        self.firebaseAuth = firebaseAuth
        self.appleSignInClient = appleSignInClient
        self.googleSignInClient = googleSignInClient
        self.presenterProvider = presenterProvider
        self.clientIDProvider = clientIDProvider
        super.init()
    }

    public func currentSession() -> AuthSession? {
        firebaseAuth.currentSession()
    }

    public func signIn(with provider: AuthenticationProvider) async throws -> AuthSession {
        switch provider {
        case .apple:
            return try await signInWithApple()
        case .google:
            return try await signInWithGoogle()
        }
    }

    public func handleOpenURL(_ url: URL) -> Bool {
        guard Self.isGoogleCallbackURL(url) else { return false }
        return googleSignInClient.handle(url)
    }

    public func signOut() throws {
        googleSignInClient.signOut()
        try firebaseAuth.signOut()
    }

    private func signInWithApple() async throws -> AuthSession {
        let rawNonce = Self.randomNonce()

        do {
            let credential = try await appleSignInClient.authorize(hashedNonce: Self.sha256(rawNonce))
            guard let identityToken = credential.identityToken else {
                throw FirebaseAuthenticationError.missingIdentityToken
            }
            guard let identityTokenString = String(data: identityToken, encoding: .utf8) else {
                throw FirebaseAuthenticationError.invalidIdentityToken
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: identityTokenString,
                rawNonce: rawNonce,
                fullName: credential.fullName
            )
            let authResult = try await firebaseAuth.signIn(with: firebaseCredential)
            try await updateDisplayNameIfNeeded(credential.fullName, applyDisplayName: authResult.updateDisplayName)
            return authResult.session
        } catch {
            throw Self.normalize(error)
        }
    }

    private func signInWithGoogle() async throws -> AuthSession {
        guard let clientID = clientIDProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              clientID.isEmpty == false else {
            throw FirebaseAuthenticationError.missingClientID
        }
        guard let presentingViewController = presenterProvider.topViewController() else {
            throw FirebaseAuthenticationError.missingPresentationContext
        }

        do {
            let payload = try await googleSignInClient.signIn(
                clientID: clientID,
                presentingViewController: presentingViewController
            )
            guard let idToken = payload.idToken, idToken.isEmpty == false else {
                throw FirebaseAuthenticationError.missingIDToken
            }
            guard let accessToken = payload.accessToken, accessToken.isEmpty == false else {
                throw FirebaseAuthenticationError.missingAccessToken
            }

            let firebaseCredential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            return try await firebaseAuth.signIn(with: firebaseCredential).session
        } catch {
            throw Self.normalize(error)
        }
    }

    private func updateDisplayNameIfNeeded(
        _ fullName: PersonNameComponents?,
        applyDisplayName: @MainActor (String) async throws -> Void
    ) async throws {
        guard let fullName else { return }
        let formatter = PersonNameComponentsFormatter()
        let displayName = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
        guard displayName.isEmpty == false else { return }

        try await applyDisplayName(displayName)
    }

    private static func isGoogleCallbackURL(_ url: URL) -> Bool {
        url.scheme?.hasPrefix("com.googleusercontent.apps.") == true
    }

    private static func normalize(_ error: Error) -> Error {
        if let authError = error as? FirebaseAuthenticationError {
            return authError
        }
        if error is CancellationError {
            return FirebaseAuthenticationError.cancelled
        }

        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            return FirebaseAuthenticationError.cancelled
        }
        if nsError.domain == kGIDSignInErrorDomain,
           nsError.code == GIDSignInError.canceled.rawValue {
            return FirebaseAuthenticationError.cancelled
        }

        return error
    }

    private static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randomBytes: [UInt8] = (0..<16).map { _ in UInt8.random(in: 0...255) }
            randomBytes.forEach { byte in
                guard remainingLength > 0 else { return }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
}

@MainActor
private final class LiveFirebaseAuthClient: FirebaseAuthProviding {
    func currentSession() -> AuthSession? {
        guard let user = Auth.auth().currentUser else { return nil }
        return AuthSession(
            userId: user.uid,
            email: user.email,
            displayName: user.displayName,
            photoURL: user.photoURL?.absoluteString
        )
    }

    func signIn(with credential: FirebaseAuthCredential) async throws -> FirebaseAuthenticationResult {
        let authResult = try await Auth.auth().signInAsync(with: credential)
        return FirebaseAuthenticationResult(
            session: AuthSession(
                userId: authResult.user.uid,
                email: authResult.user.email,
                displayName: authResult.user.displayName,
                photoURL: authResult.user.photoURL?.absoluteString
            ),
            updateDisplayName: { displayName in
                guard authResult.user.displayName != displayName else { return }
                let request = authResult.user.createProfileChangeRequest()
                request.displayName = displayName
                try await request.commitChangesAsync()
            }
        )
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
#endif
