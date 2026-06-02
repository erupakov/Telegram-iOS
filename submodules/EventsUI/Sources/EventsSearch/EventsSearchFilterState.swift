//
//  EventsSearchFilterState.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 29.05.2026.
//

import Foundation

public struct EventsSearchFilterState: Equatable {
    public var eventTypeIds: [Int] = []
    public var eventTypeTitles: [String] = []
    
    public var roleIds: [String] = []
    public var roleTitles: [String] = []

    public var genderIds: [String] = []
    public var genderTitles: [String] = []

    public var countryIds: [String] = []
    public var countryTitles: [String] = []

    public var city: String?
    
    public var isPaidOnly: Bool = false
    public var dateOfEventTimestamp: Int32?
    
    public var ageRange: ClosedRange<Int>?
    public var heightRange: ClosedRange<Double>?
    public var weightRange: ClosedRange<Double>?
    public var waistRange: ClosedRange<Double>?
    public var hipsRange: ClosedRange<Double>?
    public var shoeSizeRange: ClosedRange<Double>?
    public var breastSizeRange: ClosedRange<Double>?
    
    public var hairLength: [Int]?
    public var hairColor: [Int]?
    public var eyeColor: [Int]?
    public var skinColor: [Int]?

    /// Единый источник правды «какие поля считаются активным фильтром».
    /// Используется для подсчета количества активных параметров и разблокировки кнопки сброса.
    private var activeFieldFlags: [Bool] {
        [
            !roleIds.isEmpty,
            !genderIds.isEmpty,
            !eventTypeIds.isEmpty,
            !countryIds.isEmpty,
            !(city?.isEmpty ?? true),
            isPaidOnly == true, // Считаем активным фильтром, если включен тумблер "Paid only"
            dateOfEventTimestamp != nil,
            ageRange != nil,
            heightRange != nil,
            weightRange != nil,
            waistRange != nil,
            hipsRange != nil,
            shoeSizeRange != nil,
            breastSizeRange != nil,
            !(hairLength?.isEmpty ?? true),
            !(hairColor?.isEmpty ?? true),
            !(eyeColor?.isEmpty ?? true),
            !(skinColor?.isEmpty ?? true)
        ]
    }

    public var hasActiveFilters: Bool {
        activeFieldFlags.contains(true)
    }

    public var activeFilterCount: Int {
        activeFieldFlags.lazy.filter { $0 }.count
    }

    public mutating func reset() {
        roleIds = []
        roleTitles = []
        genderIds = []
        genderTitles = []
        eventTypeIds = []
        eventTypeTitles = []
        countryIds = []
        countryTitles = []
        city = nil
        
        isPaidOnly = false
        dateOfEventTimestamp = nil
        ageRange = nil
        heightRange = nil
        waistRange = nil
        weightRange = nil
        hipsRange = nil
        shoeSizeRange = nil
        breastSizeRange = nil
        hairLength = nil
        hairColor = nil
        eyeColor = nil
        skinColor = nil
    }
}
