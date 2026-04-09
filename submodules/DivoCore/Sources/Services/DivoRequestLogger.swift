import Foundation

public struct DivoRequestLogEntry {
    public let id: UUID
    public let timestamp: Date
    public let method: String
    public let path: String
    public let statusCode: Int?
    public let duration: TimeInterval
    public let requestBody: String?
    public let responseBody: String?
    public let error: String?

    public var isSuccess: Bool {
        guard let code = statusCode else { return false }
        return (200...299).contains(code)
    }
}

public final class DivoRequestLogger {
    public static let shared = DivoRequestLogger()
    public static let newEntryNotification = Notification.Name("DivoRequestLoggerNewEntry")

    private var entries: [DivoRequestLogEntry] = []
    private let queue = DispatchQueue(label: "com.divo.requestLogger")
    private let maxEntries = 100

    private init() {}

    public func log(
        method: String,
        path: String,
        statusCode: Int?,
        duration: TimeInterval,
        requestBody: String? = nil,
        responseBody: String? = nil,
        error: String? = nil
    ) {
        let entry = DivoRequestLogEntry(
            id: UUID(),
            timestamp: Date(),
            method: method,
            path: path,
            statusCode: statusCode,
            duration: duration,
            requestBody: requestBody,
            responseBody: responseBody,
            error: error
        )
        queue.sync {
            entries.insert(entry, at: 0)
            if entries.count > maxEntries {
                entries.removeLast()
            }
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: DivoRequestLogger.newEntryNotification,
                object: entry
            )
        }
    }

    public func getEntries() -> [DivoRequestLogEntry] {
        return queue.sync { entries }
    }

    public func clear() {
        queue.sync { entries.removeAll() }
    }
}
