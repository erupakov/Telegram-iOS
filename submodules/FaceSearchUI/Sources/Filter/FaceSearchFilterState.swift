import Foundation
import DivoCore
import DivoUIKit

public struct FaceSearchFilterState: Equatable {
    public static let similaritySteps: [Double] = [0.30, 0.45, 0.60, 0.75, 0.85, 1.00]
    public static let defaultSimilarity: Double = 0.30

    public var similarity: Double = FaceSearchFilterState.defaultSimilarity

    public var roleIds: [String] = []
    public var roleTitles: [String] = []

    public var countryIds: [String] = []
    public var countryTitles: [String] = []

    public var ageRange: ClosedRange<Int>?
    public var heightRange: ClosedRange<Double>?
    public var waistRange: ClosedRange<Double>?
    public var hipsRange: ClosedRange<Double>?
    public var shoeSizeRange: ClosedRange<Double>?
    public var hairLength: [Int]?

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

    public var hasActiveFilters: Bool {
        activeFieldFlags.contains(true)
    }

    public var activeFilterCount: Int {
        activeFieldFlags.lazy.filter { $0 }.count
    }

    public mutating func reset() {
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

    public var apiRoles: [String]? {
        roleIds.isEmpty ? nil : roleIds
    }

    public var apiCountries: [String]? {
        countryIds.isEmpty ? nil : countryIds
    }

    public init() {}
}
