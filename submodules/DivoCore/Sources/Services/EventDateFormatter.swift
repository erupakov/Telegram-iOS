import Foundation

/// Утилита форматирования событийных дат для UI событий (EventsList, EventDetail).
///
/// Парсит ISO-строки от API в двух вариантах (`yyyy-MM-dd'T'HH:mm:ss` и `yyyy-MM-dd'T'HH:mm`),
/// допуская пробел вместо `T`. Возвращает локализованные строки через `DivoStrings.deadlineData`
/// и `DivoStrings.deadlineDataTime`.
public enum EventDateFormatter {

    /// Форматирует время до дедлайна заявки.
    ///
    /// - Если дедлайн уже прошёл или строка не парсится — возвращает `nil`.
    /// - Если до дедлайна больше 24 часов — `Deadline: MMM d` (локализованный).
    /// - Если меньше 24 часов — `Closes in 2h 15m` / `Closes in 30m`.
    public static func timeRemaining(deadline: String?) -> String? {
        guard let raw = deadline else { return nil }
        guard let date = parse(raw) else { return nil }

        let interval = date.timeIntervalSince(Date())
        guard interval > 0 else { return nil }

        if interval > 86_400 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: DivoStrings.current.rawValue)
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
            return DivoStrings.deadlineData(formatter.string(from: date))
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let body = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        return DivoStrings.deadlineDataTime(body)
    }

    private static func parse(_ raw: String) -> Date? {
        let normalized = raw.replacingOccurrences(of: " ", with: "T")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: normalized) { return date }

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: normalized)
    }
}
