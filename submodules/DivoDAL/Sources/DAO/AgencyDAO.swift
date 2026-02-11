import Foundation

/// Data Access Object for Agency endpoints (openapi tag: Agency).
public final class AgencyDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /agency/list
    public func list(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.agencyList, method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /agency/{id}
    public func agency(id: Int) async throws -> Data {
        return try await client.requestRaw(path: APIPath.agency(id: id), method: HTTPMethod.get.rawValue)
    }

    /// POST /agency/update
    public func update(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.agencyUpdate, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /agency/{id}/models/list
    public func modelsList(agencyId: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.agencyModelsList(id: agencyId), method: HTTPMethod.post.rawValue, body: body)
    }

    /// DELETE /agency/{id}/models/{modelId}
    public func removeModel(agencyId: Int, modelId: Int) async throws {
        _ = try await client.requestRaw(path: APIPath.agencyModelsModel(agencyId: agencyId, modelId: modelId), method: HTTPMethod.delete.rawValue)
    }
}
