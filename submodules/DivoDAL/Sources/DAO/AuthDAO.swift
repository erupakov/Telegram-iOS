import Foundation

/// Data Access Object for Auth endpoints (openapi tag: Auth).
public final class AuthDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /auth/login — Email/password login. No auth required.
    public func login(email: String, password: String, deviceId: String, deviceType: String) async throws -> LoginResponse {
        let body = LoginRequest(email: email, password: password, deviceId: deviceId, deviceType: deviceType)
        return try await client.request(path: APIPath.authLogin, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /auth/logout
    public func logout() async throws {
        _ = try await client.requestRaw(path: APIPath.authLogout, method: HTTPMethod.post.rawValue)
    }

    /// POST /auth/registration — Email registration. No auth required.
    public func registration(email: String, password: String, timezone: String, role: String) async throws -> Data {
        let body = RegistrationRequest(email: email, password: password, timezone: timezone, role: role)
        return try await client.requestRaw(path: APIPath.authRegistration, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /auth/registration-social — Social (Firebase) registration. No auth required.
    public func registrationSocial(firebaseToken: String? = nil, deviceId: String? = nil, deviceType: String? = nil) async throws -> Data {
        let body = SocialAuthRequest(firebaseToken: firebaseToken, deviceId: deviceId, deviceType: deviceType)
        return try await client.requestRaw(path: APIPath.authRegistrationSocial, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /auth/login-social — Social (Firebase) login. No auth required.
    public func loginSocial(firebaseToken: String? = nil, deviceId: String? = nil, deviceType: String? = nil) async throws -> LoginResponse {
        let body = SocialAuthRequest(firebaseToken: firebaseToken, deviceId: deviceId, deviceType: deviceType)
        return try await client.request(path: APIPath.authLoginSocial, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /auth/send-email-code — Send email code (confirm_email, forgot_password). No auth required.
    public func sendEmailCode(email: String, type: String) async throws -> Data {
        let body = SendEmailCodeRequest(email: email, type: type)
        return try await client.requestRaw(path: APIPath.authSendEmailCode, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /auth/confirm-email — Confirm email by code. No auth required.
    public func confirmEmail(code: Int, token: String, deviceId: String, deviceType: String) async throws -> LoginResponse {
        let body = ConfirmEmailRequest(code: code, token: token, deviceId: deviceId, deviceType: deviceType)
        return try await client.request(path: APIPath.authConfirmEmail, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /auth/confirm-code — Confirm code. No auth required.
    public func confirmCode(body: [String: Any]? = nil) async throws -> Data {
        return try await client.requestJSON(path: APIPath.authConfirmCode, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /auth/reset-password — Reset password. No auth required.
    public func resetPassword(token: String, code: Int, password: String) async throws {
        let body = ResetPasswordRequest(token: token, code: code, password: password)
        _ = try await client.requestRaw(path: APIPath.authResetPassword, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /auth/find-user — Find user by email. No auth required.
    public func findUser(email: String) async throws -> Data {
        let body = FindUserRequest(email: email)
        return try await client.requestRaw(path: APIPath.authFindUser, method: HTTPMethod.post.rawValue, body: body)
    }
}
