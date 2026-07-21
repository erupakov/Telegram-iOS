import Foundation
import UIKit
import DivoCore
import FBSDKCoreKit

public enum DivoFacebookBootstrap {
    /// Инициализирует Facebook (Meta) SDK и вешает его вторым приёмником аналитики поверх Firebase
    /// (DIVI-62). Звать ПОСЛЕ `DivoFirebaseBootstrap.configure()` — иначе композит не подхватит
    /// уже зарегистрированный Firebase-приёмник.
    public static func configure(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !DivoFacebookConfig.clientToken.isEmpty else {
            // Без Client Token из Meta Events Manager сервер отклоняет события — SDK не инициализируем.
            // Заполнить DivoFacebookConfig.clientToken и пересобрать.
            divoLog("DivoFacebookBootstrap: clientToken пуст — Meta SDK не инициализирован (DIVI-62)", level: .info)
            return
        }

        Settings.shared.appID = DivoFacebookConfig.appID
        Settings.shared.clientToken = DivoFacebookConfig.clientToken
        Settings.shared.displayName = DivoFacebookConfig.displayName
        // Без ATT (вне ТЗ): только агрегированные события + SKAdNetwork, IDFA не собираем.
        Settings.shared.isAdvertiserTrackingEnabled = false
        Settings.shared.isAdvertiserIDCollectionEnabled = false
        Settings.shared.isAutoLogAppEventsEnabled = true
        // Verbose-лог FBSDK только в debug — по ТЗ debug-лог выключаем перед релизом.
        if DivoConfig.isDebugEnabled {
            Settings.shared.enableLoggingBehavior(.appEvents)
        }

        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        let facebook = DivoFacebookAnalytics()
        if let existing = DivoAnalyticsRegistry.current {
            DivoAnalyticsRegistry.current = DivoCompositeAnalytics([existing, facebook])
        } else {
            DivoAnalyticsRegistry.current = facebook
        }

        divoLog("Facebook (Meta) SDK configured, appID=\(DivoFacebookConfig.appID)", level: .info)
    }
}
