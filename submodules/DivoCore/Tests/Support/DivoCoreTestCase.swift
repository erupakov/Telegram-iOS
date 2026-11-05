import Foundation
import XCTest
@testable import DivoCore

/// База тестов DivoCore: весь трафик DivoAPIClient — через StubURLProtocol, состояние сессии
/// (токен, divoUserId) и кэш блокировок — свои на каждый тест.
class DivoCoreTestCase: XCTestCase {

    static let ownUserId = 1001
    private static var tokenCounter = 0

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        DivoAPIClient.shared.installTestTransport(protocolClasses: [StubURLProtocol.self])
        DivoConfig.forcedTestToken = nil
        DivoBlockedUsers.reset()
        DivoBlockedUsers.telegramBlockStateUpdater = nil
        signIn()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        DivoBlockedUsers.reset()
        DivoBlockedUsers.telegramBlockStateUpdater = nil
        signOut()
        super.tearDown()
    }

    /// Своя DIVO-сессия: уникальный токен на тест (новый токен снимает дебаунс 401 в DivoConfig).
    func signIn(userId: Int = DivoCoreTestCase.ownUserId) {
        DivoCoreTestCase.tokenCounter += 1
        DivoConfig.accessToken = "test-token-\(DivoCoreTestCase.tokenCounter)"
        DivoConfig.currentDivoUserId = userId
    }

    /// Нет своей сессии: запросы шли бы с зашитым токеном агентства.
    func signOut() {
        DivoConfig.resetToken()
        DivoConfig.currentDivoUserId = nil
    }

    var requests: [StubURLProtocol.RecordedRequest] {
        return StubURLProtocol.requests
    }

    func decode<T: Decodable>(_ type: T.Type, _ json: String, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: Data(json.utf8))
        } catch {
            XCTFail("Не декодировалось \(T.self): \(error)", file: file, line: line)
            throw error
        }
    }

    /// Ждёт пост уведомления на главной очереди (DivoBlockedUsers постит асинхронно).
    func expectNotification(_ name: Notification.Name, handler: ((Notification) -> Bool)? = nil) -> XCTestExpectation {
        return expectation(forNotification: name, object: nil, handler: handler)
    }
}

/// Конверт успешного ответа DIVO REST.
func envelope(data: String = "null", message: String = "null") -> String {
    return #"{"message":\#(message),"data":\#(data),"errors":null}"#
}
