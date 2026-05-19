import Foundation

/// Декларативная state-машина регистрационного онбординга.
///
/// Содержит граф переходов Phase 3 + Phase 4. Контроллеры экранов её не знают:
/// они только сообщают coordinator'у «юзер тапнул Continue / Back», а coordinator
/// зовёт `nextStep(...)` / `previousStep(...)` и идёт куда сказано.
///
/// Всё, что касается ролей (форма для роли, result-экран для роли, источник back-перехода),
/// вычитывается из `OnboardingRoleRegistry`. Это значит — список ролей и любые их атрибуты
/// меняются правкой массива в registry, никаких switch по 25 кейсам в этой машине нет.
public struct OnboardingRegistrationStateMachine {

    private let registry: OnboardingRoleRegistry
    /// Сколько шагов в форме — берётся из form-каталога. Инжектится closure'ой,
    /// чтобы машина не тащила за собой зависимость от каталога целиком (легче тестировать).
    private let formStepCount: (OnboardingFormID) -> Int

    public init(registry: OnboardingRoleRegistry, formStepCount: @escaping (OnboardingFormID) -> Int) {
        self.registry = registry
        self.formStepCount = formStepCount
    }

    // MARK: - Forward

    /// Какой шаг показать после успешного Continue с текущего.
    /// Возвращает `nil`, если необходимый выбор ещё не сделан (юзер на этом шаге, валидация подсветит).
    public func nextStep(from state: OnboardingRegistrationState) -> OnboardingRegistrationStep? {
        switch state.currentStep {

        case .topLevelChoice:
            guard let category = state.topLevelCategory else { return nil }
            switch category {
            case .getHired:
                return .talentSubRolePicker
            case .lookingForTalent:
                return .industryDoor
            case .hereToFollow:
                return .roleResult(roleId: .fan)
            }

        case .talentSubRolePicker:
            guard let roleId = state.selectedRoleId else { return nil }
            // Если у выбранной роли discoveredFrom == .experienceQuiz — значит между пикером и result
            // стоит квиз. Иначе сразу result. Это полностью data-driven: ни одной упоминания
            // конкретной роли в самом коде state-машины нет.
            if registry.definition(for: roleId)?.discoveredFrom == .experienceQuiz {
                return .talentExperienceQuiz
            }
            return .roleResult(roleId: roleId)

        case .talentExperienceQuiz:
            guard let hasExperience = state.hasModelingExperience else { return nil }
            // По дизайну: Yes → Model, No → New Talent. Если эта развилка будет менять смысл
            // (например, добавится третья опция), правка делается тут, без других мест.
            return .roleResult(roleId: hasExperience ? .model : .newTalent)

        case .industryDoor:
            guard let door = state.industryDoor else { return nil }
            switch door {
            case .representCompany:
                return .companiesSubRolePicker
            case .industryProfessional:
                return .industryProSubRolePicker
            }

        case .industryProSubRolePicker, .companiesSubRolePicker:
            guard let roleId = state.selectedRoleId else { return nil }
            return .roleResult(roleId: roleId)

        case .roleResult(let roleId):
            guard let def = registry.definition(for: roleId) else { return .submitting }
            return .formStep(formId: def.formId, stepIndex: 0)

        case .formStep(let formId, let stepIndex):
            let total = formStepCount(formId)
            let nextIndex = stepIndex + 1
            if nextIndex < total {
                return .formStep(formId: formId, stepIndex: nextIndex)
            }
            return .submitting

        case .submitting:
            // Переход в `.completed` делается из coordinator'а после ответа submit-сервиса,
            // не через `nextStep`. Это единственное место, где машина «не знает» исхода.
            return nil

        case .completed:
            return nil
        }
    }

    // MARK: - Back

    /// Какой шаг предшествует текущему (обычная кнопка Back).
    /// Возвращает `nil`, если мы в корне.
    public func previousStep(from state: OnboardingRegistrationState) -> OnboardingRegistrationStep? {
        switch state.currentStep {

        case .topLevelChoice:
            return nil

        case .talentSubRolePicker:
            return .topLevelChoice

        case .talentExperienceQuiz:
            return .talentSubRolePicker

        case .industryDoor:
            return .topLevelChoice

        case .industryProSubRolePicker, .companiesSubRolePicker:
            return .industryDoor

        case .roleResult(let roleId):
            // Куда возвращаться с result — определяется атрибутом `discoveredFrom` у роли в registry.
            // Никаких switch по конкретным ролям здесь нет.
            let source = registry.definition(for: roleId)?.discoveredFrom ?? .topLevel
            return step(for: source)

        case .formStep(let formId, let stepIndex):
            if stepIndex > 0 {
                return .formStep(formId: formId, stepIndex: stepIndex - 1)
            }
            // На первом шаге формы — назад в result-экран, который привёл сюда.
            if let roleId = state.selectedRoleId {
                return .roleResult(roleId: roleId)
            }
            // Аномалия: forms-step без выбранной роли. Сваливаемся на top-level.
            return .topLevelChoice

        case .submitting, .completed:
            return nil
        }
    }

    // MARK: - Restart

    /// Жмём «Choose a different role» на result-экране — возвращаемся к самому первому экрану.
    /// Coordinator при этом ОБЯЗАН сбросить `state.topLevelCategory`/`industryDoor`/`selectedRoleId`/`hasModelingExperience`
    /// через `OnboardingRegistrationState.restartPhase3()`.
    public func restartPhase3() -> OnboardingRegistrationStep {
        return .topLevelChoice
    }

    // MARK: - Private

    private func step(for source: OnboardingDiscoverySource) -> OnboardingRegistrationStep {
        switch source {
        case .topLevel:                 return .topLevelChoice
        case .talentSubRolePicker:      return .talentSubRolePicker
        case .industryProSubRolePicker: return .industryProSubRolePicker
        case .companiesSubRolePicker:   return .companiesSubRolePicker
        case .experienceQuiz:           return .talentExperienceQuiz
        }
    }
}
