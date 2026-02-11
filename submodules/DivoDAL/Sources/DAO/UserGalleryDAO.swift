import Foundation

/// Data Access Object for User Gallery endpoints (openapi tag: User Gallery).
public final class UserGalleryDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /user-gallery/add — multipart
    public func add(multipart: MultipartForm) async throws -> Data {
        return try await client.upload(path: APIPath.userGalleryAdd, method: HTTPMethod.post.rawValue, multipart: multipart)
    }

    /// POST /user-gallery/list
    public func list(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userGalleryList, method: HTTPMethod.post.rawValue, body: body)
    }

    /// DELETE /user-gallery/{id}
    public func delete(id: Int) async throws {
        _ = try await client.requestRaw(path: APIPath.userGallery(id: id), method: HTTPMethod.delete.rawValue)
    }

    /// POST /user-gallery/like
    public func like(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userGalleryLike, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /user-gallery/unlike
    public func unlike(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userGalleryUnlike, method: HTTPMethod.post.rawValue, body: body)
    }
}
