import Foundation

/// Полное состояние регистрационного онбординга. Сериализуется в JSON и кладётся
/// в UserDefaults после каждого перехода — это даёт восстановление после крэша
/// или закрытия приложения посреди прохождения.
///
/// Тестовый запуск из настроек создаёт новое состояние (`forceFresh: true`),
/// реальный флоу — пытается восстановить незавершённый прогресс.
public struct OnboardingRegistrationState: Codable, Equatable {

    /// Выбор на самом первом экране (3 двери дизайна).
    public var topLevelCategory: OnboardingTopLevelCategory?

    /// «How do you work?» — только в ветке `lookingForTalent`.
    public var industryDoor: OnboardingIndustryDoor?

    /// Финальная подроль из 25. Является «осью» — от неё считается result-экран и форма.
    public var selectedRoleId: OnboardingRoleID?

    /// Ответ Question 2 of 2 квиза для Talent: есть ли опыт + агентство.
    /// `true` → роль `Model`, `false` → `New Talent`.
    public var hasModelingExperience: Bool?

    /// Значения полей форм Phase 4. Ключ — `OnboardingFormID`, внутри — `[fieldKey: value]`.
    /// Хранится отдельно для каждой формы, чтобы если юзер вернётся в Phase 3 и выберет
    /// другую роль/форму, прежний прогресс не пропал.
    public var formValues: [String: [String: FormFieldValue]]

    /// Шаг, на котором юзер сейчас находится.
    public var currentStep: OnboardingRegistrationStep

    public init(currentStep: OnboardingRegistrationStep = .topLevelChoice) {
        self.topLevelCategory = nil
        self.industryDoor = nil
        self.selectedRoleId = nil
        self.hasModelingExperience = nil
        self.formValues = [:]
        self.currentStep = currentStep
    }

    // MARK: - Convenience accessors

    public func value(forForm formId: OnboardingFormID, fieldKey: String) -> FormFieldValue? {
        return formValues[formId.rawValue]?[fieldKey]
    }

    public mutating func setValue(_ value: FormFieldValue, forForm formId: OnboardingFormID, fieldKey: String) {
        var formDict = formValues[formId.rawValue] ?? [:]
        formDict[fieldKey] = value
        formValues[formId.rawValue] = formDict
    }

    public mutating func clearForm(_ formId: OnboardingFormID) {
        formValues.removeValue(forKey: formId.rawValue)
    }

    /// Сбрасывает квиз-ответы, чтобы пользователь мог перевыбрать роль с нуля.
    public mutating func restartPhase3() {
        topLevelCategory = nil
        industryDoor = nil
        selectedRoleId = nil
        hasModelingExperience = nil
        currentStep = .topLevelChoice
    }
}

// MARK: - FormFieldValue

/// Универсальный контейнер значения поля формы. Сериализуется без потерь.
public enum FormFieldValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case date(Date)
    /// ID выбранной опции из picker'а.
    case option(String)
    /// ID-шники выбранных опций из multi-picker'а.
    case options([String])
    /// Загруженное фото / логотип — пока храним как identifier (path или asset id).
    /// На этапе скелета — просто непустая строка-флаг «фото загружено».
    case asset(String)
    case empty

    public var isEmpty: Bool {
        switch self {
        case .string(let s): return s.isEmpty
        case .options(let arr): return arr.isEmpty
        case .empty: return true
        default: return false
        }
    }
}
