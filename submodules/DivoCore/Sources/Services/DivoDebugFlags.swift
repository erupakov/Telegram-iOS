import Foundation

/// Централизованное хранилище debug-флагов DIVO.
///
/// Флаги переключаются из Debug Menu и хранятся в UserDefaults. Каждый флаг
/// по умолчанию выключен — то есть в release-сборке у обычного пользователя
/// ничего не активно. Используется на этапах разработки и для quick-доступа
/// к экранам, которые в реальном флоу появляются только при определённых условиях.
public enum DivoDebugFlags {

    public static let didChangeNotification = Notification.Name("DivoDebugFlags.didChange")

    private enum Keys {
        static let showOnboardingEntry = "DivoDebugFlags.showOnboardingEntry"
    }

    /// Показать ли row «Запустить онбординг (debug)» в DIVO Settings под логаутом.
    /// Используется чтобы быстро попадать на онбординг без прохождения авторизации.
    public static var showOnboardingEntry: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.showOnboardingEntry) }
        set {
            let oldValue = showOnboardingEntry
            UserDefaults.standard.set(newValue, forKey: Keys.showOnboardingEntry)
            if newValue != oldValue {
                NotificationCenter.default.post(name: didChangeNotification, object: nil)
            }
        }
    }
}
