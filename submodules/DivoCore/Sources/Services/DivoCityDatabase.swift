import Foundation

/// Город из локальной базы (GeoNames, файл `divo_cities.txt` — тот же `cities.txt`, что в Android-клиенте).
public struct DivoLocalCity: Equatable {
    public let id: Int64
    public let name: String
    public let asciiName: String
    /// Альтернативные названия через запятую (без языковых тегов).
    public let alternateNames: String
    /// ISO 3166-1 alpha-2.
    public let countryCode: String
    public let population: Int
    /// GeoNames admin1: у США — штат («NJ»), в остальных странах часто число. Отличает одноимённые города.
    public let adminCode: String
    /// Русское название по языковым меткам GeoNames («Дубай», а не сербское «Дубаи»); пусто, если у GeoNames нет.
    public let ruName: String

    public init(id: Int64, name: String, asciiName: String, alternateNames: String, countryCode: String, population: Int, adminCode: String, ruName: String = "") {
        self.id = id
        self.name = name
        self.asciiName = asciiName
        self.alternateNames = alternateNames
        self.countryCode = countryCode
        self.population = population
        self.adminCode = adminCode
        self.ruName = ruName
    }
}

/// Поиск городов по локальной базе — один в один как в Android (`CityPickerSheet`): подстрока в названии,
/// ASCII-названии или альтернативных названиях, фильтр по странам, сначала самые крупные, не больше 50.
/// Не зависит от Apple Maps: для стран с редким покрытием (Армения, Афганистан) находятся и столицы.
///
/// Файл базы — колонки GeoNames через TAB: 0 id, 1 name, 2 asciiname, 3 alternatenames, 8 country code,
/// 10 admin1 code, 14 population, 19 — русское название (нет в старых версиях файла). Собирается скриптом
/// `Tools/divo/build_cities.py` Android-клиента; обновляется копированием его `cities.txt`.
public final class DivoCityDatabase {
    public static let shared = DivoCityDatabase(bundleResource: "divo_cities", fileExtension: "txt")

    private struct Entry {
        let city: DivoLocalCity
        /// name \u{1} asciiName \u{1} ruName \u{1} alternateNames в нижнем регистре: одно сканирование вместо четырёх.
        let key: String
    }

    private let queue = DispatchQueue(label: "divo.city-database", qos: .userInitiated)
    private let loader: () -> Data?
    // Состояние — только из `queue`.
    private var entries: [Entry]?
    private var indicesByCountry: [String: [Int]] = [:]

    private convenience init(bundleResource: String, fileExtension: String) {
        self.init(loader: {
            guard let url = Bundle.main.url(forResource: bundleResource, withExtension: fileExtension) else { return nil }
            return try? Data(contentsOf: url, options: .mappedIfSafe)
        })
    }

    /// Для тестов: источник данных передаётся снаружи.
    public init(loader: @escaping () -> Data?) {
        self.loader = loader
    }

    // MARK: - Загрузка

    /// Разогреть индекс заранее (например, при открытии экрана): разбор ~8 МБ занимает доли секунды.
    public func preload() {
        queue.async { [weak self] in
            _ = self?.ensureLoaded()
        }
    }

    /// false — файл базы не найден/не разобран (тогда поиск вернёт пусто).
    private func ensureLoaded() -> Bool {
        if entries != nil { return true }
        guard let data = loader() else { return false }
        let cities = Self.parse(data: data)
        guard !cities.isEmpty else { return false }

        var parsed: [Entry] = []
        parsed.reserveCapacity(cities.count)
        var byCountry: [String: [Int]] = [:]
        for (index, city) in cities.enumerated() {
            let key = [city.name, city.asciiName, city.ruName, city.alternateNames].joined(separator: "\u{1}").lowercased()
            parsed.append(Entry(city: city, key: key))
            byCountry[city.countryCode.uppercased(), default: []].append(index)
        }
        entries = parsed
        indicesByCountry = byCountry
        return true
    }

    // MARK: - Поиск

    /// Асинхронный поиск; `completion` — на главной очереди. `nil` — база недоступна.
    public func search(query: String, countryCode: String?, limit: Int = 50, completion: @escaping ([DivoLocalCity]?) -> Void) {
        queue.async { [weak self] in
            let result: [DivoLocalCity]?
            if let self = self, self.ensureLoaded() {
                result = self.searchLoaded(query: query, countryCode: countryCode, limit: limit)
            } else {
                result = nil
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Синхронный поиск (блокирует вызывающую очередь до загрузки базы) — для тестов и фоновых задач.
    public func searchSync(query: String, countryCode: String?, limit: Int = 50) -> [DivoLocalCity] {
        return queue.sync {
            guard ensureLoaded() else { return [] }
            return searchLoaded(query: query, countryCode: countryCode, limit: limit)
        }
    }

    private func searchLoaded(query rawQuery: String, countryCode: String?, limit: Int) -> [DivoLocalCity] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty, let entries = entries else { return [] }

        // (позиция в файле, город): при равном населении порядок как в файле (стабильно, как в Android).
        var matches: [(position: Int, city: DivoLocalCity)] = []
        func consider(_ index: Int) {
            if entries[index].key.contains(query) {
                matches.append((index, entries[index].city))
            }
        }

        if let countryCode = countryCode, !countryCode.isEmpty {
            for index in indicesByCountry[countryCode.uppercased()] ?? [] {
                consider(index)
            }
        } else {
            for index in entries.indices {
                consider(index)
            }
        }

        // Крупнейшие первыми: из нескольких одноимённых городов лидирует самый известный (как в Android).
        matches.sort { lhs, rhs in
            if lhs.city.population != rhs.city.population { return lhs.city.population > rhs.city.population }
            return lhs.position < rhs.position
        }
        return matches.prefix(limit).map { $0.city }
    }

    // MARK: - Разбор

    /// Разбор файла GeoNames. Строки с менее чем 15 колонками пропускаются; 20-я колонка (русское название)
    /// необязательна. Разбираем по байтам, не создавая объектов на каждую из ~1 млн колонок.
    public static func parse(data: Data) -> [DivoLocalCity] {
        var cities: [DivoLocalCity] = []
        cities.reserveCapacity(data.count / 200)

        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Void in
            let count = raw.count
            var tabs: [Int] = []
            tabs.reserveCapacity(24)

            func text(_ from: Int, _ to: Int) -> String {
                return String(decoding: raw[from ..< to], as: UTF8.self)
            }

            var lineStart = 0
            while lineStart < count {
                var lineEnd = lineStart
                tabs.removeAll(keepingCapacity: true)
                while lineEnd < count && raw[lineEnd] != 0x0A {
                    if raw[lineEnd] == 0x09 { tabs.append(lineEnd) }
                    lineEnd += 1
                }
                let next = lineEnd + 1
                if lineEnd > lineStart && raw[lineEnd - 1] == 0x0D { lineEnd -= 1 }   // CRLF

                // колонок на одну больше, чем табов
                if tabs.count >= 14 {
                    func column(_ index: Int) -> String {
                        let from = index == 0 ? lineStart : tabs[index - 1] + 1
                        let to = index < tabs.count ? tabs[index] : lineEnd
                        return from <= to ? text(from, to) : ""
                    }
                    if let id = Int64(column(0)) {
                        cities.append(DivoLocalCity(
                            id: id,
                            name: column(1),
                            asciiName: column(2),
                            alternateNames: column(3),
                            countryCode: column(8),
                            population: Int(column(14)) ?? 0,
                            adminCode: column(10),
                            ruName: tabs.count >= 19 ? column(19) : ""
                        ))
                    }
                }
                lineStart = next
            }
        }
        return cities
    }

    // MARK: - Название для показа

    /// Как показать найденный город: то название, по которому он нашёлся (как в Android). Если запрос
    /// кириллицей совпал с альтернативным названием — лучшее из кириллических («Ереван», а не «Эриван»).
    public static func displayName(for city: DivoLocalCity, query rawQuery: String) -> String {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return city.name }

        if city.name.lowercased().contains(query) { return city.name }
        if city.asciiName.lowercased().contains(query) { return city.asciiName }
        // Русское название по меткам GeoNames надёжнее выбора среди альтернативных без языка («Дубай», не «Дубаи»).
        if !city.ruName.isEmpty && city.ruName.lowercased().contains(query) { return city.ruName }

        if city.alternateNames.lowercased().contains(query) {
            let alternates = city.alternateNames.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let cyrillicMatches = alternates.filter { isCyrillicName($0) && $0.lowercased().contains(query) }
            if !cyrillicMatches.isEmpty {
                return bestCyrillicName(cyrillicMatches, query: query, asciiName: city.asciiName)
            }
            // Латинское альтернативное название — обычно старое или иностранное («Yunnanfu» для Куньмина):
            // показываем собственное название города.
            return city.name
        }
        return city.name
    }

    private static func isCyrillicName(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        for scalar in value.unicodeScalars {
            let code = scalar.value
            let isLetter = (code >= 0x0410 && code <= 0x044F) || code == 0x0401 || code == 0x0451
            let isSeparator = code == 0x2D || CharacterSet.whitespaces.contains(scalar)
            if !isLetter && !isSeparator {
                return false
            }
        }
        return true
    }

    /// Альтернативные названия GeoNames — без языковых тегов, с разговорными и иностранными формами
    /// («Челяба» для Челябинска, татарское «Казан»). Берём то, чья транслитерация ближе всего к официальному
    /// ASCII-названию, предпочитая начинающееся с запроса. Ничьи: дефис вместо пробела («Санкт-Петербург»),
    /// мягкий знак в конце («Казань»), без дореформенного «ъ».
    static func bestCyrillicName(_ candidates: [String], query: String, asciiName: String) -> String {
        let official = String(asciiName.lowercased().unicodeScalars.filter { $0.value >= 0x61 && $0.value <= 0x7A })
        var best: (name: String, score: Double)?
        for name in candidates {
            let lower = name.lowercased()
            let latin = String(transliterate(name).unicodeScalars.filter { $0.value >= 0x61 && $0.value <= 0x7A })
            var score = Double(levenshtein(latin, official))
            if !lower.hasPrefix(query) { score += 1000 }
            if name.contains(" ") { score += 0.5 }
            if lower.contains("ъ") { score += 2 }
            if lower.hasSuffix("ь") { score -= 0.5 }
            if best == nil || score < best!.score {
                best = (name, score)
            }
        }
        return best?.name ?? candidates[0]
    }

    private static let cyrillicToLatin: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e", "ж": "zh",
        "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o",
        "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "kh", "ц": "ts",
        "ч": "ch", "ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu",
        "я": "ya"
    ]

    private static func transliterate(_ text: String) -> String {
        return text.lowercased().map { cyrillicToLatin[$0] ?? String($0) }.joined()
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a.unicodeScalars)
        let b = Array(b.unicodeScalars)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0 ... b.count)
        for i in 1 ... a.count {
            var current = [Int](repeating: 0, count: b.count + 1)
            current[0] = i
            for j in 1 ... b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[b.count]
    }
}
