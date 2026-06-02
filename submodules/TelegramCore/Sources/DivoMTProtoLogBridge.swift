import Foundation

// DIVO: мост MTProto-диагностики на debug-экран без зависимости TelegramCore → DivoCore.
// Постит в тот же канал "DivoMTProtoLog", который слушает DivoConsoleLogger — как уже делают
// TelegramApi/MtProtoKit. Так правки в DivoCore (модели/сервисы/строки) не пересобирают TelegramCore.
enum DivoMTProtoLogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

func divoMTProtoLog(_ message: String, level: DivoMTProtoLogLevel = .debug) {
    NotificationCenter.default.post(
        name: Notification.Name("DivoMTProtoLog"),
        object: nil,
        userInfo: ["message": message, "level": level.rawValue]
    )
}
