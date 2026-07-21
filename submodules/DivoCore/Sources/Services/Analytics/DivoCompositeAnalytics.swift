import Foundation

/// Композит-приёмник аналитики: раздаёт каждое событие нескольким `DivoAnalytics`.
/// Нужен, когда поверх основного приёмника (Firebase) вешаем дополнительный
/// (Facebook/Meta, DIVI-62). Сам приёмники не фильтрует — каждый решает, что писать.
public final class DivoCompositeAnalytics: DivoAnalytics {
    private let sinks: [DivoAnalytics]

    public init(_ sinks: [DivoAnalytics]) {
        self.sinks = sinks
    }

    public func log(name: String, parameters: [String: Any]) {
        for sink in sinks {
            sink.log(name: name, parameters: parameters)
        }
    }

    public func setScreen(name: String) {
        for sink in sinks {
            sink.setScreen(name: name)
        }
    }
}
