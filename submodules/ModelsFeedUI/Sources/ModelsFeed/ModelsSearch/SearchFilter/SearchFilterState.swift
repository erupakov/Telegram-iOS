//
//  SearchFilterState.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Foundation
import DivoCore

struct FilterOptionItem {
    let id: String
    let title: String
}

struct FilterOptionApperanceItem {
    let id: Int
    let title: String
}

struct SearchFilterState: Equatable {
    var roleIds: [String] = []
    var roleTitles: [String] = []

    var genderIds: [String] = []
    var genderTitles: [String] = []

    var countryIds: [String] = []
    var countryTitles: [String] = []

    var city: String?
    
    var ageRange: ClosedRange<Int>?
    var heightRange: ClosedRange<Double>?
    var weightRange: ClosedRange<Double>?
    var waistRange: ClosedRange<Double>?
    var hipsRange: ClosedRange<Double>?
    var shoeSizeRange: ClosedRange<Double>?
    var hairLength: [Int]?
    var hairColor: [Int]?
    var eyeColor: [Int]?
    var skinColor: [Int]?

    var hasActiveFilters: Bool {
        return !roleIds.isEmpty || !genderIds.isEmpty || !countryIds.isEmpty ||
               !(city?.isEmpty ?? true) || ageRange != nil ||
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
        ageRange = nil
        heightRange = nil
        weightRange = nil
        waistRange = nil
        hipsRange = nil
        shoeSizeRange = nil
        hairLength = nil
        hairColor = nil
        eyeColor = nil
        skinColor = nil
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
    
    var activeFilterCount: Int {
        var count = 0
        
        if !roleIds.isEmpty { count += 1 }
        if !genderIds.isEmpty { count += 1 }
        
        if !countryIds.isEmpty { count += 1 }
        if let city = city, !city.isEmpty { count += 1 }
        
        if ageRange != nil { count += 1 }
        if heightRange != nil { count += 1 }
        if weightRange != nil { count += 1 }
        if waistRange != nil { count += 1 }
        if hipsRange != nil { count += 1 }
        if shoeSizeRange != nil { count += 1 }
        if hairLength != nil { count += 1 }
        if hairColor != nil { count += 1 }
        if eyeColor != nil { count += 1 }
        if skinColor != nil { count += 1 }
        
        return count
    }
}
