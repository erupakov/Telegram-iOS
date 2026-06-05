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
        static let slowImageLoading = "DivoDebugFlags.slowImageLoading"
        static let forceImagePlaceholders = "DivoDebugFlags.forceImagePlaceholders"
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

    /// Задерживает выдачу картинок в `ImageLoader` (~2с), чтобы успеть рассмотреть шиммер.
    /// Действует и на кэш — иначе повторная загрузка мгновенна и шиммера не видно.
    public static var slowImageLoading: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.slowImageLoading) }
        set {
            let oldValue = slowImageLoading
            UserDefaults.standard.set(newValue, forKey: Keys.slowImageLoading)
            if newValue != oldValue {
                NotificationCenter.default.post(name: didChangeNotification, object: nil)
            }
        }
    }

    /// Заставляет `loadImage` сразу показывать placeholder, минуя сеть — чтобы проверить
    /// пустые состояния (заглушки) без отключения интернета и чистки кэша.
    public static var forceImagePlaceholders: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.forceImagePlaceholders) }
        set {
            let oldValue = forceImagePlaceholders
            UserDefaults.standard.set(newValue, forKey: Keys.forceImagePlaceholders)
            if newValue != oldValue {
                NotificationCenter.default.post(name: didChangeNotification, object: nil)
            }
        }
    }
}
