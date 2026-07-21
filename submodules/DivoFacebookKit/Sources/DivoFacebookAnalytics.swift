import Foundation
import DivoCore
import FBSDKCoreKit

/// Facebook (Meta)-реализация `DivoAnalytics` (DIVI-62). Подключается вторым приёмником поверх
/// Firebase (композит, см. `DivoFacebookBootstrap`). В Meta по ТЗ уходят ТОЛЬКО три события
/// трекинга рекламных кампаний — всё остальное отсекается whitelist-ом ниже.
public final class DivoFacebookAnalytics: DivoAnalytics {
    public init() {}

    public func log(name: String, parameters: [String: Any]) {
        switch name {
        case "sign_up_start", "sign_up_complete":
            // По ТЗ эти события шлём без параметров.
            AppEvents.shared.logEvent(AppEvents.Name(name))
            divoLog("[Meta] событие отправлено: \(name)", level: .info)
        case "profile_media_uploaded":
            // ТЗ называет событие gallery_media_uploaded (Firebase-имя не трогаем, маппим только для Meta)
            // и ограничивает его фото/видео с единственным параметром media_type. background и
            // target_user_id в Meta не шлём.
            guard let mediaType = parameters["media_type"] as? String,
                  mediaType == "photo" || mediaType == "video" else {
                return
            }
            AppEvents.shared.logEvent(AppEvents.Name("gallery_media_uploaded"), parameters: [
                AppEvents.ParameterName("media_type"): mediaType
            ])
            divoLog("[Meta] событие отправлено: gallery_media_uploaded (media_type=\(mediaType))", level: .info)
        default:
            return
        }
    }

    public func setScreen(name: String) {
        // Экраны в Meta не трекаем — только событийная воронка рекламных кампаний.
    }
}
