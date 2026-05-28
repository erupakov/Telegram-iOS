import Foundation
import DivoCore

public struct DivoFirebaseSignInResult {
    public let uid: String
    public let providerId: String
    public let idToken: String?
    public let email: String?
    public let displayName: String?

    public init(uid: String, providerId: String, idToken: String? = nil, email: String? = nil, displayName: String? = nil) {
        self.uid = uid
        self.providerId = providerId
        self.idToken = idToken
        self.email = email
        self.displayName = displayName
    }
}

public enum DivoFirebaseAuthError: Error {
    case userCancelled
    case providerFailed(underlying: Error)
    case notConfigured
}

public final class FirebaseAuthClient {
    public static let shared = FirebaseAuthClient()

    private init() {}

    public func signInWithGoogle() async throws -> DivoFirebaseSignInResult {
        // Шаг 3: OAuthProvider(providerID: "google.com").credential → Auth.auth().signIn(with:)
        throw DivoFirebaseAuthError.notConfigured
    }

    public func signInWithApple() async throws -> DivoFirebaseSignInResult {
        // Шаг 4: ASAuthorizationController + OAuthProvider(providerID: "apple.com")
        throw DivoFirebaseAuthError.notConfigured
    }

    public func signOut() throws {
        // Шаг 3: try Auth.auth().signOut()
    }
}
