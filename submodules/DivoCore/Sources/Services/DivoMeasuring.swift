import Foundation

/// Система единиц юзера. Числа параметров внешности храним и шлём на сервер всегда
/// в метрике (cm/kg, обувь — EU-шкала); конвертация делается только на показе и вводе.
public enum DivoMeasuringSystem: String {
    case metric
    case imperial

    /// Дефолт для юзера без настройки — по локали устройства (как у Android).
    public static var localeDefault: DivoMeasuringSystem {
        Locale.current.usesMetricSystem ? .metric : .imperial
    }

    /// Текущая система: кэш top-level `measuringSystem` из `/user/info`, иначе локаль.
    public static var current: DivoMeasuringSystem {
        if let raw = UserDefaults.standard.string(forKey: cacheKey),
           let system = DivoMeasuringSystem(rawValue: raw) {
            return system
        }
        return localeDefault
    }

    /// Обновить кэш по ответу `/user/info` или после смены настройки.
    /// `nil`/незнакомое значение сбрасывает кэш — вернёмся к локали.
    public static func updateCurrent(_ rawValue: String?) {
        if let system = rawValue.flatMap(DivoMeasuringSystem.init(rawValue:)) {
            UserDefaults.standard.set(system.rawValue, forKey: cacheKey)
        } else {
            UserDefaults.standard.removeObject(forKey: cacheKey)
        }
    }

    private static let cacheKey = "divoMeasuringSystem"
}

/// Числовой параметр внешности с единицей измерения.
public enum DivoMeasureKind {
    case height
    case weight
    case waist
    case hips
    case shoeSize
}

/// Конвертация и форматирование параметров внешности под систему единиц.
/// Работает на границе UI: внутрь экранов и в запросы числа идут метрическими.
public enum DivoMeasuring {

    private static let cmPerInch = 2.54
    private static let lbPerKg = 2.20462
    // Юнисекс-сдвиг EU→US: «самый маленький и самый большой, на пол не смотрим» —
    // EU 34–48 → US 2–16 (низ мужской шкалы, верх женской); бренды сами гуляют на ±1
    private static let usShoeOffset = 32.0

    // MARK: - Конвертация

    /// Метрическое значение → число в единицах `system` (целое — под слайдеры и поля ввода).
    public static func displayValue(metric: Double, kind: DivoMeasureKind, system: DivoMeasuringSystem = .current) -> Double {
        guard system == .imperial else { return metric }
        switch kind {
        case .height, .waist, .hips: return (metric / cmPerInch).rounded()
        case .weight: return (metric * lbPerKg).rounded()
        // Сдвиг шкалы без округления — полуразмеры сохраняются; кламп к US 1 прячет
        // старые записи EU 30–33 (детские размеры, взрослого US-числа у них нет)
        case .shoeSize: return Swift.max(metric - usShoeOffset, 1)
        }
    }

    /// Число из UI в единицах `system` → целое метрическое (для отправки и хранения).
    public static func metricValue(display: Double, kind: DivoMeasureKind, system: DivoMeasuringSystem = .current) -> Double {
        guard system == .imperial else { return display }
        switch kind {
        case .height, .waist, .hips: return (display * cmPerInch).rounded()
        case .weight: return (display / lbPerKg).rounded()
        case .shoeSize: return display + usShoeOffset
        }
    }

    /// Значение из ответа сервера → метрическое. Маркер `measuringSystem` источника
    /// говорит, в каких единицах записаны числа: чужие записи могут быть в imperial.
    public static func normalizedMetric(_ value: Double, sourceSystem: String?, kind: DivoMeasureKind) -> Double {
        // Обувь на проводе всегда в EU независимо от маркера — US-шкала живёт только на показе
        guard kind != .shoeSize else { return value }
        let source = sourceSystem.flatMap(DivoMeasuringSystem.init(rawValue:)) ?? .metric
        return metricValue(display: value, kind: kind, system: source)
    }

    // MARK: - Показ

    /// Значение для показа: «170», «92.5»; рост в imperial — «5'7"».
    public static func valueString(metric: Double, kind: DivoMeasureKind, system: DivoMeasuringSystem = .current) -> String {
        let display = displayValue(metric: metric, kind: kind, system: system)
        if system == .imperial && kind == .height {
            let totalInches = Int(display)
            return "\(totalInches / 12)'\(totalInches % 12)\""
        }
        return plain(display)
    }

    /// Значение с единицей: «170 cm», «154 lb»; рост в imperial — «5'7"» без суффикса.
    public static func valueWithUnit(metric: Double, kind: DivoMeasureKind, system: DivoMeasuringSystem = .current) -> String {
        let value = valueString(metric: metric, kind: kind, system: system)
        if system == .imperial && kind == .height { return value }
        return "\(value) \(unit(kind: kind, system: system))"
    }

    /// Диапазон «от–до» (требования эвента, строки фильтров): «150-200», «4'11"-6'7"».
    /// Значения на входе — уже метрические (чужие предварительно через `normalizedMetric`).
    public static func rangeString(fromMetric: Double?, toMetric: Double?, kind: DivoMeasureKind, system: DivoMeasuringSystem = .current) -> String? {
        let from = fromMetric.map { valueString(metric: $0, kind: kind, system: system) }
        let to = toMetric.map { valueString(metric: $0, kind: kind, system: system) }
        switch (from, to) {
        case let (from?, to?): return from == to ? from : "\(from)-\(to)"
        case let (from?, nil): return from
        case let (nil, to?): return to
        default: return nil
        }
    }

    // MARK: - Подписи

    /// Заголовок параметра для строк показа: «Height (cm)» / «Height (ft/in)».
    public static func title(kind: DivoMeasureKind, system: DivoMeasuringSystem = .current) -> String {
        switch (kind, system) {
        case (.height, .metric): return DivoStrings.heightCm
        case (.height, .imperial): return DivoStrings.heightFtIn
        case (.weight, .metric): return DivoStrings.weightKg
        case (.weight, .imperial): return DivoStrings.weightLb
        case (.waist, .metric): return DivoStrings.waistCm
        case (.waist, .imperial): return DivoStrings.waistIn
        case (.hips, .metric): return DivoStrings.hipsCm
        case (.hips, .imperial): return DivoStrings.hipsIn
        case (.shoeSize, .metric): return DivoStrings.shoeSizeEU
        case (.shoeSize, .imperial): return DivoStrings.shoeSizeUS
        }
    }

    /// Заголовок для экрана ввода. Отличается только ростом: в пикере число в дюймах,
    /// поэтому «Height (in)», а не «(ft/in)».
    public static func inputTitle(kind: DivoMeasureKind, system: DivoMeasuringSystem = .current) -> String {
        if system == .imperial && kind == .height { return DivoStrings.heightIn }
        return title(kind: kind, system: system)
    }

    /// Короткая единица: «cm»/«in», «kg»/«lb», рост в imperial — «ft/in», обувь — «EU».
    public static func unit(kind: DivoMeasureKind, system: DivoMeasuringSystem = .current) -> String {
        switch (kind, system) {
        case (.height, .metric), (.waist, .metric), (.hips, .metric): return DivoStrings.unitCm
        case (.height, .imperial): return DivoStrings.unitFtIn
        case (.waist, .imperial), (.hips, .imperial): return DivoStrings.unitIn
        case (.weight, .metric): return DivoStrings.unitKg
        case (.weight, .imperial): return DivoStrings.unitLb
        case (.shoeSize, .metric): return DivoStrings.unitEU
        case (.shoeSize, .imperial): return DivoStrings.unitUS
        }
    }

    private static func plain(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : "\(value)"
    }
}
