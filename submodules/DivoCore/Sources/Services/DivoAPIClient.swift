import Foundation

public final class DivoAPIClient {
    public static let shared = DivoAPIClient()

    private let session: URLSession
    private let baseURL: URL
    private let logger = DivoRequestLogger.shared

    private init() {
        self.baseURL = DivoConfig.baseURL
        let config = URLSessionConfiguration.default
        config.protocolClasses = [DivoMockURLProtocol.self] + (config.protocolClasses ?? [])
        self.session = URLSession(configuration: config)
        // Network connectivity мониторится через DivoNetworkMonitor.shared (single source of truth).
        _ = DivoNetworkMonitor.shared
    }

    private func checkConnectivity() throws {
        guard DivoNetworkMonitor.shared.isConnected else {
            throw DivoAPIError.noInternetConnection
        }
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
        try checkConnectivity()
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
            let responseString = String(data: data, encoding: .utf8)

            guard let http = http else {
                logger.log(
                    method: method,
                    path: path,
                    statusCode: nil,
                    duration: duration,
                    requestBody: requestBodyString,
                    responseBody: responseString,
                    error: "No HTTPURLResponse"
                )
                throw DivoAPIError.unknown
            }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                logger.log(
                    method: method,
                    path: path,
                    statusCode: http.statusCode,
                    duration: duration,
                    requestBody: requestBodyString,
                    responseBody: responseString,
                    error: "HTTP \(http.statusCode)"
                )
                divoLog("API Error [\(http.statusCode)] \(url.absoluteString): \(body)", level: .error)
                throw DivoAPIError.httpError(statusCode: http.statusCode, body: body)
            }

            do {
                let result = try JSONDecoder().decode(T.self, from: data)
                logger.log(
                    method: method,
                    path: path,
                    statusCode: http.statusCode,
                    duration: duration,
                    requestBody: requestBodyString,
                    responseBody: responseString
                )
                return result
            } catch {
                logger.log(
                    method: method,
                    path: path,
                    statusCode: http.statusCode,
                    duration: duration,
                    requestBody: requestBodyString,
                    responseBody: responseString,
                    error: String(describing: error)
                )
                divoLog("Decode error [\(path)]: \(error)", level: .error)
                throw DivoAPIError.decodingError(underlying: error)
            }
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start
            if !(error is DivoAPIError) {
                logger.log(
                    method: method,
                    path: path,
                    statusCode: nil,
                    duration: duration,
                    requestBody: requestBodyString,
                    error: String(describing: error)
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
        try checkConnectivity()
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
                responseBody: String(data: data, encoding: .utf8)
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
        try checkConnectivity()
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
                responseBody: String(data: data, encoding: .utf8)
            )

            guard let http = http else {
                throw DivoAPIError.unknown
            }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                divoLog("Upload Error [\(http.statusCode)]: \(body)", level: .error)
                throw DivoAPIError.httpError(statusCode: http.statusCode, body: body)
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? "nil"
                divoLog("Decode error [\(path)]: \(error)", level: .error)
                divoLog("Response body: \(body)", level: .error)
                throw error
            }
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

    public func upload<T: Decodable>(
        path: String,
        fileData: Data,
        fileName: String = "photo.jpg",
        mimeType: String = "image/jpeg",
        fields: [String: String]
    ) async throws -> T {
        try checkConnectivity()
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

        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let uploadDelay = DivoConfig.simulatedDelay
        if uploadDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(uploadDelay * 1_000_000_000))
        }

        let fieldsDetail = fields.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        let uploadBody = "\(fileName) (\(fileData.count) bytes) | \(fieldsDetail)"

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
                requestBody: uploadBody,
                responseBody: String(data: data, encoding: .utf8)
            )

            guard let http = http else {
                throw DivoAPIError.unknown
            }

            guard (200...299).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                divoLog("Upload Error [\(http.statusCode)]: \(body)", level: .error)
                throw DivoAPIError.httpError(statusCode: http.statusCode, body: body)
            }

            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? "nil"
                divoLog("Decode error [\(path)]: \(error)", level: .error)
                divoLog("Response body: \(body)", level: .error)
                throw error
            }
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start
            if !(error is DivoAPIError) {
                logger.log(
                    method: "POST (upload)",
                    path: path,
                    statusCode: nil,
                    duration: duration,
                    requestBody: uploadBody,
                    error: error.localizedDescription
                )
            }
            throw error
        }
    }

    public func uploadRawData(
        path: String,
        fileData: Data,
        fileName: String = "photo.jpg",
        mimeType: String = "image/jpeg",
        fields: [String: String]
    ) async throws -> Data {
        try checkConnectivity()
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

        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let fieldsDetail = fields.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        let uploadBody = "\(fileName) (\(fileData.count) bytes) | \(fieldsDetail)"

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
                requestBody: uploadBody,
                responseBody: String(data: data, encoding: .utf8)
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
                    method: "POST (upload)",
                    path: path,
                    statusCode: nil,
                    duration: duration,
                    requestBody: uploadBody,
                    error: error.localizedDescription
                )
            }
            throw error
        }
    }
}

public enum DivoAPIError: Error, LocalizedError {
    case httpError(statusCode: Int, body: String = "")
    case decodingError(underlying: Error)
    case noInternetConnection
    case unknown

    public var errorDescription: String? {
        switch self {
        case .httpError(let code, _): return "HTTP \(code)"
        case .decodingError(let err): return "Decoding: \(err)"
        case .noInternetConnection: return "No internet connection"
        case .unknown: return "Unknown API error"
        }
    }

    /// Текст для пользователя из тела ошибки сервера (validation errors 4xx).
    /// Собирает message + первое детальное сообщение из errors (`{"field": ["..."]}`),
    /// чтобы пользователю было понятно, какое поле починить.
    /// Возвращает nil, если это не httpError или body не парсится — caller подставляет fallback.
    public var userFacingMessage: String? {
        guard case .httpError(_, let body) = self,
              let data = body.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ServerValidationError.self, from: data) else {
            return nil
        }
        let detail = decoded.errors?.values.first?.first
        let parts = [decoded.message, detail].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    /// `true`, если ошибка относится к отсутствию интернет-соединения.
    public var isNetwork: Bool {
        if case .noInternetConnection = self { return true }
        return false
    }
}

/// Проверка «нет интернета» для произвольной `Error` — для catch-блоков,
/// которые не приводят ошибку к `DivoAPIError` явно.
///
/// Помимо нашего reachability-предчека (`DivoAPIError.noInternetConnection`) ловим и «сырые»
/// `URLError` от URLSession: предчек проходит, если глобальный монитор ещё не успел переключиться
/// (сеть отвалилась в процессе запроса) — тогда падает уже сам запрос таймаутом/обрывом.
public func isNetworkError(_ error: Error) -> Bool {
    if (error as? DivoAPIError)?.isNetwork == true { return true }
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .dataNotAllowed:
            return true
        default:
            return false
        }
    }
    return false
}

private struct ServerValidationError: Decodable {
    let message: String?
    let errors: [String: [String]]?
}

private struct EmptyBody: Encodable {}
