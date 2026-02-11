import Foundation

/// Data Access Object for Wallet endpoints (openapi tag: Wallet).
public final class WalletDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /wallet/list
    public func list(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.walletList, method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /wallet/withdrawal-networks
    public func withdrawalNetworks() async throws -> Data {
        return try await client.requestRaw(path: APIPath.walletWithdrawalNetworks, method: HTTPMethod.get.rawValue)
    }

    /// POST /wallet/bonus
    public func bonus(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.walletBonus, method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /wallet/{walletId}
    public func wallet(walletId: Int) async throws -> Data {
        return try await client.requestRaw(path: APIPath.wallet(id: walletId), method: HTTPMethod.get.rawValue)
    }

    /// POST /wallet/{walletId}/operations
    public func operations(walletId: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.walletOperations(walletId: walletId), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /wallet/{walletId}/withdraw
    public func withdraw(walletId: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.walletWithdraw(walletId: walletId), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /wallet/{walletId}/send
    public func send(walletId: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.walletSend(walletId: walletId), method: HTTPMethod.post.rawValue, body: body)
    }
}
