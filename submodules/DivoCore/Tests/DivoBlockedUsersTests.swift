import Foundation
import XCTest
@testable import DivoCore

/// DivoBlockedUsers по контракту docs/divo-api-user-block.md: пагинация, гард сессии,
/// блок из чата через /user/by-telegram, кэш и уведомления.
final class DivoBlockedUsersTests: DivoCoreTestCase {

    // MARK: - POST /user/blocked

    func testFetchWalksPagesUntilTotalCount() async throws {
        StubURLProtocol.respondInOrder([
            .json(200, blockedPage(ids: Array(1...100), currentOffset: 100, totalCount: 120)),
            .json(200, blockedPage(ids: Array(101...120), currentOffset: 120, totalCount: 120)),
        ])

        let users = try await DivoBlockedUsers.fetch()

        XCTAssertEqual(users.count, 120)
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.allSatisfy { $0.method == "POST" && $0.apiPath == "/user/blocked" })
        XCTAssertEqual(requests[0].jsonBody?["offset"] as? Int, 0)
        XCTAssertEqual(requests[1].jsonBody?["offset"] as? Int, 100)   // следующий offset = currentOffset
        XCTAssertTrue(requests.allSatisfy { ($0.jsonBody?["limit"] as? Int).map { (1...100).contains($0) } ?? false })
        XCTAssertEqual(DivoBlockedUsers.isBlocked(userId: 120), true)
        XCTAssertEqual(DivoBlockedUsers.cachedCount, 120)
    }

    func testFetchStopsOnEmptyPageWithoutMeta() async throws {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"{"items":[]}"#)),
        ])

        let users = try await DivoBlockedUsers.fetch()

        XCTAssertTrue(users.isEmpty)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(DivoBlockedUsers.isBlocked(userId: 1), false)   // список загружен — не nil
    }

    func testFetchDoesNotLoopWhenServerDoesNotAdvanceOffset() async throws {
        // Сломанная мета (currentOffset не растёт) не должна зациклить загрузку.
        StubURLProtocol.respondInOrder([
            .json(200, blockedPage(ids: [1, 2], currentOffset: 0, totalCount: 50)),
        ])

        let users = try await DivoBlockedUsers.fetch()

        XCTAssertEqual(users.map(\.id), [1, 2])
        XCTAssertEqual(requests.count, 1)
    }

    func testFetchSyncsTelegramBlockStateForListedUsers() async throws {
        var synced: [Int64: Bool] = [:]
        DivoBlockedUsers.telegramBlockStateUpdater = { telegramId, isBlocked in synced[telegramId] = isBlocked }
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"""
            {"items":[{"id":1,"telegramId":777},{"id":2,"telegramId":null}],
             "pagination":{"meta":{"limit":100,"currentOffset":2,"totalCount":2}}}
            """#)),
        ])

        try await DivoBlockedUsers.fetch()

        XCTAssertEqual(synced, [777: true])
        XCTAssertEqual(DivoBlockedUsers.telegramId(userId: 1), 777)
        XCTAssertNil(DivoBlockedUsers.telegramId(userId: 2))
    }

    func testFetchErrorLeavesCacheUnloaded() async {
        StubURLProtocol.respondInOrder([.json(500, #"{"message":"Server Error"}"#)])

        do {
            try await DivoBlockedUsers.fetch()
            XCTFail("Ожидали ошибку")
        } catch {}

        XCTAssertNil(DivoBlockedUsers.isBlocked(userId: 1))
        XCTAssertNil(DivoBlockedUsers.cachedCount)
    }

    // MARK: - Гард сессии: зашитый токен агентства не должен блокировать от имени агентства

    func testNoOwnSessionSendsNothing() async {
        signOut()

        await assertThrowsNoSession { try await DivoBlockedUsers.block(userId: 42) }
        await assertThrowsNoSession { try await DivoBlockedUsers.unblock(userId: 42) }
        await assertThrowsNoSession { _ = try await DivoBlockedUsers.fetch() }
        let outcome = await DivoBlockedUsers.setBlocked(telegramUserId: 555, isBlocked: true)

        XCTAssertEqual(outcome, .notDivoUser)
        XCTAssertTrue(requests.isEmpty, "Ушли запросы: \(requests.map(\.apiPath))")
    }

    // MARK: - POST /user/block, /user/unblock

    func testBlockUpdatesCachePostsNotificationsAndSyncsChat() async throws {
        var synced: [Int64: Bool] = [:]
        DivoBlockedUsers.telegramBlockStateUpdater = { telegramId, isBlocked in synced[telegramId] = isBlocked }
        let blocked = expectNotification(DivoBlockedUsers.userBlockedNotification) { ($0.userInfo?["userId"] as? Int) == 42 }
        let unfollowed = expectNotification(DivoConfig.divoFollowStateChanged) {
            ($0.userInfo?["userId"] as? Int) == 42 && ($0.userInfo?["isFollowed"] as? Bool) == false
        }
        StubURLProtocol.respondInOrder([.json(200, envelope(message: #""Пользователь заблокирован""#))])

        try await DivoBlockedUsers.block(userId: 42, telegramId: 777)

        XCTAssertEqual(requests.first?.apiPath, "/user/block")
        XCTAssertEqual(requests.first?.jsonBody?["userId"] as? Int, 42)
        XCTAssertEqual(DivoBlockedUsers.isBlocked(userId: 42), true)
        XCTAssertEqual(DivoBlockedUsers.telegramId(userId: 42), 777)
        XCTAssertEqual(synced, [777: true])
        await fulfillment(of: [blocked, unfollowed], timeout: 2.0)
    }

    func testBlockFailureChangesNothing() async {
        var synced: [Int64: Bool] = [:]
        DivoBlockedUsers.telegramBlockStateUpdater = { telegramId, isBlocked in synced[telegramId] = isBlocked }
        let blocked = expectNotification(DivoBlockedUsers.userBlockedNotification) {
            ($0.userInfo?["userId"] as? Int) == DivoCoreTestCase.ownUserId
        }
        blocked.isInverted = true
        // 422: попытка заблокировать себя.
        StubURLProtocol.respondInOrder([.json(422, #"{"message":"Вы не можете заблокировать себя","data":null,"errors":null}"#)])

        do {
            try await DivoBlockedUsers.block(userId: DivoCoreTestCase.ownUserId, telegramId: 777)
            XCTFail("Ожидали ошибку")
        } catch {}

        XCTAssertNil(DivoBlockedUsers.isBlocked(userId: DivoCoreTestCase.ownUserId))
        XCTAssertTrue(synced.isEmpty)
        await fulfillment(of: [blocked], timeout: 0.5)
    }

    func testUnblockRemovesFromCacheAndSyncsChat() async throws {
        var synced: [Int64: Bool] = [:]
        DivoBlockedUsers.telegramBlockStateUpdater = { telegramId, isBlocked in synced[telegramId] = isBlocked }
        StubURLProtocol.respondInOrder([.json(200, envelope()), .json(200, envelope())])

        try await DivoBlockedUsers.block(userId: 42, telegramId: 777)
        try await DivoBlockedUsers.unblock(userId: 42, telegramId: 777)

        XCTAssertEqual(requests.map(\.apiPath), ["/user/block", "/user/unblock"])
        XCTAssertEqual(DivoBlockedUsers.isBlocked(userId: 42), false)
        XCTAssertNil(DivoBlockedUsers.telegramId(userId: 42))
        XCTAssertEqual(synced, [777: false])
    }

    // MARK: - Кэш привязан к аккаунту

    func testCacheIsNotInheritedByAnotherAccount() async throws {
        StubURLProtocol.respondInOrder([.json(200, envelope())])
        try await DivoBlockedUsers.block(userId: 42)
        XCTAssertEqual(DivoBlockedUsers.isBlocked(userId: 42), true)

        signIn(userId: DivoCoreTestCase.ownUserId + 1)

        XCTAssertNil(DivoBlockedUsers.isBlocked(userId: 42))
        XCTAssertNil(DivoBlockedUsers.cachedCount)
    }

    func testSessionResetClearsCache() async throws {
        StubURLProtocol.respondInOrder([.json(200, envelope())])
        try await DivoBlockedUsers.block(userId: 42, telegramId: 777)

        DivoConfig.resetDivoSessionForRollback()
        signIn()

        XCTAssertNil(DivoBlockedUsers.isBlocked(userId: 42))
        XCTAssertNil(DivoBlockedUsers.telegramId(userId: 42))
    }

    // MARK: - Блок из чата: /user/by-telegram → /user/block

    func testChatBlockResolvesDivoIdThenBlocks() async {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"{"id":42,"fullName":"Анна"}"#)),
            .json(200, envelope()),
        ])

        let outcome = await DivoBlockedUsers.setBlocked(telegramUserId: 777, isBlocked: true)

        XCTAssertEqual(outcome, .done)
        XCTAssertEqual(requests.map(\.method), ["GET", "POST"])
        XCTAssertEqual(requests.map(\.apiPath), ["/user/by-telegram?telegramId=777", "/user/block"])
        XCTAssertEqual(requests.last?.jsonBody?["userId"] as? Int, 42)
        XCTAssertEqual(DivoBlockedUsers.telegramId(userId: 42), 777)
    }

    func testChatBlockWorksWhenProfileIsUnavailableStub() async {
        // Профиль уже недоступен (блок с другой стороны) — заглушка всё равно содержит id.
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"{"id":42,"isUnavailable":true,"message":"Профиль недоступен"}"#)),
            .json(200, envelope()),
        ])

        let outcome = await DivoBlockedUsers.setBlocked(telegramUserId: 777, isBlocked: true)

        XCTAssertEqual(outcome, .done)
        XCTAssertEqual(requests.last?.jsonBody?["userId"] as? Int, 42)
    }

    func testChatBlockWithoutDivoAccountFallsBackToTelegram() async {
        for statusCode in [404, 422] {
            StubURLProtocol.reset()
            StubURLProtocol.respondInOrder([.json(statusCode, #"{"message":"User not found"}"#)])

            let outcome = await DivoBlockedUsers.setBlocked(telegramUserId: 777, isBlocked: true)

            XCTAssertEqual(outcome, .notDivoUser, "HTTP \(statusCode)")
            XCTAssertEqual(requests.count, 1, "HTTP \(statusCode): блок в DIVO слать некому")
        }
    }

    func testChatBlockServerErrorIsFailedNotFallback() async {
        // 5xx / сеть → .failed: contacts.block вызывать нельзя, иначе teamgram разъедется с DIVO.
        StubURLProtocol.respondInOrder([.raw(503, "Service Unavailable", contentType: "text/plain")])
        let resolveFailed = await DivoBlockedUsers.setBlocked(telegramUserId: 777, isBlocked: true)
        XCTAssertEqual(resolveFailed, .failed)

        StubURLProtocol.reset()
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"{"id":42}"#)),
            .json(500, #"{"message":"Server Error"}"#),
        ])
        let blockFailed = await DivoBlockedUsers.setBlocked(telegramUserId: 777, isBlocked: true)
        XCTAssertEqual(blockFailed, .failed)
        XCTAssertNil(DivoBlockedUsers.isBlocked(userId: 42))
    }

    func testChatUnblockCallsUnblock() async {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"{"id":42}"#)),
            .json(200, envelope()),
        ])

        let outcome = await DivoBlockedUsers.setBlocked(telegramUserId: 777, isBlocked: false)

        XCTAssertEqual(outcome, .done)
        XCTAssertEqual(requests.last?.apiPath, "/user/unblock")
    }

    // MARK: - Helpers

    private func blockedPage(ids: [Int], currentOffset: Int, totalCount: Int) -> String {
        let items = ids.map { #"{"id":\#($0),"fullName":"User \#($0)"}"# }.joined(separator: ",")
        return envelope(data: #"{"items":[\#(items)],"pagination":{"meta":{"limit":100,"currentOffset":\#(currentOffset),"totalCount":\#(totalCount)}}}"#)
    }

    private func assertThrowsNoSession(_ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await body()
            XCTFail("Ожидали BlockError.noSession", file: file, line: line)
        } catch DivoBlockedUsers.BlockError.noSession {
        } catch {
            XCTFail("Ожидали BlockError.noSession, получили \(error)", file: file, line: line)
        }
    }
}
