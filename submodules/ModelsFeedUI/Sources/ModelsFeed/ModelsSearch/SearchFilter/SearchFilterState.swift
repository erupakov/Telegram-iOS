//
//  SearchFilterState.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Foundation
import TelegramCore

struct FilterOptionItem {
    let id: String
    let title: String
}

struct SearchFilterState {
    var roleIds: [String] = []
    var roleTitles: [String] = []

    var genderIds: [String] = []
    var genderTitles: [String] = []

    var countryIds: [String] = []
    var countryTitles: [String] = []

    var city: String?

    var hasActiveFilters: Bool {
        return !roleIds.isEmpty || !genderIds.isEmpty || !countryIds.isEmpty || !(city?.isEmpty ?? true)
    }

    mutating func reset() {
        roleIds = []
        roleTitles = []
        genderIds = []
        genderTitles = []
        countryIds = []
        countryTitles = []
        city = nil
    }

    var apiRoles: [String] {
        if !roleIds.isEmpty {
            return roleIds
        }
        return["model", "new_face", "agency_employee", "brand", "photographer", "stylist", "media", "place"]
    }

    var apiGenders: [String]? {
        if !genderIds.isEmpty {
            return genderIds
        }
        return nil
    }
    
    var apiCountries: [String]? {
        if !countryIds.isEmpty {
            return countryIds
        }
        return nil
    }
}
