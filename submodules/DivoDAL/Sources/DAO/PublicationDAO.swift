import Foundation

/// Data Access Object for Publication endpoints (openapi tag: Publication).
public final class PublicationDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /publication/list
    public func list(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.publicationList, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /publication/feed
    public func feed(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.publicationFeed, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /publication/create
    public func create(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.publicationCreate, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /publication/like
    public func like(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.publicationLike, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /publication/unlike
    public func unlike(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.publicationUnlike, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /publication/{id} — Edit publication
    public func update(id: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.publication(id: id), method: HTTPMethod.post.rawValue, body: body)
    }

    /// DELETE /publication/{id}
    public func delete(id: Int) async throws {
        _ = try await client.requestRaw(path: APIPath.publication(id: id), method: HTTPMethod.delete.rawValue)
    }
}
