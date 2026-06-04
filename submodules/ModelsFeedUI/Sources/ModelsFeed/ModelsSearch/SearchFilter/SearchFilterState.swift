//
//  SearchFilterState.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Foundation
import DivoCore
import DivoUIKit

struct SearchFilterState: Equatable {
    var roleIds: [String] = []
    var roleTitles: [String] = []

    var genderIds: [String] = []
    var genderTitles: [String] = []

    var countryIds: [String] = []
    var countryTitles: [String] = []

    var cityId: Int?
    var cityTitle: String?
    var rawCityId: String?
    
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

    /// Единый источник правды «какие поля считаются активным фильтром».
    /// Пустая строка/массив/`nil` — не активны; непустое значение — активно.
    private var activeFieldFlags: [Bool] {
        [
            !roleIds.isEmpty,
            !genderIds.isEmpty,
            !countryIds.isEmpty,
            cityId != nil,
            ageRange != nil,
            heightRange != nil,
            weightRange != nil,
            waistRange != nil,
            hipsRange != nil,
            shoeSizeRange != nil,
            !(hairLength?.isEmpty ?? true),
            !(hairColor?.isEmpty ?? true),
            !(eyeColor?.isEmpty ?? true),
            !(skinColor?.isEmpty ?? true)
        ]
    }

    var hasActiveFilters: Bool {
        activeFieldFlags.contains(true)
    }

    var activeFilterCount: Int {
        activeFieldFlags.lazy.filter { $0 }.count
    }

    mutating func reset() {
        roleIds = []
        roleTitles = []
        genderIds = []
        genderTitles = []
        countryIds = []
        countryTitles = []
        cityId = nil
        cityTitle = nil
        rawCityId = nil
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
        return ["model", "new_face", "agency_employee", "brand", "photographer", "stylist", "media", "place"]
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
