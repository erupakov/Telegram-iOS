import Foundation

/// Data Access Object for Radar endpoints (openapi tag: Radar).
public final class RadarDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /radar/
    public func get() async throws -> Data {
        return try await client.requestRaw(path: APIPath.radar, method: HTTPMethod.get.rawValue)
    }

    /// POST /radar/
    public func set(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.radar, method: HTTPMethod.post.rawValue, body: body)
    }

    /// DELETE /radar/
    public func delete() async throws {
        _ = try await client.requestRaw(path: APIPath.radar, method: HTTPMethod.delete.rawValue)
    }

    /// POST /radar/models
    public func models(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.radarModels, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /radar/places
    public func places(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.radarPlaces, method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /radar/places/{id}
    public func place(id: Int) async throws -> Data {
        return try await client.requestRaw(path: APIPath.radarPlace(id: id), method: HTTPMethod.get.rawValue)
    }

    /// POST /radar/places/{id}/reviews/list
    public func placeReviewsList(placeId: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.radarPlaceReviewsList(id: placeId), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /radar/places/{id}/reviews/add
    public func placeReviewsAdd(placeId: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.radarPlaceReviewsAdd(id: placeId), method: HTTPMethod.post.rawValue, body: body)
    }
}
