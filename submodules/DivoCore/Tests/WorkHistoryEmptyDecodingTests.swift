import Foundation
import XCTest
@testable import DivoCore

/// Пустая история работы — не ошибка: бэк может отдать `data: []`, `data: null` или `{"items": []}`.
final class WorkHistoryEmptyDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> WorkHistoryResponse {
        return try JSONDecoder().decode(WorkHistoryResponse.self, from: Data(json.utf8))
    }

    func testEmptyItemsObject() throws {
        XCTAssertTrue(try decode(#"{"message":"ok","data":{"items":[]}}"#).data.items.isEmpty)
    }

    func testEmptyArrayInsteadOfObject() throws {
        XCTAssertTrue(try decode(#"{"message":"ok","data":[]}"#).data.items.isEmpty)
    }

    func testNullOrMissingData() throws {
        XCTAssertTrue(try decode(#"{"message":"ok","data":null}"#).data.items.isEmpty)
        XCTAssertTrue(try decode(#"{"message":"ok"}"#).data.items.isEmpty)
    }

    func testItemsStillDecoded() throws {
        let response = try decode(#"{"data":{"items":[{"id":1,"agencyId":5,"agencyName":"ONE"}]}}"#)
        XCTAssertEqual(response.data.items.first?.id, 1)
        XCTAssertEqual(response.data.items.first?.agencyId, 5)
    }
}
