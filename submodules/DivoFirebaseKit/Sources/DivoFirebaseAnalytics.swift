import Foundation
import DivoCore
import FirebaseAnalytics

/// Firebase-реализация `DivoAnalytics`. Регистрируется в `DivoAnalyticsRegistry` из
/// `DivoFirebaseBootstrap.configure()`. Шлёт в текущий проект (stage), включая dev/TF-сборки —
/// заказчик мониторит именно stage, поэтому по `isDebugEnabled` НЕ глушим.
public final class DivoFirebaseAnalytics: DivoAnalytics {
    public init() {}

    public func log(name: String, parameters: [String: Any]) {
        Analytics.logEvent(name, parameters: parameters.isEmpty ? nil : parameters)
    }

    public func setScreen(name: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: name
        ])
    }
}
