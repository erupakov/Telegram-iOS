import Foundation

/// Сопоставление города из подсказки Apple Maps (`MKLocalSearchCompletion`, id вида "title|||subtitle")
/// с базой городов бэка (`GET /geo/search-by-address-name`).
///
/// Раньше каждый экран брал строго `data.first` ответа и требовал у него `city.id`, а запрос собирал
/// как `parts.joined(", ")`. Из-за этого:
/// - пустой subtitle давал хвост ", " («Гонконг, ») и бэк ничего не находил;
/// - если первым результатом приходил адрес без города (страна/регион), город не находился,
///   даже когда он был дальше в списке.
/// Теперь запрос чистится, берётся первый результат с `city.id`, а если полный запрос
/// («Гонконг, САР Китая») не дал города — повторяем по одному названию города.
public enum DivoGeoCityResolver {
    /// Варианты запроса по убыванию точности: «город, регион/страна» → «город».
    public static func queryCandidates(for rawQuery: String) -> [String] {
        let parts = rawQuery
            .replacingOccurrences(of: "|||", with: ",")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let first = parts.first else { return [] }
        var candidates = [parts.joined(separator: ", ")]
        if parts.count > 1 {
            candidates.append(first)
        }
        return candidates
    }

    /// Первый результат с городом из базы бэка или nil, если ни один вариант запроса города не дал.
    /// Сетевые ошибки пробрасываются — экран показывает их отдельно от «город не найден».
    public static func resolveCity(query rawQuery: String) async throws -> GeoAddressItem? {
        for query in queryCandidates(for: rawQuery) {
            let response: GeoSearchResponse = try await DivoAPIClient.shared.request(
                path: "/geo/search-by-address-name?query=\(query.divoURLQueryEncoded)",
                method: "GET"
            )
            if let item = response.data?.first(where: { $0.city?.id != nil }) {
                return item
            }
        }
        return nil
    }
}
