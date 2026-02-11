import Foundation

/// Request body for POST /auth/login.
public struct LoginRequest: Encodable {
    public let email: String
    public let password: String
    public let deviceId: String
    public let deviceType: String

    public init(email: String, password: String, deviceId: String, deviceType: String) {
        self.email = email
        self.password = password
        self.deviceId = deviceId
        self.deviceType = deviceType
    }
}

/// Response for successful login (returns accessToken).
public struct LoginResponse: Codable {
    public let accessToken: String

    public init(accessToken: String) {
        self.accessToken = accessToken
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "accessToken"
    }
}

/// Request body for POST /auth/registration.
public struct RegistrationRequest: Encodable {
    public let email: String
    public let password: String
    public let timezone: String
    public let role: String

    public init(email: String, password: String, timezone: String, role: String) {
        self.email = email
        self.password = password
        self.timezone = timezone
        self.role = role
    }
}

/// Request body for POST /auth/registration-social and /auth/login-social.
public struct SocialAuthRequest: Encodable {
    public let firebaseToken: String?
    public let deviceId: String?
    public let deviceType: String?

    public init(firebaseToken: String? = nil, deviceId: String? = nil, deviceType: String? = nil) {
        self.firebaseToken = firebaseToken
        self.deviceId = deviceId
        self.deviceType = deviceType
    }
}

/// Request body for POST /auth/send-email-code.
public struct SendEmailCodeRequest: Encodable {
    public let email: String
    public let type: String

    public init(email: String, type: String) {
        self.email = email
        self.type = type
    }
}

/// Request body for POST /auth/confirm-email.
public struct ConfirmEmailRequest: Encodable {
    public let code: Int
    public let token: String
    public let deviceId: String
    public let deviceType: String

    public init(code: Int, token: String, deviceId: String, deviceType: String) {
        self.code = code
        self.token = token
        self.deviceId = deviceId
        self.deviceType = deviceType
    }
}

/// Request body for POST /auth/reset-password.
public struct ResetPasswordRequest: Encodable {
    public let token: String
    public let code: Int
    public let password: String

    public init(token: String, code: Int, password: String) {
        self.token = token
        self.code = code
        self.password = password
    }
}

/// Request body for POST /auth/find-user.
public struct FindUserRequest: Encodable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}
