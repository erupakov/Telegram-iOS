import Foundation
import DivoCore
import DivoUIKit

public struct FaceSearchFilterState: Equatable {
    public static let similaritySteps: [Double] = [0.30, 0.45, 0.60, 0.75, 0.85, 1.00]
    public static let defaultSimilarity: Double = 0.30

    private static let savedSimilarityKey = "FaceSearch.savedSimilarity"

    /// Процент совпадения, который человек последний раз выставил слайдером фильтра. С него стартует
    /// каждый новый поиск по фото; переживает перезапуск. Меняется ТОЛЬКО применённым изменением
    /// слайдера (см. FaceSearchResultsController.applyFilters) — авто-понижение при пустой выдаче
    /// (fallback) его не трогает. Невалидное/отсутствующее значение → `defaultSimilarity`.
    public static var savedSimilarity: Double {
        get {
            guard let value = UserDefaults.standard.object(forKey: savedSimilarityKey) as? Double,
                  similaritySteps.contains(value) else {
                return defaultSimilarity
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: savedSimilarityKey)
        }
    }

    public var similarity: Double = FaceSearchFilterState.defaultSimilarity

    public var roleIds: [String] = []
    public var roleTitles: [String] = []

    public var countryIds: [String] = []
    public var countryTitles: [String] = []

    /// Пол: id из /dictionary/gender (male/female/other). Пусто — любой.
    public var genderIds: [String] = []
    public var genderTitles: [String] = []

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
            !genderIds.isEmpty,
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
        genderIds = []
        genderTitles = []
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

    public var apiGenders: [String]? {
        genderIds.isEmpty ? nil : genderIds
    }

    /// Проходит ли результат FR по полу. Фильтр дублируется на клиенте: если /fr/search не учтёт
    /// параметр `gender`, выдача всё равно не покажет людей другого пола. Пол не указан → «other».
    public func matchesGender(_ gender: String?) -> Bool {
        guard !genderIds.isEmpty else { return true }
        let normalized = gender?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let value = (normalized == DivoGender.male || normalized == DivoGender.female) ? normalized : DivoGender.notSpecified
        return genderIds.contains(value)
    }

    public init() {}
}
