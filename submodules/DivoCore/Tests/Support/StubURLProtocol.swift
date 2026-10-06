import Foundation
@testable import DivoCore

/// Подставной «сервер» для DivoAPIClient: на каждый запрос зовёт `handler` и отдаёт его ответ.
/// Все запросы записываются (с телом) — тест проверяет путь, метод, заголовки и JSON.
final class StubURLProtocol: URLProtocol {

    struct Response {
        var statusCode: Int
        var body: Data
        var headers: [String: String]

        static func json(_ statusCode: Int, _ body: String) -> Response {
            return Response(statusCode: statusCode, body: Data(body.utf8), headers: ["Content-Type": "application/json"])
        }

        static func raw(_ statusCode: Int, _ body: String, contentType: String) -> Response {
            return Response(statusCode: statusCode, body: Data(body.utf8), headers: ["Content-Type": contentType])
        }
    }

    /// Обрыв соединения вместо HTTP-ответа.
    struct TransportFailure: Error {
        let code: URLError.Code
    }

    struct RecordedRequest {
        let method: String
        let url: URL
        let headers: [String: String]
        let body: Data?

        /// Путь с query, без префикса из baseURL (`/api` на stage, `/v2` на prod).
        var apiPath: String {
            let path = url.path
            let prefix = DivoConfig.baseURL.path
            let trimmed = (!prefix.isEmpty && path.hasPrefix(prefix)) ? String(path.dropFirst(prefix.count)) : path
            if let query = url.query {
                return trimmed + "?" + query
            }
            return trimmed
        }

        var jsonBody: [String: Any]? {
            guard let body else { return nil }
            return (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        }

        func header(_ name: String) -> String? {
            return headers.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame })?.value
        }
    }

    private static let lock = NSLock()
    private static var _handler: ((RecordedRequest) throws -> Response)?
    private static var _requests: [RecordedRequest] = []

    static var handler: ((RecordedRequest) throws -> Response)? {
        get { lock.lock(); defer { lock.unlock() }; return _handler }
        set { lock.lock(); _handler = newValue; lock.unlock() }
    }

    static var requests: [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    static func reset() {
        lock.lock()
        _handler = nil
        _requests = []
        lock.unlock()
    }

    /// Ответы по порядку: первый запрос получает первый ответ и т.д.
    static func respondInOrder(_ responses: [Response]) {
        var queue = responses
        let queueLock = NSLock()
        handler = { request in
            queueLock.lock()
            defer { queueLock.unlock() }
            guard !queue.isEmpty else {
                throw StubError.unexpectedRequest(request.apiPath)
            }
            return queue.removeFirst()
        }
    }

    enum StubError: Error {
        case unexpectedRequest(String)
        case noHandler
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // URLSession переносит тело в httpBodyStream — читаем его сами.
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        let recorded = RecordedRequest(
            method: request.httpMethod ?? "GET",
            url: request.url!,
            headers: request.allHTTPHeaderFields ?? [:],
            body: body
        )
        Self.lock.lock()
        Self._requests.append(recorded)
        let handler = Self._handler
        Self.lock.unlock()

        do {
            guard let handler else { throw StubError.noHandler }
            let response = try handler(recorded)
            let http = HTTPURLResponse(url: request.url!, statusCode: response.statusCode, httpVersion: "HTTP/1.1", headerFields: response.headers)!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch let failure as TransportFailure {
            client?.urlProtocol(self, didFailWithError: URLError(failure.code))
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
