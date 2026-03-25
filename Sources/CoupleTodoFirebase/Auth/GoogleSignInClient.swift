#if os(iOS)
import Foundation
@preconcurrency import GoogleSignIn
import UIKit

@MainActor
final class GoogleSignInClient: GoogleSignInAuthorizing {
    func signIn(clientID: String, presentingViewController: UIViewController) async throws -> GoogleSignInPayload {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        return GoogleSignInPayload(
            idToken: result.user.idToken?.tokenString,
            accessToken: result.user.accessToken.tokenString
        )
    }

    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}
#endif
