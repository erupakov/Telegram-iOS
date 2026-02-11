import Foundation

/// Data Access Object for Customer endpoints (openapi tag: Customer).
public final class CustomerDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /customer/roles
    public func roles() async throws -> Data {
        return try await client.requestRaw(path: APIPath.customerRoles, method: HTTPMethod.get.rawValue)
    }
}
