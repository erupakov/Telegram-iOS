import Foundation
import XCTest
@testable import DivoCore

/// DivoAPIClient: что уходит на бэк (путь, метод, заголовки, тело) и как разбираются ошибки.
final class APIClientTests: DivoCoreTestCase {

    // MARK: - Форма запроса

    func testRequestShapeAndRequiredHeaders() async throws {
        StubURLProtocol.respondInOrder([.json(200, envelope())])

        let _: UserBlockResponse = try await DivoAPIClient.shared.request(
            path: "/user/block",
            method: "POST",
            body: UserBlockRequest(userId: 42)
        )

        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.apiPath, "/user/block")
        XCTAssertEqual(request.header("Authorization"), "Bearer \(DivoConfig.accessToken)")
        XCTAssertEqual(request.header("Content-Type"), "application/json")
        XCTAssertEqual(request.header("Accept"), "application/json")
        // Бэк отвечает 422 без App-Platform / App-Version (docs/divo-api-user-block.md).
        XCTAssertEqual(request.header("App-Platform"), "ios")
        XCTAssertEqual(request.header("App-Version"), DivoConfig.appVersion)
        XCTAssertEqual(request.header("Accept-Language"), DivoStrings.current.rawValue)
        XCTAssertEqual(request.jsonBody?["userId"] as? Int, 42)
    }

    func testAppVersionFormatIsVersionWithBuildInParens() {
        // Формат «1.4.0 (123)»; без номера сборки — просто версия.
        let version = DivoConfig.appVersion
        XCTAssertFalse(version.isEmpty)
        if version.contains("(") {
            XCTAssertNotNil(version.range(of: #"^\S+ \(\S+\)$"#, options: .regularExpression), version)
        }
    }

    func testRequestWithoutAuthorizationOmitsHeader() async throws {
        StubURLProtocol.respondInOrder([.json(200, envelope())])

        let _: UserBlockResponse = try await DivoAPIClient.shared.request(
            path: "/auth/telegram-link",
            method: "POST",
            body: UserBlockRequest(userId: 1),
            includeAuthorization: false
        )

        XCTAssertNil(requests.first?.header("Authorization"))
    }

    // MARK: - Ошибки

    func testHttp422MapsToHttpErrorWithServerMessage() async {
        StubURLProtocol.respondInOrder([.json(422, #"{"message":"Действие недоступно","data":null,"errors":null}"#)])

        let error = await requestError(path: "/user/like")

        guard case let .httpError(statusCode, body)? = error as? DivoAPIError else {
            return XCTFail("Ожидали httpError, получили \(String(describing: error))")
        }
        XCTAssertEqual(statusCode, 422)
        XCTAssertTrue(body.contains("Действие недоступно"))
        XCTAssertEqual((error as? DivoAPIError)?.userFacingMessage, "Действие недоступно")
    }

    func testValidationErrorMessageIncludesFirstFieldError() async {
        StubURLProtocol.respondInOrder([.json(422, #"{"message":"Ошибка валидации","data":null,"errors":{"limit":["Не больше 100"]}}"#)])

        let error = await requestError(path: "/user/blocked")

        XCTAssertEqual((error as? DivoAPIError)?.userFacingMessage, "Ошибка валидации\nНе больше 100")
    }

    func testHtmlErrorPageFromProxyHasNoUserFacingMessage() async {
        StubURLProtocol.respondInOrder([.raw(502, "<html><body>Bad Gateway</body></html>", contentType: "text/html")])

        let error = await requestError(path: "/user/block")

        guard case .httpError(502, _)? = error as? DivoAPIError else {
            return XCTFail("Ожидали httpError 502, получили \(String(describing: error))")
        }
        XCTAssertNil((error as? DivoAPIError)?.userFacingMessage)
    }

    func testMalformedJsonOnSuccessIsDecodingError() async {
        StubURLProtocol.respondInOrder([.json(200, #"{"message":"ok","data":"#)])

        let error = await requestError(path: "/user/block")

        guard case .decodingError? = error as? DivoAPIError else {
            return XCTFail("Ожидали decodingError, получили \(String(describing: error))")
        }
    }

    func testEmptyBodyOnSuccessIsDecodingError() async {
        StubURLProtocol.respondInOrder([.raw(200, "", contentType: "application/json")])

        let error = await requestError(path: "/user/block")

        guard case .decodingError? = error as? DivoAPIError else {
            return XCTFail("Ожидали decodingError, получили \(String(describing: error))")
        }
    }

    func testDroppedConnectionIsNetworkError() async {
        StubURLProtocol.handler = { _ in throw StubURLProtocol.TransportFailure(code: .networkConnectionLost) }

        let error = await requestError(path: "/user/block")

        XCTAssertNotNil(error)
        XCTAssertTrue(isNetworkError(error!), "\(String(describing: error))")
    }

    // MARK: - 401

    func testUnauthorizedWithStoredTokenSignalsSessionExpired() async {
        let expired = expectNotification(DivoConfig.sessionExpiredNotification)
        StubURLProtocol.respondInOrder([.json(401, #"{"message":"Unauthenticated."}"#)])

        _ = await requestError(path: "/user/info")

        await fulfillment(of: [expired], timeout: 2.0)
    }

    func testUnauthorizedWithoutAuthorizationHeaderDoesNotSignal() async {
        let expired = expectNotification(DivoConfig.sessionExpiredNotification)
        expired.isInverted = true
        StubURLProtocol.respondInOrder([.json(401, #"{"message":"Unauthenticated."}"#)])

        do {
            let _: UserBlockResponse = try await DivoAPIClient.shared.request(
                path: "/auth/telegram-link",
                method: "POST",
                body: UserBlockRequest(userId: 1),
                includeAuthorization: false
            )
            XCTFail("Ожидали ошибку")
        } catch {}

        await fulfillment(of: [expired], timeout: 0.5)
    }

    // MARK: - Helpers

    private func requestError(path: String) async -> Error? {
        do {
            let _: UserBlockResponse = try await DivoAPIClient.shared.request(
                path: path,
                method: "POST",
                body: UserBlockRequest(userId: 42)
            )
            return nil
        } catch {
            return error
        }
    }
}
