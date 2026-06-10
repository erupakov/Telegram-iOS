import Foundation

/// Утилиты для DIVO-телефонов.
public enum DivoPhone {
    /// ITU-код страны синтетического dummy-номера соц-входа (`/auth/dummy_phone`, `+9995…`).
    /// Код 999 не назначен ни одной стране → проверка по нему точная, реальный номер под неё не попадёт.
    /// ⚠️ Зеркалится в `TelegramCore/ApiUtils/TelegramUser.swift` (`divoDummyCountryCode`) — переиспользовать
    /// сам символ нельзя, TelegramCore не импортит DivoCore. Менять синхронно.
    public static let dummyCountryCode = "999"

    /// Синтетический dummy-номер соц-входа: начинается с `dummyCountryCode`.
    public static func isDummy(_ phone: String?) -> Bool {
        guard let phone else { return false }
        return phone.filter { $0.isNumber }.hasPrefix(dummyCountryCode)
    }
}
