import Foundation

/// Валидация значений полей формы. Чистая логика — без UI и без сайд-эффектов.
public enum FormValidator {

    public enum Issue: Equatable {
        case required(fieldKey: String)
        case tooShort(fieldKey: String, min: Int)
        case tooLong(fieldKey: String, max: Int)
        case malformedEmail(fieldKey: String)
        case malformedURL(fieldKey: String)
        case malformedPhone(fieldKey: String)
        case dateOutOfRange(fieldKey: String)
        case selectionRequired(fieldKey: String)
        case tooFewSelected(fieldKey: String, min: Int)
        case tooManySelected(fieldKey: String, max: Int)
    }

    /// Проверяет одно поле. Возвращает массив проблем — `[]` если поле валидно.
    public static func validate(field: FormField, value: FormFieldValue?) -> [Issue] {
        var issues: [Issue] = []

        // 1) Required-проверка. Пустые значения / nil — это required-фейл.
        let isPresent: Bool = {
            guard let v = value else { return false }
            return !v.isEmpty
        }()
        if field.isRequired && !isPresent {
            issues.append(.required(fieldKey: field.key))
            // Дальше остальные проверки не имеют смысла.
            return issues
        }
        guard let value = value, !value.isEmpty else { return issues }

        // 2) Проверки по типу поля.
        switch field.kind {
        case .text(let minLength, let maxLength),
             .multilineText(let minLength, let maxLength):
            if case .string(let s) = value {
                if let min = minLength, s.count < min { issues.append(.tooShort(fieldKey: field.key, min: min)) }
                if let max = maxLength, s.count > max { issues.append(.tooLong(fieldKey: field.key, max: max)) }
            }

        case .email:
            if case .string(let s) = value, !isValidEmail(s) {
                issues.append(.malformedEmail(fieldKey: field.key))
            }

        case .url(let scheme):
            if case .string(let s) = value {
                let isValid: Bool
                switch scheme {
                case .instagram, .anyLink:
                    // Поля «ссылка ИЛИ инстаграм-хэндл» (websiteOrInstagram у студии, instagramOrCasting):
                    // принимаем любой непустой ввод — хэндл вроде @studio/имя без точки валиден.
                    // Строгий разбор формата — на бэке (иначе UI режет корректные хэндлы).
                    isValid = isValidInstagramHandle(s)
                case .anyHttp:
                    isValid = isProbablyValidURL(s)
                }
                if !isValid {
                    issues.append(.malformedURL(fieldKey: field.key))
                }
            }

        case .phone:
            if case .string(let s) = value, !isProbablyValidPhone(s) {
                issues.append(.malformedPhone(fieldKey: field.key))
            }

        case .date(let minDate, let maxDate, _):
            if case .date(let d) = value {
                if let min = minDate, d < min { issues.append(.dateOutOfRange(fieldKey: field.key)) }
                if let max = maxDate, d > max { issues.append(.dateOutOfRange(fieldKey: field.key)) }
            }

        case .picker, .country, .city:
            // Required уже проверено выше; picker — это `.option`. Дополнительных проверок нет.
            break

        case .multiPicker(_, let minSelections, let maxSelections):
            if case .options(let arr) = value {
                if arr.count < minSelections { issues.append(.tooFewSelected(fieldKey: field.key, min: minSelections)) }
                if let max = maxSelections, arr.count > max { issues.append(.tooManySelected(fieldKey: field.key, max: max)) }
            }

        case .photo:
            // Required проверено выше; для непустого `.asset(...)` дополнительных проверок не делаем.
            break
        }

        return issues
    }

    /// Валидирует все обязательные поля шага. Удобно для разрешения Continue.
    public static func validate(step: FormStep, values: [String: FormFieldValue]) -> [Issue] {
        var allIssues: [Issue] = []
        for field in step.fields {
            allIssues.append(contentsOf: validate(field: field, value: values[field.key]))
        }
        return allIssues
    }

    public static func isStepValid(_ step: FormStep, values: [String: FormFieldValue]) -> Bool {
        return validate(step: step, values: values).isEmpty
    }

    // MARK: - Низкоуровневые проверки

    private static func isValidEmail(_ s: String) -> Bool {
        // Достаточная для онбординга проверка. Жёсткую — оставляем бэку.
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isProbablyValidURL(_ s: String) -> Bool {
        guard let url = URL(string: s) else { return false }
        return url.scheme != nil || s.contains(".")                     // допускаем "instagram.com/x" без https
    }

    /// Instagram-handle: на клиенте проверяем только non-empty. Точный формат
    /// (alphanumeric, длина, доступность handle) — забота бэка, иначе UI отвергает
    /// валидные ввода типа `@user.name`, кириллицу, имена с дефисами и т.п.
    private static func isValidInstagramHandle(_ s: String) -> Bool {
        return !s.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func isProbablyValidPhone(_ s: String) -> Bool {
        let digits = s.filter { $0.isNumber }
        return digits.count >= 7 && digits.count <= 15
    }
}
