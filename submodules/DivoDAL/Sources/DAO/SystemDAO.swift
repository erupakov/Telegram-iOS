import Foundation

/// Data Access Object for System endpoints (openapi tag: System).
public final class SystemDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /system/feature-flags
    public func featureFlags() async throws -> Data {
        return try await client.requestRaw(path: APIPath.systemFeatureFlags, method: HTTPMethod.get.rawValue)
    }
}
