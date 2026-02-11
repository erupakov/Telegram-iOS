import Foundation

/// Data Access Object for Geo endpoints (openapi tag: Geo).
public final class GeoDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// GET /geo/search-by-address-name. No auth required.
    public func searchByAddressName(q: String?) async throws -> Data {
        let query = q.map { ["q": $0] }
        return try await client.requestRaw(path: APIPath.geoSearchByAddressName, method: HTTPMethod.get.rawValue, query: query)
    }

    /// GET /geo/search-geocoder. No auth required.
    public func searchGeocoder(q: String?) async throws -> Data {
        let query = q.map { ["q": $0] }
        return try await client.requestRaw(path: APIPath.geoSearchGeocoder, method: HTTPMethod.get.rawValue, query: query)
    }
}
