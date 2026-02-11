import Foundation

/// Data Access Object for Dictionary endpoints (openapi tag: Dictionary).
public final class DictionaryDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /dictionary/gender
    public func gender() async throws -> Data {
        return try await client.requestRaw(path: APIPath.dictionaryGender, method: HTTPMethod.get.rawValue)
    }

    /// GET /dictionary/appearances
    public func appearances() async throws -> Data {
        return try await client.requestRaw(path: APIPath.dictionaryAppearances, method: HTTPMethod.get.rawValue)
    }

    /// GET /dictionary/payments
    public func payments() async throws -> Data {
        return try await client.requestRaw(path: APIPath.dictionaryPayments, method: HTTPMethod.get.rawValue)
    }

    /// GET /dictionary/feed-report-types
    public func feedReportTypes() async throws -> Data {
        return try await client.requestRaw(path: APIPath.dictionaryFeedReportTypes, method: HTTPMethod.get.rawValue)
    }
}
