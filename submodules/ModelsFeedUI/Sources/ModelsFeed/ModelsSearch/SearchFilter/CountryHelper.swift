//
//  CountryHelper.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Foundation
import DivoUIKit

struct CountryHelper {
    static func getAllCountries() -> [FilterOptionItem] {
        var countries: [FilterOptionItem] = []

        let preferredLocale = Locale.preferredLanguages.first ?? "en"
        let localizationLocale = Locale(identifier: preferredLocale)
        
        for regionCode in Locale.isoRegionCodes {
            if let countryName = localizationLocale.localizedString(forRegionCode: regionCode) {
                let flag = emojiFlag(for: regionCode)
                let title = "\(flag) \(countryName)"

                countries.append(FilterOptionItem(id: regionCode, title: title))
            }
        }

        return countries.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func emojiFlag(for countryCode: String?) -> String {
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
