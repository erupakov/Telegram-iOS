import Foundation

public struct DivoConsoleLogEntry {
    public let id: UUID
    public let timestamp: Date
    public let level: Level
    public let message: String
    public let file: String
    public let line: Int

    public enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
}

public final class DivoConsoleLogger {
    public static let shared = DivoConsoleLogger()
    public static let newEntryNotification = Notification.Name("DivoConsoleLoggerNewEntry")

    private var entries: [DivoConsoleLogEntry] = []
    private let queue = DispatchQueue(label: "com.divo.consoleLogger")
    private let maxEntries = 200

    private init() {
        // Lazy-register shake gesture observer — открывает logs viewer на любом экране.
        _ = DivoShakeGestureHandler.shared
        // DIVO: мост MTProto-диагностики на debug-экран. TelegramApi/MtProtoKit не могут
        // импортить DivoCore (цикл зависимостей), поэтому они постят "DivoMTProtoLog" через
        // NotificationCenter, а мы кладём это в логи — как Android-алерт "can't parse magic".
        NotificationCenter.default.addObserver(forName: Notification.Name("DivoMTProtoLog"), object: nil, queue: nil) { [weak self] note in
            if let msg = note.userInfo?["message"] as? String {
                // DIVO: трейсы MTProto (→ / OK ←) — это .info, не ошибки. Реальные проблемы
                // (RPC ERROR от сервера, can't parse magic = TL_PARSING_ERROR) остаются .error,
                // чтобы не тонули в шуме happy-path-трафика.
                let level: DivoConsoleLogEntry.Level =
                    (msg.contains("RPC ERROR") || msg.contains("can't parse")) ? .error : .info
                self?.log(msg, level: level, file: "MTProto", line: 0)
            }
        }
    }

    public func log(
        _ message: String,
        level: DivoConsoleLogEntry.Level = .debug,
        file: String = #file,
        line: Int = #line
    ) {
        let entry = DivoConsoleLogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            message: message,
            file: (file as NSString).lastPathComponent,
            line: line
        )
        queue.sync {
            entries.insert(entry, at: 0)
            if entries.count > maxEntries {
                entries.removeLast()
            }
        }
        print("[\(entry.level.rawValue)] \(entry.file):\(entry.line) — \(message)")
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: DivoConsoleLogger.newEntryNotification,
                object: entry
            )
        }
    }

    public func getEntries() -> [DivoConsoleLogEntry] {
        return queue.sync { entries }
    }

    public func clear() {
        queue.sync { entries.removeAll() }
    }
}

public func divoLog(
    _ message: String,
    level: DivoConsoleLogEntry.Level = .debug,
    file: String = #file,
    line: Int = #line
) {
    // FIXME DIVO: временно без #if DEBUG для диагностики MTProto на opt-сборке.
    // Вернуть #if DEBUG после диагностики (см. ветку feature/PROJ-010-...).
    DivoConsoleLogger.shared.log(message, level: level, file: file, line: line)
}
