import Foundation

/// Произвольное JSON-значение для отправки «как есть» (например, `additionalInfo` при регистрации —
/// бэк хранит его как unstructured JSON-объект). Encodable; строится из нетипизированного
/// `[String: Any]`, который отдаёт `FormSerializer.payload` онбординга.
public enum DivoJSONValue: Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([DivoJSONValue])
    case object([String: DivoJSONValue])
    case null

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    /// Конвертация из нетипизированного JSON-значения (`Any`).
    public static func from(_ value: Any) -> DivoJSONValue {
        switch value {
        case let value as DivoJSONValue: return value
        case let value as String: return .string(value)
        case let value as Bool: return .bool(value) // Bool ДО Int: важно для NSNumber-bridging
        case let value as Int: return .int(value)
        case let value as Double: return .double(value)
        case let value as [Any]: return .array(value.map(DivoJSONValue.from))
        case let value as [String: Any]: return .object(value.mapValues(DivoJSONValue.from))
        default: return .null
        }
    }

    /// Билд объекта additionalInfo из `[String: Any]` (payload онбординга).
    public static func object(from dict: [String: Any]) -> [String: DivoJSONValue] {
        dict.mapValues(DivoJSONValue.from)
    }
}
