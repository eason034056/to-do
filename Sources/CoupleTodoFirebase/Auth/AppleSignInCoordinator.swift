#if os(iOS)
import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class AppleSignInCoordinator: NSObject, AppleSignInAuthorizing {
    private var continuation: CheckedContinuation<AppleSignInPayload, Error>?

    func authorize(hashedNonce: String) async throws -> AppleSignInPayload {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: FirebaseAuthenticationError.unsupportedCredential)
            continuation = nil
            return
        }
        continuation?.resume(
            returning: AppleSignInPayload(
                identityToken: credential.identityToken,
                fullName: credential.fullName
            )
        )
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        return window ?? ASPresentationAnchor()
    }
}
#endif
