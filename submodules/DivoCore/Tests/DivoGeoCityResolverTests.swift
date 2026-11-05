import Foundation
import XCTest
@testable import DivoCore

/// DivoGeoCityResolver: чистка запроса из подсказки Apple Maps и выбор результата с городом.
final class DivoGeoCityResolverTests: DivoCoreTestCase {

    // MARK: - queryCandidates

    func testEmptySubtitleDoesNotLeaveTrailingComma() {
        XCTAssertEqual(DivoGeoCityResolver.queryCandidates(for: "Гонконг, "), ["Гонконг"])
        XCTAssertEqual(DivoGeoCityResolver.queryCandidates(for: "Гонконг|||"), ["Гонконг"])
    }

    func testFullQueryThenCityOnly() {
        XCTAssertEqual(
            DivoGeoCityResolver.queryCandidates(for: "Гонконг, САР Китая"),
            ["Гонконг, САР Китая", "Гонконг"]
        )
    }

    func testBlankQueryHasNoCandidates() {
        XCTAssertEqual(DivoGeoCityResolver.queryCandidates(for: " , "), [])
    }

    // MARK: - resolveCity

    func testSkipsResultsWithoutCity() async throws {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"[{"country":{"name":"Гонконг","code":"HK"}},{"city":{"id":42,"name":"Гонконг","countryCode":"HK"}}]"#)),
        ])

        let item = try await DivoGeoCityResolver.resolveCity(query: "Гонконг")

        XCTAssertEqual(item?.city?.id, 42)
        XCTAssertEqual(requests.count, 1)
    }

    func testFallsBackToCityNameOnly() async throws {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: "[]")),
            .json(200, envelope(data: #"[{"city":{"id":7,"name":"Гонконг"}}]"#)),
        ])

        let item = try await DivoGeoCityResolver.resolveCity(query: "Гонконг, САР Китая")

        XCTAssertEqual(item?.city?.id, 7)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.url.query?.removingPercentEncoding, "query=Гонконг")
    }

    func testReturnsNilWhenNothingFound() async throws {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: "[]")),
            .json(200, envelope(data: "[]")),
        ])

        let item = try await DivoGeoCityResolver.resolveCity(query: "Гонконг, САР Китая")

        XCTAssertNil(item)
    }
}
