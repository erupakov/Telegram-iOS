import Foundation

/// Описывает шаг, который сейчас показан пользователю в потоке регистрационного онбординга.
///
/// Семантика — что отображает контроллер, не «куда мы движемся». Поток описывается
/// state-машиной (`OnboardingRegistrationStateMachine`), которая по текущему `state` решает,
/// какой следующий step выдать на forward/back.
public enum OnboardingRegistrationStep: Hashable, Codable {

    /// Самый первый экран Phase 3. Три варианта: `getHired` / `lookingForTalent` / `hereToFollow`.
    case topLevelChoice

    /// Talent sub-role picker (открывается из `getHired`). Список ролей Talent + Creative.
    /// По дизайну Creative-роли вшиты сюда; по PDF v3.0 — отдельная категория. Пока — как в дизайне.
    case talentSubRolePicker

    /// Question 2 of 2 для Model: «Do you have professional modelling experience and an agency?».
    /// Появляется ТОЛЬКО если на предыдущем шаге выбран Model. Yes → Model, No → New Talent.
    case talentExperienceQuiz

    /// Industry «How do you work?». Два варианта: представляю компанию / я профессионал.
    /// Открывается из `lookingForTalent`.
    case industryDoor

    /// Industry Pro sub-role picker (Scout / Booker / Casting Director / Talent Manager).
    case industryProSubRolePicker

    /// Companies & Brands sub-role picker (Modeling agency / Fashion brand / ...).
    case companiesSubRolePicker

    /// Result-экран «YOU'RE A …». Один из 9 вариантов.
    case roleResult(roleId: OnboardingRoleID)

    /// Шаг внутри формы Phase 4. `stepIndex` — 0-based индекс шага в `OnboardingFormCatalog`.
    case formStep(formId: OnboardingFormID, stepIndex: Int)

    /// Идёт submit на бэк / мок.
    case submitting

    /// Финиш — переходим обратно к флоу авторизации (или в тестовом режиме просто dismiss).
    case completed
}
