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
            ["Гонконг", "Гонконг, САР Китая"]
        )
    }

    func testAddsDiacriticFreeCandidate() {
        XCTAssertEqual(
            DivoGeoCityResolver.queryCandidates(for: "Herāt|||Afghanistan"),
            ["Herāt", "Herāt, Afghanistan", "Herat"]
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
        XCTAssertEqual(requests.last?.url.query?.removingPercentEncoding, "query=Гонконг, САР Китая")
    }

    func testPrefersItemWithExpectedCountry() async throws {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"[{"city":{"id":1,"name":"Newark","countryCode":"GB"}},{"city":{"id":2,"name":"Newark","countryCode":"US"}}]"#)),
        ])

        let item = try await DivoGeoCityResolver.resolveCity(query: "Newark|||United States")

        XCTAssertEqual(item?.city?.id, 2)
        XCTAssertEqual(requests.count, 1)
    }

    func testTriesNextCandidateWhenCountryDoesNotMatch() async throws {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"[{"city":{"id":1,"name":"Yerevan","countryCode":"US"}}]"#)),
            .json(200, envelope(data: #"[{"city":{"id":9,"name":"Yerevan","countryCode":"AM"}}]"#)),
        ])

        let item = try await DivoGeoCityResolver.resolveCity(query: "Yerevan|||Armenia")

        XCTAssertEqual(item?.city?.id, 9)
        XCTAssertEqual(requests.count, 2)
    }

    func testFallsBackToWrongCountryItemWhenNothingBetter() async throws {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: #"[{"city":{"id":1,"name":"Yerevan","countryCode":"US"}}]"#)),
            .json(200, envelope(data: "[]")),
        ])

        let item = try await DivoGeoCityResolver.resolveCity(query: "Yerevan|||Armenia")

        XCTAssertEqual(item?.city?.id, 1)
        XCTAssertEqual(requests.count, 2)
    }

    func testRetriesWithoutDiacritics() async throws {
        StubURLProtocol.respondInOrder([
            .json(200, envelope(data: "[]")),
            .json(200, envelope(data: "[]")),
            .json(200, envelope(data: #"[{"city":{"id":5,"name":"Herat","countryCode":"AF"}}]"#)),
        ])

        let item = try await DivoGeoCityResolver.resolveCity(query: "Herāt|||Afghanistan")

        XCTAssertEqual(item?.city?.id, 5)
        XCTAssertEqual(requests.last?.url.query?.removingPercentEncoding, "query=Herat")
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
