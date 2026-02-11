import Foundation

/// Data Access Object for User Paid Services endpoints (openapi tag: User Paid Services).
public final class UserPaidServicesDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /user-paid-services/
    public func list() async throws -> Data {
        return try await client.requestRaw(path: APIPath.userPaidServicesList, method: HTTPMethod.get.rawValue)
    }

    /// POST /user-paid-services/check-balance
    public func checkBalance(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userPaidServicesCheckBalance, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /user-paid-services/buy
    public func buy(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.userPaidServicesBuy, method: HTTPMethod.post.rawValue, body: body)
    }
}
