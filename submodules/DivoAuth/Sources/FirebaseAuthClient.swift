import Foundation
import UIKit
import AuthenticationServices
import CryptoKit
import DivoCore
import FirebaseAuth

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
    case invalidResponse(String)
    case missingToken
    case noPresentationAnchor
}

public final class FirebaseAuthClient: NSObject {
    public static let shared = FirebaseAuthClient()

    private var currentSession: ASWebAuthenticationSession?
    private var presentationProvider: GoogleAuthPresentationProvider?
    private var appleSignInDelegate: AppleSignInDelegate?

    private override init() {}

    // MARK: - Google

    @MainActor
    public func signInWithGoogle(presentingFrom anchor: ASPresentationAnchor?) async throws -> DivoFirebaseSignInResult {
        let codeVerifier = Self.generateCodeVerifier()
        let codeChallenge = Self.sha256Base64URL(codeVerifier)
        let state = Self.randomString(32)
        let clientID = DivoFirebaseConfig.clientID
        let redirectURI = "\(DivoFirebaseConfig.reversedClientID):/oauth2redirect/google"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authURL = components.url else {
            throw DivoFirebaseAuthError.invalidResponse("failed to build auth url")
        }

        let callbackURL = try await runWebAuth(
            url: authURL,
            scheme: DivoFirebaseConfig.reversedClientID,
            anchor: anchor
        )

        guard let cb = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let items = cb.queryItems else {
            throw DivoFirebaseAuthError.invalidResponse("no query items")
        }
        guard items.first(where: { $0.name == "state" })?.value == state else {
            throw DivoFirebaseAuthError.invalidResponse("state mismatch")
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            if let err = items.first(where: { $0.name == "error" })?.value {
                throw DivoFirebaseAuthError.invalidResponse("oauth error: \(err)")
            }
            throw DivoFirebaseAuthError.invalidResponse("no code in callback")
        }

        let tokens = try await exchangeGoogleCode(
            code: code,
            codeVerifier: codeVerifier,
            redirectURI: redirectURI,
            clientID: clientID
        )

        let credential = GoogleAuthProvider.credential(
            withIDToken: tokens.idToken,
            accessToken: tokens.accessToken
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        let user = authResult.user

        divoLog(
            "Firebase signIn google ok: uid=\(user.uid) email=\(user.email ?? "nil")",
            level: .info
        )
        return DivoFirebaseSignInResult(
            uid: user.uid,
            providerId: "google.com",
            idToken: tokens.idToken,
            email: user.email,
            displayName: user.displayName
        )
    }

    // MARK: - Apple

    @MainActor
    public func signInWithApple(presentingFrom anchor: ASPresentationAnchor?) async throws -> DivoFirebaseSignInResult {
        let rawNonce = Self.generateAppleNonce(length: 32)
        let hashedNonce = Self.sha256Hex(rawNonce)

        let appleProvider = ASAuthorizationAppleIDProvider()
        let request = appleProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let authorization = try await runAppleAuth(request: request, anchor: anchor)

        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw DivoFirebaseAuthError.invalidResponse("not ASAuthorizationAppleIDCredential")
        }
        guard let idTokenData = appleCredential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8) else {
            throw DivoFirebaseAuthError.missingToken
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: appleCredential.fullName
        )
        let authResult = try await Auth.auth().signIn(with: firebaseCredential)
        let user = authResult.user

        let displayName: String?
        if let fullName = appleCredential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let formatted = formatter.string(from: fullName)
            displayName = formatted.isEmpty ? user.displayName : formatted
        } else {
            displayName = user.displayName
        }

        divoLog(
            "Firebase signIn apple ok: uid=\(user.uid) email=\(appleCredential.email ?? user.email ?? "nil")",
            level: .info
        )
        return DivoFirebaseSignInResult(
            uid: user.uid,
            providerId: "apple.com",
            idToken: idToken,
            email: appleCredential.email ?? user.email,
            displayName: displayName
        )
    }

    @MainActor
    private func runAppleAuth(request: ASAuthorizationAppleIDRequest, anchor: ASPresentationAnchor?) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let resumeOnce: (Result<ASAuthorization, Error>) -> Void = { [weak self] result in
                guard !didResume else { return }
                didResume = true
                self?.appleSignInDelegate = nil
                switch result {
                case .success(let a): continuation.resume(returning: a)
                case .failure(let e): continuation.resume(throwing: e)
                }
            }
            let delegate = AppleSignInDelegate(anchor: anchor, completion: resumeOnce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            self.appleSignInDelegate = delegate
            controller.performRequests()
        }
    }

    public func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Web auth

    @MainActor
    private func runWebAuth(url: URL, scheme: String, anchor: ASPresentationAnchor?) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            // ASWebAuthenticationSession при отсутствии сети может СИНХРОННО вызвать
            // completion handler с error внутри session.start() и потом ещё вернуть false
            // из start(). Без флага мы вызывали бы resume дважды → fatal в checked continuation.
            var didResume = false
            let resumeOnce: (Result<URL, Error>) -> Void = { result in
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success(let url): continuation.resume(returning: url)
                case .failure(let err): continuation.resume(throwing: err)
                }
            }

            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callbackURL, error in
                self?.currentSession = nil
                self?.presentationProvider = nil
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        resumeOnce(.failure(DivoFirebaseAuthError.userCancelled))
                    } else {
                        resumeOnce(.failure(DivoFirebaseAuthError.providerFailed(underlying: error)))
                    }
                    return
                }
                guard let callbackURL = callbackURL else {
                    resumeOnce(.failure(DivoFirebaseAuthError.missingToken))
                    return
                }
                resumeOnce(.success(callbackURL))
            }
            let provider = GoogleAuthPresentationProvider(anchor: anchor)
            session.presentationContextProvider = provider
            session.prefersEphemeralWebBrowserSession = false
            self.presentationProvider = provider
            self.currentSession = session
            if !session.start() {
                self.currentSession = nil
                self.presentationProvider = nil
                resumeOnce(.failure(DivoFirebaseAuthError.providerFailed(
                    underlying: NSError(domain: "DivoFirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "session.start() returned false"])
                )))
            }
        }
    }

    // MARK: - Token exchange

    private struct GoogleTokenResponse: Decodable {
        let idToken: String
        let accessToken: String

        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
            case accessToken = "access_token"
        }
    }

    private func exchangeGoogleCode(
        code: String,
        codeVerifier: String,
        redirectURI: String,
        clientID: String
    ) async throws -> (idToken: String, accessToken: String) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyItems: [(String, String)] = [
            ("code", code),
            ("client_id", clientID),
            ("redirect_uri", redirectURI),
            ("grant_type", "authorization_code"),
            ("code_verifier", codeVerifier),
        ]
        let body = bodyItems.map { pair -> String in
            let value = pair.1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(pair.0)=\(value)"
        }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DivoFirebaseAuthError.invalidResponse("token endpoint: \(body)")
        }
        let tokens = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        return (tokens.idToken, tokens.accessToken)
    }

    // MARK: - PKCE & random

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    private static func sha256Base64URL(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return base64URLEncode(Data(hash))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomString(_ length: Int) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(alphabet.randomElement()!)
        }
        return result
    }

    // MARK: - Apple nonce

    private static func generateAppleNonce(length: Int) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256Hex(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let anchor: ASPresentationAnchor?
    private let completion: (Result<ASAuthorization, Error>) -> Void

    init(anchor: ASPresentationAnchor?, completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.anchor = anchor
        self.completion = completion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            completion(.failure(DivoFirebaseAuthError.userCancelled))
        } else {
            completion(.failure(DivoFirebaseAuthError.providerFailed(underlying: error)))
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let anchor = anchor { return anchor }
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return window
        }
        return ASPresentationAnchor()
    }
}

private final class GoogleAuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor?

    init(anchor: ASPresentationAnchor?) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let anchor = anchor {
            return anchor
        }
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return window
        }
        return ASPresentationAnchor()
    }
}
