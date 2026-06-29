import Foundation

/// Мост чат-событий из Telegram-слоя. Telegram-модули (TelegramUI, ChatListUI) не импортят
/// DivoCore, поэтому они постят `NotificationCenter` с именем `DivoAnalyticsChatEvent` и
/// userInfo `["event": <имя события>, <параметры>...]`, а мы здесь пробрасываем это в аналитику.
/// Тот же приём, что и для диагностики `DivoMTProtoLog`.
public enum DivoChatAnalyticsBridge {
    public static let notificationName = Notification.Name("DivoAnalyticsChatEvent")
    private static var observer: NSObjectProtocol?

    /// Вызывается один раз на старте (из DivoFirebaseBootstrap). Идемпотентно.
    public static func install() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: nil) { note in
            guard let info = note.userInfo, let event = info["event"] as? String else { return }
            var parameters: [String: Any] = [:]
            for (key, value) in info {
                guard let key = key as? String, key != "event" else { continue }
                parameters[key] = value
            }
            DivoAnalyticsRegistry.current?.log(name: event, parameters: parameters)
        }
    }
}
