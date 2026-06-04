import Foundation
import DivoCore

public struct CountryHelper {
    public static func getAllCountries() -> [FilterOptionItem] {
        var countries: [FilterOptionItem] = []

        let localizationLocale = Locale(identifier: DivoStrings.current.rawValue)

        for regionCode in Locale.isoRegionCodes {
            if let countryName = localizationLocale.localizedString(forRegionCode: regionCode) {
                let flag = emojiFlag(for: regionCode)
                let title = "\(flag) \(countryName)"

                countries.append(FilterOptionItem(id: regionCode, title: title))
            }
        }

        return countries.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public static func emojiFlag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "" }
        let base: UInt32 = 127397
        var s = ""
        for v in code.uppercased().unicodeScalars {
            guard let scalar = UnicodeScalar(base + v.value) else { continue }
            s.unicodeScalars.append(scalar)
        }
        return s
    }
}
