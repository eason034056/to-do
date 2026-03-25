#if os(iOS)
import UIKit
import XCTest
@testable import CoupleTodoFirebase

@MainActor
final class FirebaseAuthenticationServiceTests: XCTestCase {
    func testSignInWithGoogleThrowsMissingClientIDWhenFirebaseClientIDUnavailable() async {
        let service = FirebaseAuthenticationService(
            firebaseAuth: StubFirebaseAuthClient(),
            appleSignInClient: StubAppleSignInClient(),
            googleSignInClient: StubGoogleSignInClient(),
            presenterProvider: StubPresenterProvider(),
            clientIDProvider: { nil }
        )

        do {
            _ = try await service.signIn(with: .google)
            XCTFail("Expected missingClientID error")
        } catch let error as FirebaseAuthenticationError {
            XCTAssertEqual(error, .missingClientID)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSignInWithGoogleThrowsMissingIDTokenWhenGoogleSDKReturnsNoIDToken() async {
        let service = FirebaseAuthenticationService(
            firebaseAuth: StubFirebaseAuthClient(),
            appleSignInClient: StubAppleSignInClient(),
            googleSignInClient: StubGoogleSignInClient(
                signInResult: GoogleSignInPayload(idToken: nil, accessToken: "token")
            ),
            presenterProvider: StubPresenterProvider(),
            clientIDProvider: { "client-id" }
        )

        do {
            _ = try await service.signIn(with: .google)
            XCTFail("Expected missingIDToken error")
        } catch let error as FirebaseAuthenticationError {
            XCTAssertEqual(error, .missingIDToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSignInWithGoogleThrowsMissingAccessTokenWhenGoogleSDKReturnsNoAccessToken() async {
        let service = FirebaseAuthenticationService(
            firebaseAuth: StubFirebaseAuthClient(),
            appleSignInClient: StubAppleSignInClient(),
            googleSignInClient: StubGoogleSignInClient(
                signInResult: GoogleSignInPayload(idToken: "id-token", accessToken: nil)
            ),
            presenterProvider: StubPresenterProvider(),
            clientIDProvider: { "client-id" }
        )

        do {
            _ = try await service.signIn(with: .google)
            XCTFail("Expected missingAccessToken error")
        } catch let error as FirebaseAuthenticationError {
            XCTAssertEqual(error, .missingAccessToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHandleOpenURLReturnsInjectedGoogleSignInHandlerResult() {
        let googleSignInClient = StubGoogleSignInClient(handleURLResult: true)
        let service = FirebaseAuthenticationService(
            firebaseAuth: StubFirebaseAuthClient(),
            appleSignInClient: StubAppleSignInClient(),
            googleSignInClient: googleSignInClient,
            presenterProvider: StubPresenterProvider(),
            clientIDProvider: { "client-id" }
        )
        let url = URL(string: "com.googleusercontent.apps.123:/oauth")!

        XCTAssertTrue(service.handleOpenURL(url))
        XCTAssertEqual(googleSignInClient.handledURLs, [url])
    }
}

@MainActor
private struct StubPresenterProvider: AuthenticationPresenterProviding {
    var viewController = UIViewController()

    func topViewController() -> UIViewController? {
        viewController
    }
}

@MainActor
private final class StubFirebaseAuthClient: FirebaseAuthProviding {
    var currentSessionValue: AuthSession?

    func currentSession() -> AuthSession? {
        currentSessionValue
    }

    func signIn(with credential: FirebaseAuthCredential) async throws -> FirebaseAuthenticationResult {
        FirebaseAuthenticationResult(
            session: AuthSession(userId: "usr_google", email: "test@example.com", displayName: "Test User"),
            updateDisplayName: { _ in }
        )
    }

    func signOut() throws {}
}

@MainActor
private struct StubAppleSignInClient: AppleSignInAuthorizing {
    func authorize(hashedNonce: String) async throws -> AppleSignInPayload {
        AppleSignInPayload(identityToken: Data(), fullName: nil)
    }
}

@MainActor
private final class StubGoogleSignInClient: GoogleSignInAuthorizing {
    let signInResult: GoogleSignInPayload
    let handleURLResult: Bool
    private(set) var handledURLs: [URL] = []

    init(
        signInResult: GoogleSignInPayload = GoogleSignInPayload(idToken: "id-token", accessToken: "access-token"),
        handleURLResult: Bool = false
    ) {
        self.signInResult = signInResult
        self.handleURLResult = handleURLResult
    }

    func signIn(clientID: String, presentingViewController: UIViewController) async throws -> GoogleSignInPayload {
        signInResult
    }

    func handle(_ url: URL) -> Bool {
        handledURLs.append(url)
        return handleURLResult
    }

    func signOut() {}
}
#endif
