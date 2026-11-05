import Foundation

/// Поле `errors` в конверте ответа DIVO REST `{message, data, errors}`. По контракту бэка это `null`
/// или JSON-объект (`{"field": ["текст", …]}` при 422), строкой не бывает. Раньше модели описывали
/// его как `String?` / `[String]?` — объект в успешном ответе ронял декодирование, и успех выглядел
/// ошибкой. Тип принимает любую форму и ничего не теряет; текст для пользователя — в `message`.
public struct DivoResponseErrors: Decodable, Equatable {
    /// Ошибки по полям: объект `{"field": ["…"]}`; массив/строка — под ключом `""`.
    public let fields: [String: [String]]

    public init(fields: [String: [String]] = [:]) {
        self.fields = fields
    }

    /// Ошибок нет (`null`, `{}`, `[]`, пустая строка).
    public var isEmpty: Bool {
        return fields.values.allSatisfy { $0.isEmpty }
    }

    /// Все тексты ошибок одним списком (порядок полей — по ключу, чтобы сообщение было стабильным).
    public var messages: [String] {
        return fields.keys.sorted().flatMap { fields[$0] ?? [] }
    }

    /// Первый текст ошибки (для логов / запасного сообщения).
    public var firstMessage: String? {
        return fields.values.lazy.compactMap { $0.first }.first
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.fields = [:]
        } else if let object = try? container.decode([String: DivoErrorMessages].self) {
            self.fields = object.mapValues(\.messages)
        } else if let array = try? container.decode([String].self) {
            self.fields = array.isEmpty ? [:] : ["": array]
        } else if let string = try? container.decode(String.self) {
            self.fields = string.isEmpty ? [:] : ["": [string]]
        } else {
            // Незнакомая форма — не валим ответ из-за служебного поля.
            self.fields = [:]
        }
    }
}

/// Значение поля в `errors`: обычно массив строк, но допускаем и одиночную строку.
private struct DivoErrorMessages: Decodable {
    let messages: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([String].self) {
            self.messages = array
        } else if let string = try? container.decode(String.self) {
            self.messages = [string]
        } else {
            self.messages = []
        }
    }
}
