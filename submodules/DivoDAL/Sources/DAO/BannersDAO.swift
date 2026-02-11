import Foundation

/// Data Access Object for Banners endpoints (openapi tag: Banners).
public final class BannersDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /banners/
    public func get() async throws -> Data {
        return try await client.requestRaw(path: APIPath.banners, method: HTTPMethod.get.rawValue)
    }

    /// GET /banners/list
    public func list() async throws -> Data {
        return try await client.requestRaw(path: APIPath.bannersList, method: HTTPMethod.get.rawValue)
    }

    /// POST /banners/{id}/close
    public func close(id: Int) async throws -> Data {
        return try await client.requestRaw(path: APIPath.bannersClose(id: id), method: HTTPMethod.post.rawValue)
    }
}
