import Foundation

/// Превращает заполненное состояние онбординга в JSON-структуру для отправки на бэк.
///
/// Структура простая и плоская — бэк когда-нибудь раскроет её до 25 ролей и подробного контракта,
/// сейчас мы просто докажем, что все собранные данные доходят до submit-сервиса.
public enum FormSerializer {

    public static func payload(
        state: OnboardingRegistrationState,
        registry: OnboardingRoleRegistry
    ) -> [String: Any] {
        var payload: [String: Any] = [:]

        if let roleId = state.selectedRoleId {
            payload["onboardingRoleId"] = roleId.rawValue
            if let def = registry.definition(for: roleId) {
                payload["backendRole"] = def.backendRoleRaw
                payload["formId"] = def.formId.rawValue
            }
        }

        if let topLevel = state.topLevelCategory {
            payload["topLevelCategory"] = topLevel.rawValue
        }

        if let door = state.industryDoor {
            payload["industryDoor"] = door.rawValue
        }

        if let hasExperience = state.hasModelingExperience {
            payload["hasModelingExperience"] = hasExperience
        }

        // Поля формы выбранной роли. Из других форм значения не шлём — могли быть набиты во время
        // экспериментов с другой ролью.
        if let formId = state.selectedRoleId.flatMap({ registry.definition(for: $0)?.formId }),
           let values = state.formValues[formId.rawValue] {
            payload["form"] = serialize(values: values)
        }

        return payload
    }

    private static func serialize(values: [String: FormFieldValue]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in values {
            switch value {
            case .string(let s): result[key] = s
            case .int(let i): result[key] = i
            case .bool(let b): result[key] = b
            case .date(let d): result[key] = ISO8601DateFormatter().string(from: d)
            case .option(let id): result[key] = id
            case .options(let arr): result[key] = arr
            case .asset(let id): result[key] = id
            case .empty: break
            }
        }
        return result
    }

    /// Удобный JSON-дамп для логирования в DivoConsoleLogger.
    public static func jsonString(
        state: OnboardingRegistrationState,
        registry: OnboardingRoleRegistry,
        prettyPrinted: Bool = true
    ) -> String {
        let dict = payload(state: state, registry: registry)
        let options: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: options),
              let str = String(data: data, encoding: .utf8) else {
            return "<failed to serialize>"
        }
        return str
    }
}
