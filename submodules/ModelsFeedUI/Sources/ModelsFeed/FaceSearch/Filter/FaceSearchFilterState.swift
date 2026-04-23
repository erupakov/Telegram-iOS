import Foundation
import DivoCore
import DivoUIKit

struct FaceSearchFilterState: Equatable {
    static let similaritySteps: [Double] = [0.30, 0.45, 0.60, 0.75, 0.85, 1.00]
    static let defaultSimilarity: Double = 0.30

    var similarity: Double = FaceSearchFilterState.defaultSimilarity

    var roleIds: [String] = []
    var roleTitles: [String] = []

    var countryIds: [String] = []
    var countryTitles: [String] = []

    var ageRange: ClosedRange<Int>?
    var heightRange: ClosedRange<Double>?
    var waistRange: ClosedRange<Double>?
    var hipsRange: ClosedRange<Double>?
    var shoeSizeRange: ClosedRange<Double>?
    var hairLength: [Int]?

    private var activeFieldFlags: [Bool] {
        [
            similarity != FaceSearchFilterState.defaultSimilarity,
            !roleIds.isEmpty,
            !countryIds.isEmpty,
            ageRange != nil,
            heightRange != nil,
            waistRange != nil,
            hipsRange != nil,
            shoeSizeRange != nil,
            !(hairLength?.isEmpty ?? true)
        ]
    }

    var hasActiveFilters: Bool {
        activeFieldFlags.contains(true)
    }

    var activeFilterCount: Int {
        activeFieldFlags.lazy.filter { $0 }.count
    }

    mutating func reset() {
        similarity = FaceSearchFilterState.defaultSimilarity
        roleIds = []
        roleTitles = []
        countryIds = []
        countryTitles = []
        ageRange = nil
        heightRange = nil
        waistRange = nil
        hipsRange = nil
        shoeSizeRange = nil
        hairLength = nil
    }

    var apiRoles: [String]? {
        roleIds.isEmpty ? nil : roleIds
    }

    var apiCountries: [String]? {
        countryIds.isEmpty ? nil : countryIds
    }
}
