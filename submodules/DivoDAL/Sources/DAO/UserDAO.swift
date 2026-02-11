import Foundation

/// Data Access Object for User endpoints (openapi tag: User).
public final class UserDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /user/info — Current user info
    public func info() async throws -> UserInfo {
        return try await client.request(path: APIPath.userInfo, method: HTTPMethod.get.rawValue)
    }

    /// GET /user/rating
    public func rating() async throws -> Data {
        return try await client.requestRaw(path: APIPath.userRating, method: HTTPMethod.get.rawValue)
    }

    /// GET /user/available-rating-features
    public func availableRatingFeatures() async throws -> Data {
        return try await client.requestRaw(path: APIPath.userAvailableRatingFeatures, method: HTTPMethod.get.rawValue)
    }

    /// GET /user/viewers
    public func viewers() async throws -> Data {
        return try await client.requestRaw(path: APIPath.userViewers, method: HTTPMethod.get.rawValue)
    }

    /// GET /user/budge-count
    public func budgeCount() async throws -> Data {
        return try await client.requestRaw(path: APIPath.userBudgeCount, method: HTTPMethod.get.rawValue)
    }

    /// GET /user/{id}
    public func user(id: Int) async throws -> UserInfo {
        return try await client.request(path: APIPath.user(id: id), method: HTTPMethod.get.rawValue)
    }

    /// POST /user/update-profile
    public func updateProfile(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userUpdateProfile, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /user/update-password
    public func updatePassword(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userUpdatePassword, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /user/update-email
    public func updateEmail(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userUpdateEmail, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /user/update-email-confirm
    public func updateEmailConfirm(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userUpdateEmailConfirm, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /user/list-with-wallets
    public func listWithWallets(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userListWithWallets, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /user/save-push-token
    public func savePushToken(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userSavePushToken, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /user/send-test-push
    public func sendTestPush(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userSendTestPush, method: HTTPMethod.post.rawValue, body: body)
    }

    /// DELETE /user/delete-account
    public func deleteAccount() async throws {
        _ = try await client.requestRaw(path: APIPath.userDeleteAccount, method: HTTPMethod.delete.rawValue)
    }

    /// POST /user/change-role
    public func changeRole(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userChangeRole, method: HTTPMethod.post.rawValue, body: body)
    }
}
