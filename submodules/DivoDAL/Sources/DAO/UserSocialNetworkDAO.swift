import Foundation

/// Data Access Object for User Social Network endpoints (openapi tag: User Social Network).
public final class UserSocialNetworkDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /user-social-network/
    public func list() async throws -> Data {
        return try await client.requestRaw(path: APIPath.userSocialNetworkList, method: HTTPMethod.get.rawValue)
    }

    /// POST /user-social-network/upsert
    public func upsert(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userSocialNetworkUpsert, method: HTTPMethod.post.rawValue, body: body)
    }

    /// DELETE /user-social-network/{id}
    public func delete(id: Int) async throws {
        _ = try await client.requestRaw(path: APIPath.userSocialNetwork(id: id), method: HTTPMethod.delete.rawValue)
    }
}
