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

    /// Плоский профиль под контракт бэка (как шлёт Android): все поля верхнего уровня, camelCase.
    /// Мапит наши form-ключи в ключи Android и добивает деривативами (fullName/phone/email/timezone).
    ///
    /// НЕ кладёт: `photoUuid`/`photoUrl` (нужен upload фото в storage — отдельный шаг, у нас пока только
    /// локальный путь) и `subRole`/`subrole` (семантика не подтверждена, по контракту subrole=null).
    /// Слитые в одно поле инстаграм/портфолио/кастинг кладём в `instagramUrl` (приоритет — instagram).
    public static func registrationProfile(
        state: OnboardingRegistrationState,
        registry: OnboardingRoleRegistry,
        phone: String?,
        email: String?,
        photoUuid: String? = nil,
        photoUrl: String? = nil
    ) -> [String: Any] {
        var out: [String: Any] = [:]

        let values: [String: FormFieldValue] = state.selectedRoleId
            .flatMap { registry.definition(for: $0)?.formId }
            .flatMap { state.formValues[$0.rawValue] } ?? [:]

        func string(_ key: String) -> String? {
            switch values[key] {
            case let .string(s)?: return s.isEmpty ? nil : s
            case let .option(s)?: return s.isEmpty ? nil : s
            default: return nil
            }
        }
        func dateString(_ key: String) -> String? {
            guard case let .date(d)? = values[key] else { return nil }
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: d)
        }

        // Имя
        let firstName = string("firstName")
        let lastName = string("lastName")
        if let firstName { out["firstName"] = firstName }
        if let lastName { out["lastName"] = lastName }
        let fullName = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        if !fullName.isEmpty { out["fullName"] = fullName }

        if let dob = dateString("dateOfBirth") { out["dateOfBirth"] = dob }
        if let gender = string("gender") { out["gender"] = gender }
        // Город хранится как резолвнутый geoCityId (числовой) — канонический ключ во всём приложении.
        if let geoCityId = string("city").flatMap({ Int($0) }) { out["geoCityId"] = geoCityId }

        // Страна: храним ISO regionCode (CountryHelper.id) → countryCode + локализованное имя.
        if let code = string("country") {
            out["countryCode"] = code
            let locale = Locale(identifier: Locale.preferredLanguages.first ?? "en")
            if let name = locale.localizedString(forRegionCode: code) { out["country"] = name }
        }

        // Компании / студия
        if let v = string("companyName") ?? string("studioName") { out["companyName"] = v }
        if let v = string("websiteUrl") ?? string("websiteOrInstagram") { out["websiteUrl"] = v }
        if let v = string("contactRole") { out["contactRole"] = v }
        let contactName = [string("contactFirstName"), string("contactLastName")].compactMap { $0 }.joined(separator: " ")
        if let v = string("contactName") ?? (contactName.isEmpty ? nil : contactName) { out["contactName"] = v }
        if let v = string("contactPhoneOrEmail") { out["contactPhone"] = v }

        // Talent / Creative
        if let v = string("specialisation") { out["specialisation"] = v }
        if let v = string("agencyName") ?? string("agency") ?? string("currentAgency") { out["agencyName"] = v }
        if let v = string("instagramHandle") ?? string("instagramOrPortfolio") ?? string("instagramOrCasting") { out["instagramUrl"] = v }
        if let v = string("showreelUrl") { out["showreelUrl"] = v }

        // Фото — uuid/url из заранее выполненного аплоада (см. photoAssetPath + submit-сервис).
        if let photoUuid { out["photoUuid"] = photoUuid }
        if let photoUrl { out["photoUrl"] = photoUrl }

        // Деривативы / auth-зеркала (как у Android)
        if let phone { out["phone"] = phone }
        if let email { out["email"] = email }
        out["timezone"] = TimeZone.current.identifier
        out["measuringSystem"] = "metric"

        return out
    }

    /// Локальный путь к фото выбранной роли (`profilePhoto`/`logo`/`mainSpacePhoto` — `.asset`).
    /// Submit-сервис грузит его в `/file/upload-file` ДО регистрации и кладёт uuid/url в профиль.
    public static func photoAssetPath(
        state: OnboardingRegistrationState,
        registry: OnboardingRoleRegistry
    ) -> String? {
        let values: [String: FormFieldValue] = state.selectedRoleId
            .flatMap { registry.definition(for: $0)?.formId }
            .flatMap { state.formValues[$0.rawValue] } ?? [:]
        for key in ["profilePhoto", "logo", "mainSpacePhoto"] {
            if case let .asset(path)? = values[key], !path.isEmpty {
                return path
            }
        }
        return nil
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
