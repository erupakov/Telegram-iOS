import Foundation

/// Data Access Object for NFT endpoints (openapi tag: NFT).
public final class NFTDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /nft/create
    public func create(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.nftCreate, method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /nft/{id}
    public func nft(id: Int) async throws -> Data {
        return try await client.requestRaw(path: APIPath.nft(id: id), method: HTTPMethod.get.rawValue)
    }

    /// DELETE /nft/{id}
    public func delete(id: Int) async throws {
        _ = try await client.requestRaw(path: APIPath.nft(id: id), method: HTTPMethod.delete.rawValue)
    }

    /// POST /nft/update/{id}
    public func update(id: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.nftUpdate(id: id), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /nft/list
    public func list(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.nftList, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /nft/buy/{id}
    public func buy(id: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.nftBuy(id: id), method: HTTPMethod.post.rawValue, body: body)
    }
}
