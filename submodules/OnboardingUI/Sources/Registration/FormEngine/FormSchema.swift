import Foundation

/// Декларативное описание формы Phase 4.
///
/// Михаил при вёрстке использует `FormSchema` как источник истины: список шагов,
/// какие поля показывать в каждом шаге, какие у них типы и валидации. Перевёрстывать
/// «жёстко» нельзя — иначе схема и UI разойдутся и логика state-машины сломается.
public struct FormSchema {
    public let id: OnboardingFormID
    /// Локализационный ключ заголовка-«шапки» (например, "4.A — Companies & Brands").
    /// Не отображается юзеру напрямую, но используется в шапке debug-логов.
    public let internalTitleKey: String
    public let steps: [FormStep]

    public init(id: OnboardingFormID, internalTitleKey: String, steps: [FormStep]) {
        self.id = id
        self.internalTitleKey = internalTitleKey
        self.steps = steps
    }
}

public struct FormStep {
    /// Заголовок экрана (например, «PERSONAL DETAILS»).
    public let titleKey: String
    /// Опциональный подзаголовок под title.
    public let subtitleKey: String?
    /// Лейбл прогресса в шапке. Если nil — лейбла нет (в 4.E на step 1 он есть, на step 2 — есть Skip справа).
    public let stepProgressKey: String?
    /// Поля шага в порядке отрисовки.
    public let fields: [FormField]
    /// Текст основной кнопки внизу. Обычно «Continue» / «Done» / «Let's go».
    public let primaryButtonKey: String
    /// Показывать ли «Skip for now» справа в шапке (4.E step 2).
    public let allowSkip: Bool

    public init(
        titleKey: String,
        subtitleKey: String? = nil,
        stepProgressKey: String? = nil,
        fields: [FormField],
        primaryButtonKey: String,
        allowSkip: Bool = false
    ) {
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.stepProgressKey = stepProgressKey
        self.fields = fields
        self.primaryButtonKey = primaryButtonKey
        self.allowSkip = allowSkip
    }
}

public struct FormField {
    /// Уникальный ключ в рамках формы. Под ним сохраняется значение в `OnboardingRegistrationState`,
    /// и под этим же ключом значение попадает в submit-payload.
    public let key: String
    public let kind: FormFieldKind
    /// Локализационный ключ placeholder'а (например, "First name *").
    public let placeholderKey: String?
    /// Подсказка под полем (например, "Helps verify your account").
    public let helpTextKey: String?
    public let isRequired: Bool

    public init(
        key: String,
        kind: FormFieldKind,
        placeholderKey: String? = nil,
        helpTextKey: String? = nil,
        isRequired: Bool = false
    ) {
        self.key = key
        self.kind = kind
        self.placeholderKey = placeholderKey
        self.helpTextKey = helpTextKey
        self.isRequired = isRequired
    }
}
