import Foundation
import XCTest
@testable import DivoCore

/// DivoCityDatabase: разбор GeoNames-файла и поиск по локальной базе городов (как в Android).
final class DivoCityDatabaseTests: XCTestCase {

    /// Строка GeoNames: 19 колонок через TAB (нужны 0, 1, 2, 3, 8, 10, 14).
    private func row(id: Int, name: String, ascii: String? = nil, alternates: String = "", country: String, admin: String = "", population: Int) -> String {
        var columns = [String](repeating: "", count: 19)
        columns[0] = String(id)
        columns[1] = name
        columns[2] = ascii ?? name
        columns[3] = alternates
        columns[8] = country
        columns[10] = admin
        columns[14] = String(population)
        return columns.joined(separator: "\t")
    }

    private func database(_ rows: [String]) -> DivoCityDatabase {
        let data = Data(rows.joined(separator: "\n").utf8)
        return DivoCityDatabase(loader: { data })
    }

    private var sample: DivoCityDatabase {
        return database([
            row(id: 616052, name: "Yerevan", alternates: "Erevan,Ереван,Эривань,Ervan", country: "AM", population: 1_144_700),
            row(id: 616051, name: "Gyumri", alternates: "Гюмри,Александрополь", country: "AM", population: 121_976),
            row(id: 1138958, name: "Kabul", alternates: "Кабул,Kabol", country: "AF", population: 4_434_550),
            row(id: 5101798, name: "Newark", alternates: "", country: "US", admin: "NJ", population: 281_944),
            row(id: 4143861, name: "Newark", alternates: "", country: "US", admin: "OH", population: 49_934),
            row(id: 2641673, name: "Newark", alternates: "", country: "GB", admin: "ENG", population: 27_000),
        ])
    }

    // MARK: - Разбор

    func testParseSkipsShortAndBrokenRows() {
        let good = row(id: 1, name: "A", country: "AM", population: 5)
        let data = Data([good, "short\tline", "x\tname" + String(repeating: "\t", count: 16), ""].joined(separator: "\n").utf8)

        let cities = DivoCityDatabase.parse(data: data)

        XCTAssertEqual(cities.count, 1)
        XCTAssertEqual(cities.first?.id, 1)
        XCTAssertEqual(cities.first?.countryCode, "AM")
        XCTAssertEqual(cities.first?.population, 5)
    }

    // MARK: - Поиск

    func testFindsCapitalsOfSmallCountriesByCountryCode() {
        XCTAssertEqual(sample.searchSync(query: "Yerevan", countryCode: "AM").first?.name, "Yerevan")
        XCTAssertEqual(sample.searchSync(query: "kabul", countryCode: "AF").first?.name, "Kabul")
    }

    func testSearchByCyrillicAlternateName() {
        XCTAssertEqual(sample.searchSync(query: "ерев", countryCode: "AM").map { $0.name }, ["Yerevan"])
        XCTAssertEqual(sample.searchSync(query: "  КАБУЛ ", countryCode: nil).map { $0.name }, ["Kabul"])
    }

    func testCountryFilterExcludesOthersAndNilSearchesEverywhere() {
        XCTAssertTrue(sample.searchSync(query: "Kabul", countryCode: "AM").isEmpty)
        XCTAssertEqual(sample.searchSync(query: "newark", countryCode: nil).count, 3)
        XCTAssertEqual(sample.searchSync(query: "newark", countryCode: "us").count, 2)
    }

    func testResultsSortedByPopulationAndLimited() {
        let results = sample.searchSync(query: "newark", countryCode: nil)
        XCTAssertEqual(results.map { $0.adminCode }, ["NJ", "OH", "ENG"])
        XCTAssertEqual(sample.searchSync(query: "newark", countryCode: nil, limit: 2).count, 2)
    }

    func testEmptyQueryAndMissingDatabaseReturnNothing() {
        XCTAssertTrue(sample.searchSync(query: "   ", countryCode: "AM").isEmpty)
        XCTAssertTrue(DivoCityDatabase(loader: { nil }).searchSync(query: "Yerevan", countryCode: nil).isEmpty)
    }

    // MARK: - Название для показа

    func testDisplayNameFollowsTheQuery() throws {
        let yerevan = try XCTUnwrap(sample.searchSync(query: "Yerevan", countryCode: "AM").first)

        XCTAssertEqual(DivoCityDatabase.displayName(for: yerevan, query: "yer"), "Yerevan")
        XCTAssertEqual(DivoCityDatabase.displayName(for: yerevan, query: "ере"), "Ереван")
        // Латинский вариант из альтернативных — показываем собственное имя.
        XCTAssertEqual(DivoCityDatabase.displayName(for: yerevan, query: "erev"), "Yerevan")
        XCTAssertEqual(DivoCityDatabase.displayName(for: yerevan, query: ""), "Yerevan")
    }

    func testBestCyrillicNamePrefersOfficialForm() {
        XCTAssertEqual(DivoCityDatabase.bestCyrillicName(["Казан", "Казань"], query: "каз", asciiName: "Kazan"), "Казань")
        // Название, начинающееся с запроса, важнее более «точной» транслитерации.
        XCTAssertEqual(DivoCityDatabase.bestCyrillicName(["Эривань", "Ереван"], query: "ере", asciiName: "Yerevan"), "Ереван")
    }
}
