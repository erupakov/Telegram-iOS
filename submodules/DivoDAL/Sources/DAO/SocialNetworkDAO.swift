import Foundation

/// Data Access Object for Social Network endpoints (openapi tag: Social Network).
public final class SocialNetworkDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /social-network/
    public func list() async throws -> Data {
        return try await client.requestRaw(path: APIPath.socialNetworkList, method: HTTPMethod.get.rawValue)
    }

    /// GET /social-network/instagram/import
    public func instagramImport() async throws -> Data {
        return try await client.requestRaw(path: APIPath.socialNetworkInstagramImport, method: HTTPMethod.get.rawValue)
    }

    /// POST /social-network/instagram/add
    public func instagramAdd(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.socialNetworkInstagramAdd, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /social-network/instagram/{id}/update
    public func instagramUpdate(id: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.socialNetworkInstagramUpdate(id: id), method: HTTPMethod.post.rawValue, body: body)
    }

    /// DELETE /social-network/instagram/{id}/delete
    public func instagramDelete(id: Int) async throws {
        _ = try await client.requestRaw(path: APIPath.socialNetworkInstagramDelete(id: id), method: HTTPMethod.delete.rawValue)
    }
}
