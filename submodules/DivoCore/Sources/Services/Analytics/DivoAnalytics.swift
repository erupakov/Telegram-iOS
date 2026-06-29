import Foundation

/// Абстракция аналитики DIVO. Конкретная реализация (Firebase) живёт в DivoFirebaseKit
/// и регистрируется в `DivoAnalyticsRegistry` на старте приложения — по тому же принципу,
/// что `DivoErrorReporterRegistry` и `DivoFeatureFlagsRegistry`. Так UI-модули зависят
/// только от DivoCore, а Firebase в них не протекает.
public protocol DivoAnalytics: AnyObject {
    func log(name: String, parameters: [String: Any])
    func setScreen(name: String)
}

public enum DivoAnalyticsRegistry {
    /// nil до старта (DivoFirebaseBootstrap) — в это время divoTrack/divoTrackScreen no-op.
    public static var current: DivoAnalytics?
}

public func divoTrack(_ event: DivoAnalyticsEvent) {
    DivoAnalyticsRegistry.current?.log(name: event.name, parameters: event.parameters)
}

public func divoTrackScreen(_ name: String) {
    DivoAnalyticsRegistry.current?.setScreen(name: name)
}
