import Foundation

/// Data Access Object for Agency Employee endpoints (openapi tag: Agency Employee).
public final class AgencyEmployeeDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /agency-employee/roles
    public func roles() async throws -> Data {
        return try await client.requestRaw(path: APIPath.agencyEmployeeRoles, method: HTTPMethod.get.rawValue)
    }
}
