import Foundation
import XCTest
@testable import DivoCore

/// Тело лайка профиля: оба варианта ключа (`user_id` у iOS исторически, `userId` у Android).
final class UserLikeRequestTests: XCTestCase {
    func testEncodesBothKeys() throws {
        let data = try JSONEncoder().encode(UserLikeRequest(userId: 42))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Int])
        XCTAssertEqual(json["user_id"], 42)
        XCTAssertEqual(json["userId"], 42)
        XCTAssertEqual(json.count, 2)
    }
}
