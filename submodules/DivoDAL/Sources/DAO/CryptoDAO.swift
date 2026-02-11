import Foundation

/// Data Access Object for Crypto webhook endpoints (openapi tag: Crypto). No auth required.
public final class CryptoDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /crypto/webhook
    public func webhookGet() async throws -> Data {
        return try await client.requestRaw(path: APIPath.cryptoWebhook, method: HTTPMethod.get.rawValue)
    }

    /// POST /crypto/webhook
    public func webhookPost(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.cryptoWebhook, method: HTTPMethod.post.rawValue, body: body)
    }

    /// PUT /crypto/webhook
    public func webhookPut(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.cryptoWebhook, method: HTTPMethod.put.rawValue, body: body)
    }

    /// PATCH /crypto/webhook
    public func webhookPatch(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.cryptoWebhook, method: HTTPMethod.patch.rawValue, body: body)
    }

    /// DELETE /crypto/webhook
    public func webhookDelete() async throws -> Data {
        return try await client.requestRaw(path: APIPath.cryptoWebhook, method: HTTPMethod.delete.rawValue)
    }
}
