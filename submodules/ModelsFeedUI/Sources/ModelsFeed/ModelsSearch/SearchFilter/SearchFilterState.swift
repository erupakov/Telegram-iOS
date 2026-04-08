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

struct FilterOptionApperanceItem {
    let id: Int
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
    
    // Appearance filters
    var gender: String?
    var ageRange: ClosedRange<Double>?
    var heightRange: ClosedRange<Double>?
    var weightRange: ClosedRange<Double>?
    var waistRange: ClosedRange<Double>?
    var hipsRange: ClosedRange<Double>?
    var shoeSizeRange: ClosedRange<Double>?
    var hairLength: [String]?
    var hairColor: [String]?
    var eyeColor: [String]?
    var skinColor: [String]?

    var hasActiveFilters: Bool {
        return !roleIds.isEmpty || !genderIds.isEmpty || !countryIds.isEmpty ||
               !(city?.isEmpty ?? true) || !(gender?.isEmpty ?? true) || ageRange != nil ||
               heightRange != nil || weightRange != nil || waistRange != nil ||
               hipsRange != nil || shoeSizeRange != nil || !(hairLength?.isEmpty ?? true) ||
               !(hairColor?.isEmpty ?? true) || !(eyeColor?.isEmpty ?? true) || !(skinColor?.isEmpty ?? true)
    }

    mutating func reset() {
        roleIds = []
        roleTitles = []
        genderIds = []
        genderTitles = []
        countryIds = []
        countryTitles = []
        city = nil
        gender = nil
        ageRange = nil
        heightRange = nil
        weightRange = nil
        waistRange = nil
        hipsRange = nil
        shoeSizeRange = nil
        hairLength = []
        hairColor = []
        eyeColor = []
        skinColor = []
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
