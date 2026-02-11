import Foundation

/// Data Access Object for Event endpoints (openapi tag: Event).
public final class EventDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /event/user/applies
    public func userApplies(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.eventUserApplies, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /event/list
    public func list(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.eventList, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /event/create
    public func create(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.eventCreate, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /event/update/{id}
    public func update(id: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.eventUpdate(id: id), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /event/{id}/applies
    public func applies(id: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.eventApplies(id: id), method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /event/{id}
    public func event(id: Int) async throws -> Data {
        return try await client.requestRaw(path: APIPath.event(id: id), method: HTTPMethod.get.rawValue)
    }

    /// DELETE /event/{id} — Cancel event
    public func delete(id: Int) async throws {
        _ = try await client.requestRaw(path: APIPath.event(id: id), method: HTTPMethod.delete.rawValue)
    }

    /// POST /event/types
    public func types(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.eventTypes, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /event/apply
    public func apply(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.eventApply, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /event/{id}/like
    public func like(id: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.eventLike(id: id), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /event/{id}/unlike
    public func unlike(id: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.eventUnlike(id: id), method: HTTPMethod.post.rawValue, body: body)
    }
}
