import Foundation

/// HTTP client for the Divo REST API. Handles base URL, Bearer auth, JSON/multipart, and error mapping.
public final class APIClient {
    public static let defaultBaseURL = URL(string: "https://backend.divo.fashion")!
    private static let apiPathPrefix = "/api"

    private let baseURL: URL
    private let session: URLSession
    private let authToken: () -> String?

    public init(
        baseURL: URL = APIClient.defaultBaseURL,
        session: URLSession = .shared,
        authToken: @escaping () -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authToken = authToken
    }

    /// Builds the full API URL for a path (e.g. "/auth/login" -> baseURL + "/api" + path).
    private func url(path: String, queryItems: [URLQueryItem]? = nil) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let pathSuffix = path.hasPrefix("/") ? path : "/" + path
        components.path = APIClient.apiPathPrefix + pathSuffix
        components.queryItems = queryItems
        return components.url!
    }

    /// Performs a JSON request. Body is encoded as application/json; response is decoded to Decodable.
    public func request<T: Decodable>(
        path: String,
        method: String = "GET",
        query: [String: String]? = nil,
        body: (some Encodable)? = nil,
        tokenOverride: String? = nil
    ) async throws -> T {
        let data = try await requestRaw(path: path, method: method, query: query, body: body, tokenOverride: tokenOverride)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw DivoAPIError.decoding(error)
        }
    }

    /// Performs a request and returns raw Data. Use for empty or non-JSON responses.
    public func requestRaw(
        path: String,
        method: String = "GET",
        query: [String: String]? = nil,
        body: (some Encodable)? = nil,
        tokenOverride: String? = nil
    ) async throws -> Data {
        let queryItems = query?.map { URLQueryItem(name: $0.key, value: $0.value) }
        let requestURL = url(path: path, queryItems: queryItems?.isEmpty == false ? queryItems : nil)
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let token = tokenOverride ?? authToken()
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DivoAPIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DivoAPIError.serverError(statusCode: 0)
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw DivoAPIError.unauthorized
        case 403:
            throw DivoAPIError.forbidden
        case 422:
            let payload = DivoAPIErrorPayload.parse(from: data)
            throw DivoAPIError.validation(message: payload?.message, errors: payload?.errors)
        default:
            throw DivoAPIError.serverError(statusCode: http.statusCode)
        }
    }

    /// Performs a request with a generic JSON body (e.g. [String: Any] via dictionary).
    public func requestJSON(
        path: String,
        method: String = "GET",
        query: [String: String]? = nil,
        body: [String: Any]? = nil,
        tokenOverride: String? = nil
    ) async throws -> Data {
        let queryItems = query?.map { URLQueryItem(name: $0.key, value: $0.value) }
        let requestURL = url(path: path, queryItems: queryItems?.isEmpty == false ? queryItems : nil)
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let token = tokenOverride ?? authToken()
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body, let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = jsonData
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DivoAPIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DivoAPIError.serverError(statusCode: 0)
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw DivoAPIError.unauthorized
        case 403:
            throw DivoAPIError.forbidden
        case 422:
            let payload = DivoAPIErrorPayload.parse(from: data)
            throw DivoAPIError.validation(message: payload?.message, errors: payload?.errors)
        default:
            throw DivoAPIError.serverError(statusCode: http.statusCode)
        }
    }

    /// Builds multipart body and performs upload (e.g. file/upload-file, file/upload-files).
    public func upload(
        path: String,
        method: String = "POST",
        multipart: MultipartForm,
        tokenOverride: String? = nil
    ) async throws -> Data {
        let requestURL = url(path: path)
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        let (boundary, body) = multipart.build()
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body

        let token = tokenOverride ?? authToken()
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DivoAPIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw DivoAPIError.serverError(statusCode: 0)
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw DivoAPIError.unauthorized
        case 403:
            throw DivoAPIError.forbidden
        case 422:
            let payload = DivoAPIErrorPayload.parse(from: data)
            throw DivoAPIError.validation(message: payload?.message, errors: payload?.errors)
        default:
            throw DivoAPIError.serverError(statusCode: http.statusCode)
        }
    }
}

/// Type-erased Encodable for generic body encoding.
private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        encode = value.encode
    }
    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

/// Multipart form data for file uploads.
public struct MultipartForm {
    private var parts: [(name: String, filename: String?, data: Data, mimeType: String?)] = []
    private static let boundaryPrefix = "DivoDAL"

    public init() {}

    public mutating func append(name: String, data: Data, filename: String? = nil, mimeType: String? = nil) {
        parts.append((name: name, filename: filename, data: data, mimeType: mimeType))
    }

    public mutating func append(name: String, value: String) {
        if let d = value.data(using: .utf8) {
            parts.append((name: name, filename: nil, data: d, mimeType: nil))
        }
    }

    public func build() -> (boundary: String, body: Data) {
        let boundary = MultipartForm.boundaryPrefix + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var body = Data()
        for part in parts {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename {
                disposition += "; filename=\"\(filename)\""
            }
            body.append((disposition + "\r\n").data(using: .utf8)!)
            if let mime = part.mimeType {
                body.append("Content-Type: \(mime)\r\n".data(using: .utf8)!)
            }
            body.append("\r\n".data(using: .utf8)!)
            body.append(part.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return (boundary, body)
    }
}
