import Foundation

/// Сопоставление выбранного в пикере города с городом из базы бэка (`GET /geo/search-by-address-name`,
/// из ответа берётся `city.id`).
///
/// Пикер даёт ключ «название GeoNames|||страна (en)», экраны превращают его в строку «Yerevan, Armenia».
/// Бэкенд — геокодер со своим (ограниченным) справочником городов: нужного города в нём может не быть,
/// поэтому важно перебрать варианты запроса и не отбросить подходящий результат.
///
/// Порядок запросов (останавливаемся на первом подходящем):
/// 0. по id GeoNames (`?geonamesId=`): бэкенд импортировал тот же список городов (`geo:import-geonames`)
///    и отдаёт город без геокодера — основной путь; остальные шаги нужны, если город ещё не импортирован;
/// 1. «название» — как делает Android-клиент (`searchByAddressName(city.name)`);
/// 2. «название, страна» — различает одноимённые города разных стран;
/// 3. название без диакритики («Herāt» → «Herat»);
/// 4. русское и ASCII-название из локальной базы городов.
/// В ответе смотрим ВСЕ элементы, а не только первый (Android берёт `firstOrNull`): с известной страной
/// предпочитаем элемент, чей код страны совпал; если такого нет ни в одном ответе — берём первый с городом.
public enum DivoGeoCityResolver {
    /// id GeoNames выбранного города по локальной базе: точное название в стране, крупнейший первым
    /// (тот же порядок, что в пикере). Подменяется в тестах.
    static var geonamesIdLookup: (_ name: String, _ countryCode: String) -> Int64? = { name, countryCode in
        DivoCityDatabase.shared.searchSync(query: name, countryCode: countryCode, limit: 20)
            .first(where: { $0.name == name })?.id
    }

    private struct ParsedQuery {
        let name: String
        let countryName: String?
    }

    private static func parse(_ rawQuery: String) -> ParsedQuery? {
        let parts = rawQuery
            .replacingOccurrences(of: "|||", with: ",")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let name = parts.first else { return nil }
        return ParsedQuery(name: name, countryName: parts.count > 1 ? parts.last : nil)
    }

    /// Варианты запроса, чистые (без локальной базы): название → «название, страна» → название без диакритики.
    public static func queryCandidates(for rawQuery: String) -> [String] {
        guard let parsed = parse(rawQuery) else { return [] }
        var candidates = [parsed.name]
        if let country = parsed.countryName {
            candidates.append("\(parsed.name), \(country)")
        }
        if let folded = foldedName(parsed.name) {
            candidates.append(folded)
        }
        return candidates
    }

    /// Название без диакритики; nil, если не отличается от исходного.
    static func foldedName(_ name: String) -> String? {
        let folded = name.folding(options: [.diacriticInsensitive], locale: nil)
        return folded == name ? nil : folded
    }

    /// ISO-код страны по её названию (английскому или на языке приложения).
    static func countryCode(forName name: String) -> String? {
        let target = name.lowercased()
        let locales = [Locale(identifier: "en"), Locale(identifier: DivoStrings.current.rawValue)]
        for locale in locales {
            for code in Locale.isoRegionCodes {
                if locale.localizedString(forRegionCode: code)?.lowercased() == target {
                    return code
                }
            }
        }
        return nil
    }

    private static func itemCountryCode(_ item: GeoAddressItem) -> String? {
        let code = item.city?.countryCode ?? item.country?.code
        return code?.trimmingCharacters(in: .whitespaces).uppercased()
    }

    /// Элемент с городом: с известной страной — совпавший по коду страны (isMatch), иначе первый с городом.
    private static func pick(from items: [GeoAddressItem], expectedCountry: String?) -> (item: GeoAddressItem, isMatch: Bool)? {
        let withCity = items.filter { $0.city?.id != nil }
        if let expected = expectedCountry, let match = withCity.first(where: { itemCountryCode($0) == expected }) {
            return (match, true)
        }
        guard let first = withCity.first else { return nil }
        return (first, false)
    }

    /// Город из базы бэка или nil, если ни один вариант запроса города не дал («город не поддерживается»).
    /// Сетевые ошибки пробрасываются — экран показывает их отдельно.
    public static func resolveCity(query rawQuery: String) async throws -> GeoAddressItem? {
        guard let parsed = parse(rawQuery) else { return nil }
        let expectedCountry = parsed.countryName.flatMap { countryCode(forName: $0) }

        if let code = expectedCountry, let geonamesId = geonamesIdLookup(parsed.name, code) {
            let response: GeoSearchResponse = try await DivoAPIClient.shared.request(
                path: "/geo/search-by-address-name?geonamesId=\(geonamesId)",
                method: "GET"
            )
            if let item = (response.data ?? []).first(where: { $0.city?.id != nil }) {
                divoLog("[GEO] \"\(rawQuery)\": geonamesId=\(geonamesId) -> city \(item.city?.id ?? 0)")
                return item
            }
            divoLog("[GEO] \"\(rawQuery)\": geonamesId=\(geonamesId) не импортирован на бэкенде, ищем по названию", level: .error)
        }

        var candidates = queryCandidates(for: rawQuery)
        // Русское и ASCII-название из локальной базы: бэкенд-геокодер может знать город под другим именем.
        if let code = expectedCountry {
            let known = DivoCityDatabase.shared.searchSync(query: parsed.name, countryCode: code, limit: 5)
                .first(where: { $0.name == parsed.name })
            for extra in [known?.asciiName, known?.ruName] {
                if let extra = extra, !extra.isEmpty, !candidates.contains(extra) {
                    candidates.append(extra)
                }
            }
        }

        var weakMatch: GeoAddressItem?
        for query in candidates {
            let response: GeoSearchResponse = try await DivoAPIClient.shared.request(
                path: "/geo/search-by-address-name?query=\(query.divoURLQueryEncoded)",
                method: "GET"
            )
            let items = response.data ?? []
            let picked = pick(from: items, expectedCountry: expectedCountry)
            divoLog("[GEO] query=\"\(query)\" country=\(expectedCountry ?? "-") items=\(items.count) withCity=\(items.filter { $0.city?.id != nil }.count) picked=\(picked.map { "\($0.item.city?.id ?? 0)/\($0.item.city?.name ?? "")/\(itemCountryCode($0.item) ?? "-")" } ?? "none") match=\(picked?.isMatch ?? false)")

            guard let picked = picked else { continue }
            if expectedCountry == nil || picked.isMatch {
                return picked.item
            }
            if weakMatch == nil {
                weakMatch = picked.item
            }
        }
        if weakMatch != nil {
            divoLog("[GEO] \"\(rawQuery)\": страну не подтвердил ни один ответ — берём первый город без совпадения страны", level: .error)
        } else {
            divoLog("[GEO] \"\(rawQuery)\": бэкенд не вернул ни одного города по \(candidates.count) вариантам запроса", level: .error)
        }
        return weakMatch
    }
}
