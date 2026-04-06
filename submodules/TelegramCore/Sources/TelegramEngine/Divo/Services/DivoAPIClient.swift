import Foundation

public final class DivoAPIClient {
    public static let shared = DivoAPIClient()

    private let session: URLSession
    private let baseURL: URL
    private let logger = DivoRequestLogger.shared

    private init() {
        self.baseURL = DivoConfig.baseURL
        self.session = URLSession.shared
    }

    public func request<T: Decodable>(
        path: String,
        method: String = "GET"
    ) async throws -> T {
        return try await request(path: path, method: method, body: Optional<EmptyBody>.none)
    }

    public func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: (some Encodable)?
    ) async throws -> T {
        let url = URL(string: baseURL.absoluteString + path)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(DivoConfig.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(DivoConfig.appPlatform, forHTTPHeaderField: "app-platform")
        request.setValue(DivoConfig.appVersion, forHTTPHeaderField: "app-version")
        request.setValue(DivoStrings.current.rawValue, forHTTPHeaderField: "Accept-Language")

        var requestBodyString: String?
        if let body = body {
            let encoded = try JSONEncoder().encode(body)
            request.httpBody = encoded
            requestBodyString = String(data: encoded, encoding: .utf8)
        }

        let delay = DivoConfig.simulatedDelay
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, response) = try await session.data(for: request)
            let duration = CFAbsoluteTimeGetCurrent() - start
            let http = response as? HTTPURLResponse
            let responseString = String(data: data.prefix(4096), encoding: .utf8)

            logger.log(
                method: method,
                path: path,
                statusCode: http?.statusCode,
                duration: duration,
                requestBody: requestBodyString,
                responseBody: responseString
            )

            guard let http = http else {
                throw DivoAPIError.unknown
            }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("❌ API Error [\(http.statusCode)] \(url.absoluteString): \(body)")
                throw DivoAPIError.httpError(statusCode: http.statusCode, body: body)
            }

            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start
            if !(error is DivoAPIError) {
                logger.log(
                    method: method,
                    path: path,
                    statusCode: nil,
                    duration: duration,
                    requestBody: requestBodyString,
                    error: error.localizedDescription
                )
            }
            throw error
        }
    }

    public func requestRawData(
        path: String,
        method: String = "GET",
        body: (some Encodable)?
    ) async throws -> Data {
        let url = URL(string: baseURL.absoluteString + path)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(DivoConfig.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(DivoConfig.appPlatform, forHTTPHeaderField: "app-platform")
        request.setValue(DivoConfig.appVersion, forHTTPHeaderField: "app-version")
        request.setValue(DivoStrings.current.rawValue, forHTTPHeaderField: "Accept-Language")

        var requestBodyString: String?
        if let body = body {
            let encoded = try JSONEncoder().encode(body)
            request.httpBody = encoded
            requestBodyString = String(data: encoded, encoding: .utf8)
        }

        let rawDelay = DivoConfig.simulatedDelay
        if rawDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(rawDelay * 1_000_000_000))
        }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, response) = try await session.data(for: request)
            let duration = CFAbsoluteTimeGetCurrent() - start
            let http = response as? HTTPURLResponse

            logger.log(
                method: method,
                path: path,
                statusCode: http?.statusCode,
                duration: duration,
                requestBody: requestBodyString,
                responseBody: String(data: data.prefix(4096), encoding: .utf8)
            )

            guard let http = http else {
                throw DivoAPIError.unknown
            }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw DivoAPIError.httpError(statusCode: http.statusCode, body: body)
            }

            return data
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start
            if !(error is DivoAPIError) {
                logger.log(
                    method: method,
                    path: path,
                    statusCode: nil,
                    duration: duration,
                    requestBody: requestBodyString,
                    error: error.localizedDescription
                )
            }
            throw error
        }
    }

    public func upload<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String = "photo.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> T {
        let url = URL(string: baseURL.absoluteString + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(DivoConfig.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(DivoConfig.appPlatform, forHTTPHeaderField: "app-platform")
        request.setValue(DivoConfig.appVersion, forHTTPHeaderField: "app-version")
        request.setValue(DivoStrings.current.rawValue, forHTTPHeaderField: "Accept-Language")

        var body = Data()

        let fieldName = "file"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)

        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let uploadDelay = DivoConfig.simulatedDelay
        if uploadDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(uploadDelay * 1_000_000_000))
        }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (data, response) = try await session.upload(for: request, from: body)
            let duration = CFAbsoluteTimeGetCurrent() - start
            let http = response as? HTTPURLResponse

            logger.log(
                method: "POST (upload)",
                path: path,
                statusCode: http?.statusCode,
                duration: duration,
                requestBody: "\(fileName) (\(fileData.count) bytes)",
                responseBody: String(data: data.prefix(4096), encoding: .utf8)
            )

            guard let http = http else {
                throw DivoAPIError.unknown
            }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("❌ Upload Error [\(http.statusCode)]: \(body)")
                throw DivoAPIError.httpError(statusCode: http.statusCode, body: body)
            }

            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start
            if !(error is DivoAPIError) {
                logger.log(
                    method: "POST (upload)",
                    path: path,
                    statusCode: nil,
                    duration: duration,
                    requestBody: "\(fileName) (\(fileData.count) bytes)",
                    error: error.localizedDescription
                )
            }
            throw error
        }
    }
}

public enum DivoAPIError: Error, LocalizedError {
    case httpError(statusCode: Int, body: String = "")
    case unknown

    public var errorDescription: String? {
        switch self {
        case .httpError(let code, _): return "HTTP \(code)"
        case .unknown: return "Unknown API error"
        }
    }
}

private struct EmptyBody: Encodable {}
