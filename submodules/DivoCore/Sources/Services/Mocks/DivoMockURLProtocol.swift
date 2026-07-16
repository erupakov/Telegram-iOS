import Foundation

public final class DivoMockURLProtocol: URLProtocol {

    override public class func canInit(with request: URLRequest) -> Bool {
        guard DivoConfig.isMockEnabled else { return false }
        guard let host = request.url?.host else { return false }
        return host.contains("divo.fashion")
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override public func startLoading() {
        guard let url = request.url,
              let client = self.client else { return }

        let path = url.path
        let (offset, limit) = Self.parseOffsetLimit(from: request)

        let data = Self.mockResponse(for: path, offset: offset, limit: limit)

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: data)
        client.urlProtocolDidFinishLoading(self)
    }

    override public func stopLoading() {}

    // MARK: - Routing

    private static func mockResponse(for path: String, offset: Int, limit: Int) -> Data {
        // Exact matches
        switch path {
        case _ where path.hasSuffix("/feedline/search"):
            return DivoMockData.feedlineSearch(offset: offset, limit: limit)
        case _ where path.hasSuffix("/feedline/list"):
            return DivoMockData.feedlineList(offset: offset, limit: limit)
        case _ where path.hasSuffix("/dictionary/gender"):
            return DivoMockData.dictionaryGender
        case _ where path.hasSuffix("/dictionary/appearances"):
            return DivoMockData.dictionaryAppearances
        case _ where path.hasSuffix("/user/info"):
            return DivoMockData.userDetail(id: 1, useCurrentRole: true)
        case _ where path.hasSuffix("/user/engagement"):
            return DivoMockData.userEngagement
        case _ where path.hasSuffix("/user-gallery/list"):
            return DivoMockData.galleryList(offset: offset, limit: limit)
        case _ where path.hasSuffix("/publication/list"):
            return DivoMockData.emptyPaginatedList
        case _ where path.hasSuffix("/event/list"):
            return DivoMockData.emptyEventList
        case _ where path.hasSuffix("/event/types"):
            return DivoMockData.eventTypes
        case _ where path.hasSuffix("/agency/list"):
            return DivoMockData.agencyList
        case _ where path.hasSuffix("/model-work-history"):
            return DivoMockData.emptyWorkHistory
        case _ where path.hasSuffix("/fr/detect"):
            return DivoMockData.frDetect
        case _ where path.hasSuffix("/fr/search"):
            return DivoMockData.frSearchEmpty
        default:
            break
        }

        // Pattern matches: /user/{id} — чужой профиль, всегда модель
        if path.range(of: #"/user/\d+$"#, options: .regularExpression) != nil {
            let userId = Int(path.split(separator: "/").last ?? "1") ?? 1
            return DivoMockData.userDetail(id: userId, useCurrentRole: false)
        }

        // Pattern matches: /agency/{id}/models/list
        if path.contains("/models/list") {
            return DivoMockData.agencyModelsList
        }

        // Pattern matches: /event/{id}
        if path.range(of: #"/event/\d+$"#, options: .regularExpression) != nil {
            return DivoMockData.eventDetail
        }

        // Action endpoints — generic success
        let actionSuffixes = [
            "/user/like", "/user/unlike",
            "/feedline/like", "/feedline/unlike",
            "/follower/follow", "/follower/unfollow",
            "/file/upload-file",
            "/user-gallery/add", "/publication/create",
            "/user/update-profile", "/agency/update",
            "/user/update-social-links"
        ]
        if actionSuffixes.contains(where: { path.hasSuffix($0) }) {
            return DivoMockData.genericSuccess
        }

        // Fallback
        return DivoMockData.genericSuccess
    }

    // MARK: - Helpers

    private static func parseOffsetLimit(from request: URLRequest) -> (offset: Int, limit: Int) {
        // Try request body (POST)
        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            let offset = json["offset"] as? Int ?? 0
            let limit = json["limit"] as? Int ?? 20
            return (offset, limit)
        }
        // Try query parameters (GET)
        if let url = request.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = components.queryItems {
            let offset = items.first(where: { $0.name == "offset" }).flatMap { Int($0.value ?? "") } ?? 0
            let limit = items.first(where: { $0.name == "limit" }).flatMap { Int($0.value ?? "") } ?? 20
            return (offset, limit)
        }
        return (0, 20)
    }
}
