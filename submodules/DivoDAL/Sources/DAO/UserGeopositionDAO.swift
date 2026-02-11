import Foundation

/// Data Access Object for User Geoposition endpoints (openapi tag: User Geoposition).
public final class UserGeopositionDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /user-geoposition/add
    public func add(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userGeopositionAdd, method: HTTPMethod.post.rawValue, body: body)
    }
}
