import Foundation
import UIKit

private var divoDeviceId: String {
    UIDevice.current.identifierForVendor?.uuidString ?? "ios-unknown"
}

public enum DivoAuthProviderID: String, Codable {
    case google = "google.com"
    case apple = "apple.com"
}

public enum DivoUserRole: String, Codable {
    case model
    case newFace = "new_face"
    case fan
    case agencyEmployee = "agency_employee"
    case customer
}

public struct AuthLoginSocialRequest: Encodable {
    public let uid: String
    public let providerId: String
    public let deviceType: String
    public let deviceId: String?

    public init(uid: String, providerId: String, deviceType: String = "ios", deviceId: String? = nil) {
        self.uid = uid
        self.providerId = providerId
        self.deviceType = deviceType
        self.deviceId = deviceId
    }
}

public struct AuthLoginRequest: Encodable {
    public let email: String
    public let password: String
    public let deviceType: String
    public let deviceId: String?

    public init(email: String, password: String, deviceType: String = "ios", deviceId: String? = nil) {
        self.email = email
        self.password = password
        self.deviceType = deviceType
        self.deviceId = deviceId
    }
}

public struct AuthTokenUserData: Decodable {
    public let id: Int
    public let telegramLinked: Bool?
}

public struct AuthTokenWithUserData: Decodable {
    public let type: String?
    public let accessToken: String
    public let user: AuthTokenUserData
    public let telegramLinked: Bool?
}

/// DIVO REST оборачивает ответы в { message, data, errors }. Распаковываем только data.
public struct DivoEnvelope<T: Decodable>: Decodable {
    public let data: T
}

public struct AuthRegistrationSocialRequest: Encodable {
    public let email: String?
    public let password: String?
    public let role: String
    public let subrole: String?
    public let providerId: String
    public let uid: String
    public let timezone: String?
    public let deviceId: String?
    public let deviceType: String
    public let additionalInfo: [String: String]?

    public init(
        uid: String,
        providerId: String,
        role: String,
        deviceType: String = "ios",
        email: String? = nil,
        password: String? = nil,
        subrole: String? = nil,
        timezone: String? = nil,
        deviceId: String? = nil,
        additionalInfo: [String: String]? = nil
    ) {
        self.uid = uid
        self.providerId = providerId
        self.role = role
        self.deviceType = deviceType
        self.email = email
        self.password = password
        self.subrole = subrole
        self.timezone = timezone
        self.deviceId = deviceId
        self.additionalInfo = additionalInfo
    }
}

public struct AuthRegistrationRequest: Encodable {
    public let email: String?
    public let password: String?
    public let role: String
    public let subrole: String?
    public let timezone: String?
    public let deviceId: String?
    public let deviceType: String
    public let additionalInfo: [String: String]?

    public init(
        role: String,
        deviceType: String = "ios",
        email: String? = nil,
        password: String? = nil,
        subrole: String? = nil,
        timezone: String? = nil,
        deviceId: String? = nil,
        additionalInfo: [String: String]? = nil
    ) {
        self.role = role
        self.deviceType = deviceType
        self.email = email
        self.password = password
        self.subrole = subrole
        self.timezone = timezone
        self.deviceId = deviceId
        self.additionalInfo = additionalInfo
    }
}

public struct AuthTelegramLinkRequest: Encodable {
    public let divoUserId: Int?
    public let telegramUserId: Int64
    public let phone: String?
    public let deviceId: String?
    public let deviceType: String?

    public init(
        telegramUserId: Int64,
        divoUserId: Int? = nil,
        phone: String? = nil,
        deviceId: String? = nil,
        deviceType: String? = "ios"
    ) {
        self.telegramUserId = telegramUserId
        self.divoUserId = divoUserId
        self.phone = phone
        self.deviceId = deviceId
        self.deviceType = deviceType
    }
}

public struct DivoUserInfoData: Decodable {
    public let id: Int
    public let fullName: String?
    public let phone: String?
    public let role: String?
    public let subrole: String?
    public let isRegistrationFinished: Bool?
}

public struct DivoUserInfoSuccess: Decodable {
    public let status: String
    public let data: DivoUserInfoData
}

public final class AuthRestService {
    public static let shared = AuthRestService()

    private let client = DivoAPIClient.shared

    private init() {}

    public func loginSocial(uid: String, providerId: String) async throws -> AuthTokenWithUserData {
        let req = AuthLoginSocialRequest(uid: uid, providerId: providerId, deviceId: divoDeviceId)
        let env: DivoEnvelope<AuthTokenWithUserData> = try await client.request(path: "/auth/login-social", method: "POST", body: req)
        return env.data
    }

    /// Email/password логин. Для phone-флоу: email=<цифры phone>@divo.global + детерминированный пароль.
    public func login(email: String, password: String) async throws -> AuthTokenWithUserData {
        let req = AuthLoginRequest(email: email, password: password, deviceId: divoDeviceId)
        let env: DivoEnvelope<AuthTokenWithUserData> = try await client.request(path: "/auth/login", method: "POST", body: req)
        return env.data
    }

    public func registerSocial(
        uid: String,
        providerId: String,
        role: String,
        additionalInfo: [String: String]? = nil
    ) async throws -> AuthTokenWithUserData {
        let req = AuthRegistrationSocialRequest(
            uid: uid,
            providerId: providerId,
            role: role,
            deviceId: divoDeviceId,
            additionalInfo: additionalInfo
        )
        let env: DivoEnvelope<AuthTokenWithUserData> = try await client.request(path: "/auth/registration-social", method: "POST", body: req)
        return env.data
    }

    public func register(
        role: String,
        email: String? = nil,
        password: String? = nil,
        additionalInfo: [String: String]? = nil
    ) async throws -> AuthTokenWithUserData {
        let req = AuthRegistrationRequest(role: role, email: email, password: password, deviceId: divoDeviceId, additionalInfo: additionalInfo)
        let env: DivoEnvelope<AuthTokenWithUserData> = try await client.request(path: "/auth/registration", method: "POST", body: req)
        return env.data
    }

    public func telegramLink(
        telegramUserId: Int64,
        phone: String? = nil,
        divoUserId: Int? = nil
    ) async throws -> AuthTokenWithUserData {
        let req = AuthTelegramLinkRequest(telegramUserId: telegramUserId, divoUserId: divoUserId, phone: phone, deviceId: divoDeviceId)
        let env: DivoEnvelope<AuthTokenWithUserData> = try await client.request(path: "/auth/telegram-link", method: "POST", body: req)
        return env.data
    }

    public func userInfo() async throws -> DivoUserInfoData {
        let env: DivoEnvelope<DivoUserInfoData> = try await client.request(path: "/user/info")
        return env.data
    }
}
