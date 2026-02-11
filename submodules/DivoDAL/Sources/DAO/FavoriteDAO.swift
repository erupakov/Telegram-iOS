import Foundation

/// Data Access Object for Favorite endpoints (openapi tag: Favorite).
public final class FavoriteDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /favorite/mark
    public func mark(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.favoriteMark, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /favorite/unmark
    public func unmark(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.favoriteUnmark, method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /favorite/list
    public func list() async throws -> Data {
        return try await client.requestRaw(path: APIPath.favoriteList, method: HTTPMethod.get.rawValue)
    }
}
