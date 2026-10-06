import Foundation
import XCTest
@testable import DivoCore

/// Разбор ответов бэка: пограничные формы, которые реально приходят (или по контракту могут прийти).
final class ResponseDecodingTests: DivoCoreTestCase {

    // MARK: - errors: «никогда не строка» по контракту, но клиент не должен падать ни на одной форме

    func testErrorsAsFieldObject() throws {
        let errors = try decode(DivoResponseErrors.self, #"{"userId":["The user id field is required."],"limit":"too big"}"#)
        XCTAssertEqual(errors.fields["userId"], ["The user id field is required."])
        XCTAssertEqual(errors.fields["limit"], ["too big"])
    }

    func testErrorsAsArrayStringNullAndUnknownShape() throws {
        struct Envelope: Decodable { let errors: DivoResponseErrors? }
        XCTAssertEqual(try decode(Envelope.self, #"{"errors":["a","b"]}"#).errors?.fields[""], ["a", "b"])
        XCTAssertEqual(try decode(Envelope.self, #"{"errors":"oops"}"#).errors?.firstMessage, "oops")
        XCTAssertNil(try decode(Envelope.self, #"{"errors":null}"#).errors)
        XCTAssertEqual(try decode(Envelope.self, #"{"errors":42}"#).errors?.fields, [:])
        XCTAssertEqual(try decode(Envelope.self, #"{"errors":[]}"#).errors?.fields, [:])
    }

    // MARK: - Профиль

    func testProfileStubIsUnavailableDecodesWithoutOtherFields() throws {
        let response = try decode(UserDetailResponse.self, envelope(data: #"{"id":42,"isUnavailable":true,"message":"Профиль недоступен"}"#))
        XCTAssertEqual(response.data.id, 42)
        XCTAssertEqual(response.data.isUnavailable, true)
        XCTAssertNil(response.data.fullName)
        XCTAssertNil(response.data.telegramId)
    }

    func testProfileToleratesNullsAndUnknownFields() throws {
        let json = envelope(data: #"""
        {"id":7,"fullName":null,"photo":null,"avatar":null,"role":"model","telegramId":null,
         "someNewField":{"nested":[1,2,3]},"isUnavailable":false,"statistic":null}
        """#)
        let response = try decode(UserDetailResponse.self, json)
        XCTAssertEqual(response.data.id, 7)
        XCTAssertEqual(response.data.isUnavailable, false)
        XCTAssertNil(response.data.avatar)
    }

    // MARK: - Список заблокированных

    func testBlockedUserPrefersAvatarOverPhoto() throws {
        let user = try decode(DivoBlockedUser.self, #"""
        {"id":42,"fullName":"Анна","telegramId":123456789,"roleLabel":"Модель",
         "photo":{"fullUrl":"https://cdn/photo.jpg"},"avatar":{"fullUrl":"https://cdn/avatar.jpg"}}
        """#)
        XCTAssertEqual(user.imageUrl, "https://cdn/avatar.jpg")
        XCTAssertEqual(user.telegramId, 123456789)
    }

    func testBlockedUserFallsBackToPhotoAndHandlesMissingFields() throws {
        let user = try decode(DivoBlockedUser.self, #"{"id":42,"fullName":null,"telegramId":null,"photo":{"fullUrl":"https://cdn/photo.jpg"},"avatar":null}"#)
        XCTAssertEqual(user.imageUrl, "https://cdn/photo.jpg")
        XCTAssertNil(user.telegramId)
        XCTAssertEqual(user.displayName, "#42")   // у удалённых имени может не быть
    }

    func testBlockedUserWithoutIdFails() {
        XCTAssertThrowsError(try JSONDecoder().decode(DivoBlockedUser.self, from: Data(#"{"fullName":"x"}"#.utf8)))
    }

    func testBlockedPageWithPaginationMeta() throws {
        let response = try decode(BlockedUsersResponse.self, envelope(data: #"""
        {"items":[{"id":1},{"id":2}],"pagination":{"meta":{"limit":20,"currentOffset":2,"totalCount":5}}}
        """#))
        XCTAssertEqual(response.data?.items.map(\.id), [1, 2])
        XCTAssertEqual(response.data?.pagination?.meta?.currentOffset, 2)
        XCTAssertEqual(response.data?.pagination?.meta?.totalCount, 5)
    }

    func testBlockUnblockResponseWithNullData() throws {
        let response = try decode(UserBlockResponse.self, envelope(message: #""Пользователь заблокирован""#))
        XCTAssertEqual(response.message, "Пользователь заблокирован")
    }
}
