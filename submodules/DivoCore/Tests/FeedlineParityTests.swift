import Foundation
import XCTest
@testable import DivoCore

/// Лента `/feedline/list` — параметры и пагинация как в Android (`FeedRequestDto`, `OffsetPaginator`).
final class FeedlineParityTests: XCTestCase {

    func testRequestBodyMatchesAndroid() throws {
        let body = FeedlineListRequest(offset: 5, limit: 16, subscribedOnly: false, modelsOnly: false, role: "new_face", withoutNfts: true, isProfiles: true)
        let data = try JSONEncoder().encode(body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["role"] as? String, "new_face")
        XCTAssertEqual(json["isProfiles"] as? Bool, true)
        XCTAssertEqual(json["withoutNfts"] as? Bool, true)
        XCTAssertEqual(json["subscribedOnly"] as? Bool, false)
        XCTAssertEqual(json["modelsOnly"] as? Bool, false)
        XCTAssertEqual(json["offset"] as? Int, 5)
    }

    func testIsProfilesOmittedWhenNotSet() throws {
        let data = try JSONEncoder().encode(FeedlineListRequest(offset: 0, limit: 5))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["isProfiles"])
    }

    func testPaginationTotalCountDecoded() throws {
        let json = #"{"items":[],"pagination":{"meta":{"limit":16,"currentOffset":0,"totalCount":42}}}"#
        let data = try JSONDecoder().decode(FeedlineData.self, from: Data(json.utf8))
        XCTAssertEqual(data.totalCount, 42)
    }

    func testMissingPaginationIsTolerated() throws {
        let data = try JSONDecoder().decode(FeedlineData.self, from: Data(#"{"items":[]}"#.utf8))
        XCTAssertNil(data.totalCount)
    }
}
