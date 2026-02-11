import Foundation

/// Data Access Object for Feedline endpoints (openapi tag: Feedline).
public final class FeedlineDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /feedline/list
    public func list(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.feedlineList, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /feedline/like
    public func like(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.feedlineLike, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /feedline/unlike
    public func unlike(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.feedlineUnlike, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /feedline/user-activity
    public func userActivity(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.feedlineUserActivity, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /feedline/search
    public func search(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.feedlineSearch, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /feedline/report
    public func report(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.feedlineReport, method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /feedline/{id}
    public func feedline(id: Int) async throws -> Data {
        return try await client.requestRaw(path: APIPath.feedline(id: id), method: HTTPMethod.get.rawValue)
    }
}
