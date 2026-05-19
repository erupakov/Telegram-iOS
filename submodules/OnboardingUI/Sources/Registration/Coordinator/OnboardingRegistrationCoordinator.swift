import UIKit
import Display
import DivoCore
import DivoUIKit

/// Координатор регистрационного онбординга.
///
/// Один объект, который:
/// 1. Хранит state онбординга и `OnboardingProgressStore` для persistence.
/// 2. Создаёт собственный `UINavigationController` (этот VC и есть «онбординг»).
/// 3. Слушает delegate-callback'и от экранов, дёргает `OnboardingRegistrationStateMachine`,
///    пушит/попит следующий контроллер.
/// 4. На финале зовёт `OnboardingSubmitService` и завершает поток `onFinish` callback'ом.
///
/// Никакой бизнес-логики на стороне контроллеров нет — они только показывают данные
/// и сообщают о действиях. Это позволяет Михаилу полностью переверстать визуал,
/// не задев навигацию и submit.
public final class OnboardingRegistrationCoordinator {

    // MARK: - Зависимости

    private let registry: OnboardingRoleRegistry
    private let quizCatalog: OnboardingQuizCatalog
    private let formCatalog: OnboardingFormCatalog
    private let resultCatalog: OnboardingResultCatalog
    private let stateMachine: OnboardingRegistrationStateMachine
    private let store: OnboardingProgressStore
    private let submitService: OnboardingSubmitService

    /// Текущее состояние онбординга. Каждый mutating-доступ сопровождается `store.save(...)`.
    private var state: OnboardingRegistrationState

    /// UINavigationController, в котором живёт весь онбординг.
    public let navigationController: UINavigationController

    /// Дёргается, когда юзер успешно завершил онбординг (submit ОК) или явно закрыл его
    /// крестиком из top-level (`completedSuccessfully = false`).
    public let onFinish: (Bool) -> Void

    // MARK: - Init

    public init(
        registry: OnboardingRoleRegistry = .default,
        resultCatalog: OnboardingResultCatalog = OnboardingResultCatalog(),
        store: OnboardingProgressStore = OnboardingProgressStore(),
        submitService: OnboardingSubmitService = MockOnboardingSubmitService(),
        forceFresh: Bool,
        onFinish: @escaping (Bool) -> Void
    ) {
        // FormCatalog зависит от registry (берёт оттуда списки ролей для встроенных пикеров),
        // поэтому конструируется здесь после установки registry, а не через default-параметр.
        let formCatalog = OnboardingFormCatalog(registry: registry)

        self.registry = registry
        self.resultCatalog = resultCatalog
        self.formCatalog = formCatalog
        self.store = store
        self.submitService = submitService
        self.quizCatalog = OnboardingQuizCatalog(registry: registry)
        self.stateMachine = OnboardingRegistrationStateMachine(
            registry: registry,
            formStepCount: { formCatalog.stepCount(for: $0) }
        )
        self.onFinish = onFinish

        self.state = Self.resolveStartState(
            forceFresh: forceFresh,
            store: store,
            registry: registry,
            formCatalog: formCatalog
        )

        self.navigationController = UINavigationController()
        self.navigationController.setNavigationBarHidden(true, animated: false)
        self.navigationController.modalPresentationStyle = .fullScreen

        // Запускаем с текущего шага.
        pushController(for: state.currentStep, animated: false)
    }

    // MARK: - Public entry

    /// Завершение по системному «крестику» (`OnboardingQuizViewController` topLevelChoice).
    /// Из других мест закрытие не предусмотрено — там есть Back.
    public func cancelFromTopLevel() {
        divoLog("Onboarding cancelled from top-level", level: .info)
        onFinish(false)
    }

    // MARK: - Стейт

    private func updateState(_ mutate: (inout OnboardingRegistrationState) -> Void) {
        mutate(&state)
        store.save(state)
    }

    private func go(to step: OnboardingRegistrationStep, animated: Bool = true) {
        updateState { $0.currentStep = step }
        pushController(for: step, animated: animated)
    }

    private func goBack(animated: Bool = true) {
        guard let previous = stateMachine.previousStep(from: state) else {
            // Корень — закрываем онбординг как cancel.
            divoLog("Onboarding back from top-level → cancelFromTopLevel", level: .info)
            cancelFromTopLevel()
            return
        }
        updateState { $0.currentStep = previous }
        if navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: animated)
        } else {
            // После persistence-restore стек содержит только текущий шаг — pop ничего бы не сделал
            // и UI рассинхронился бы со state. Создаём controller предыдущего шага и заменяем root.
            let vc = makeController(for: previous)
            navigationController.setViewControllers([vc], animated: animated)
        }
    }

    // MARK: - Push

    private func pushController(for step: OnboardingRegistrationStep, animated: Bool) {
        let vc = makeController(for: step)
        if navigationController.viewControllers.isEmpty {
            navigationController.setViewControllers([vc], animated: false)
        } else {
            navigationController.pushViewController(vc, animated: animated)
        }
    }

    private func makeController(for step: OnboardingRegistrationStep) -> UIViewController {
        switch step {
        case .topLevelChoice,
             .industryDoor,
             .talentSubRolePicker,
             .industryProSubRolePicker,
             .companiesSubRolePicker,
             .talentExperienceQuiz:
            guard let descriptor = quizCatalog.descriptor(for: step) else {
                return UIViewController()
            }
            let currentSelection = currentSelectionForQuiz(step: step)
            let vc = OnboardingQuizViewController(descriptor: descriptor, currentSelection: currentSelection)
            vc.delegate = self
            return vc

        case .roleResult(let roleId):
            guard let presentation = resultCatalog.presentation(forRole: roleId, registry: registry) else {
                return UIViewController()
            }
            let vc = OnboardingRoleResultViewController(presentation: presentation)
            vc.delegate = self
            return vc

        case .formStep(let formId, let index):
            let schema = formCatalog.schema(for: formId, state: state)
            let safeIndex = max(0, min(index, schema.steps.count - 1))
            let step = schema.steps[safeIndex]
            let formValues = state.formValues[formId.rawValue] ?? [:]
            let vc = OnboardingFormStepViewController(step: step, currentValues: formValues)
            vc.delegate = self
            return vc

        case .submitting:
            let vc = OnboardingSubmitViewController()
            vc.delegate = self
            return vc

        case .completed:
            // На этом шаге uikit-контроллер не нужен — переход в onFinish.
            return UIViewController()
        }
    }

    private func currentSelectionForQuiz(step: OnboardingRegistrationStep) -> String? {
        switch step {
        case .topLevelChoice:
            return state.topLevelCategory?.rawValue
        case .industryDoor:
            return state.industryDoor?.rawValue
        case .talentExperienceQuiz:
            if let v = state.hasModelingExperience { return v ? "yes" : "no" }
            return nil
        case .talentSubRolePicker, .industryProSubRolePicker, .companiesSubRolePicker:
            return state.selectedRoleId?.rawValue
        default:
            return nil
        }
    }
}

// MARK: - OnboardingQuizViewController.Delegate

extension OnboardingRegistrationCoordinator: OnboardingQuizViewController.Delegate {

    public func quizController(_ controller: OnboardingQuizViewController, didSelectOption optionId: String) {
        switch state.currentStep {
        case .topLevelChoice:
            updateState { $0.topLevelCategory = OnboardingTopLevelCategory(rawValue: optionId) }
        case .industryDoor:
            updateState { $0.industryDoor = OnboardingIndustryDoor(rawValue: optionId) }
        case .talentExperienceQuiz:
            // Выбор Yes/No yet одновременно фиксирует hasModelingExperience И селектит финальную
            // роль (.model или .newTalent). Без обновления selectedRoleId submit-payload отправил бы
            // .model даже когда юзер прошёл ветку «No yet» → 4.D2 — рассинхрон с фактической формой.
            let hasExperience = (optionId == "yes")
            updateState {
                $0.hasModelingExperience = hasExperience
                $0.selectedRoleId = hasExperience ? .model : .newTalent
            }
        case .talentSubRolePicker, .industryProSubRolePicker, .companiesSubRolePicker:
            updateState { $0.selectedRoleId = OnboardingRoleID(optionId) }
        default:
            break
        }
    }

    public func quizControllerDidTapContinue(_ controller: OnboardingQuizViewController) {
        guard let next = stateMachine.nextStep(from: state) else { return }
        go(to: next)
    }

    public func quizControllerDidTapBack(_ controller: OnboardingQuizViewController) {
        goBack()
    }
}

// MARK: - OnboardingRoleResultViewController.Delegate

extension OnboardingRegistrationCoordinator: OnboardingRoleResultViewController.Delegate {

    public func roleResultControllerDidConfirm(_ controller: OnboardingRoleResultViewController) {
        guard let next = stateMachine.nextStep(from: state) else { return }
        go(to: next)
    }

    public func roleResultControllerDidRequestRestart(_ controller: OnboardingRoleResultViewController) {
        // «Choose a different role» — полностью сбрасываем Phase 3.
        updateState { $0.restartPhase3() }
        navigationController.setViewControllers([makeController(for: .topLevelChoice)], animated: true)
    }

    public func roleResultControllerDidTapBack(_ controller: OnboardingRoleResultViewController) {
        goBack()
    }
}

// MARK: - OnboardingFormStepViewController.Delegate

extension OnboardingRegistrationCoordinator: OnboardingFormStepViewController.Delegate {

    public func formStepController(_ controller: OnboardingFormStepViewController, didChangeField fieldKey: String, to value: FormFieldValue) {
        guard case .formStep(let formId, _) = state.currentStep else { return }
        updateState { $0.setValue(value, forForm: formId, fieldKey: fieldKey) }
    }

    public func formStepController(_ controller: OnboardingFormStepViewController, didRequestPickerForField fieldKey: String) {
        guard case .formStep(let formId, let stepIndex) = state.currentStep else { return }
        let schema = formCatalog.schema(for: formId, state: state)
        guard let step = schema.steps[safe: stepIndex],
              let field = step.fields.first(where: { $0.key == fieldKey }) else { return }

        switch field.kind {
        case .picker(let options):
            presentPickerSheet(controller: controller, fieldKey: fieldKey, titleKey: field.placeholderKey ?? "onboarding.button.continue", options: options)
        case .multiPicker(let options, _, _):
            presentPickerSheet(controller: controller, fieldKey: fieldKey, titleKey: field.placeholderKey ?? "onboarding.button.continue", options: options)
        case .country:
            // FIXME (PROJ-004): подключить настоящий список стран. Пока — placeholder с 3 опциями.
            let placeholderOptions: [FormPickerOption] = [
                .init(id: "US", titleKey: "United States"),
                .init(id: "GB", titleKey: "United Kingdom"),
                .init(id: "FR", titleKey: "France"),
            ]
            presentPickerSheet(controller: controller, fieldKey: fieldKey, titleKey: field.placeholderKey ?? "onboarding.form.field.country.placeholder", options: placeholderOptions)
        case .date(let minDate, let maxDate, let presentation):
            presentDateSheet(
                controller: controller,
                fieldKey: fieldKey,
                titleKey: field.placeholderKey ?? "onboarding.form.field.dateOfBirth.placeholder",
                min: minDate,
                max: maxDate,
                presentation: presentation
            )
        case .photo:
            presentPhotoPicker(controller: controller, fieldKey: fieldKey)
        default:
            break
        }
    }

    public func formStepControllerDidTapPrimary(_ controller: OnboardingFormStepViewController) {
        guard let next = stateMachine.nextStep(from: state) else { return }
        go(to: next)
    }

    public func formStepControllerDidTapBack(_ controller: OnboardingFormStepViewController) {
        goBack()
    }

    public func formStepControllerDidTapSkip(_ controller: OnboardingFormStepViewController) {
        // Skip — то же, что Primary, но без обязательного валидного значения. Сейчас единственный
        // случай Skip — фото на Fan (последний шаг), сразу submit.
        guard let next = stateMachine.nextStep(from: state) else { return }
        go(to: next)
    }

    private func presentPickerSheet(controller: UIViewController, fieldKey: String, titleKey: String, options: [FormPickerOption]) {
        // Гасим клавиатуру перед показом sheet — иначе bottom-sheet наезжает на её рамку
        // и теряется анимация перехода.
        controller.view.endEditing(true)
        let currentSelectedId: String? = {
            guard case .formStep(let formId, _) = state.currentStep,
                  let value = state.value(forForm: formId, fieldKey: fieldKey),
                  case .option(let id) = value else { return nil }
            return id
        }()
        let sheet = OnboardingPickerSheetViewController(
            titleKey: titleKey,
            options: options,
            selectedId: currentSelectedId,
            onSelect: { [weak self, weak controller] selectedId in
                guard let self = self,
                      let formId = self.formIdFromCurrentStepOptional() else { return }
                let value: FormFieldValue = selectedId.map { .option($0) } ?? .empty
                self.updateState { $0.setValue(value, forForm: formId, fieldKey: fieldKey) }
                if let formController = controller as? OnboardingFormStepViewController {
                    formController.updateFieldValue(value, forKey: fieldKey)
                }
            }
        )
        if #available(iOS 15.0, *), let pres = sheet.sheetPresentationController {
            pres.detents = [.medium(), .large()]
            pres.prefersGrabberVisible = true
        }
        controller.present(sheet, animated: true)
    }

    private func formIdFromCurrentStep() -> OnboardingFormID {
        if case .formStep(let formId, _) = state.currentStep { return formId }
        return .companiesAndBrands
    }

    private func formIdFromCurrentStepOptional() -> OnboardingFormID? {
        if case .formStep(let formId, _) = state.currentStep { return formId }
        return nil
    }

    // MARK: - Date / Photo sheets

    private func presentDateSheet(
        controller: UIViewController,
        fieldKey: String,
        titleKey: String,
        min: Date?,
        max: Date?,
        presentation: FormFieldKind.DatePresentation
    ) {
        controller.view.endEditing(true)
        let currentDate: Date? = {
            guard let formId = formIdFromCurrentStepOptional(),
                  let value = state.value(forForm: formId, fieldKey: fieldKey),
                  case .date(let d) = value else { return nil }
            return d
        }()
        let sheet = OnboardingDateSheetViewController(
            titleKey: titleKey,
            selectedDate: currentDate,
            min: min,
            max: max,
            presentation: presentation,
            onSelect: { [weak self, weak controller] date in
                guard let self = self,
                      let formId = self.formIdFromCurrentStepOptional() else { return }
                let value: FormFieldValue = date.map { .date($0) } ?? .empty
                self.updateState { $0.setValue(value, forForm: formId, fieldKey: fieldKey) }
                if let formController = controller as? OnboardingFormStepViewController {
                    formController.updateFieldValue(value, forKey: fieldKey)
                }
            }
        )
        if #available(iOS 15.0, *), let pres = sheet.sheetPresentationController {
            pres.detents = [.medium()]
            pres.prefersGrabberVisible = true
        }
        controller.present(sheet, animated: true)
    }

    /// `OnboardingPhotoPicker` удерживается через `objc_setAssociatedObject` на presented контроллере,
    /// поэтому здесь можно просто инстанцировать и забыть. PHPicker — iOS 14+: на более старых
    /// версиях нужен будет fallback на `UIImagePickerController`.
    private func presentPhotoPicker(controller: UIViewController, fieldKey: String) {
        controller.view.endEditing(true)
        guard #available(iOS 14, *) else {
            divoLog("Photo picker unavailable: iOS 14+ required", level: .warning)
            return
        }
        let picker = OnboardingPhotoPicker()
        picker.present(on: controller) { [weak self, weak controller] result in
            guard let self = self,
                  let formId = self.formIdFromCurrentStepOptional() else { return }
            switch result {
            case .success(let path):
                let value: FormFieldValue = .asset(path)
                self.updateState { $0.setValue(value, forForm: formId, fieldKey: fieldKey) }
                if let formController = controller as? OnboardingFormStepViewController {
                    formController.updateFieldValue(value, forKey: fieldKey)
                }
            case .failure(let error):
                divoLog("Photo picker failed for field \(fieldKey): \(error.localizedDescription)", level: .error)
                // Тихо игнорируем — юзер просто остаётся без фото. Если потребуется snackbar —
                // дёрнем delegate, добавим вид.
            }
        }
    }
}

// MARK: - OnboardingSubmitViewController.Delegate

extension OnboardingRegistrationCoordinator: OnboardingSubmitViewController.Delegate {

    public func submitControllerDidRequestStart(_ controller: OnboardingSubmitViewController) {
        Task { @MainActor in
            do {
                try await submitService.submit(state: state, registry: registry)
                controller.applySuccess()
                store.clear()
                divoLog("Onboarding completed successfully", level: .info)
                onFinish(true)
            } catch {
                divoLog("Onboarding submit failed: \(error)", level: .error)
                controller.applyFailure(error: error)
            }
        }
    }

    public func submitControllerDidFinish(_ controller: OnboardingSubmitViewController) {
        // No-op: onFinish уже вызван в submitControllerDidRequestStart.
    }
}

// MARK: - Restore policy

private extension OnboardingRegistrationCoordinator {
    /// Решает с какого state стартовать coordinator на основе `forceFresh` и сохранённого state.
    ///
    /// Правила:
    /// - `forceFresh: true` или нет сохранённого state → стартуем с чистого `.topLevelChoice`.
    /// - Сохранён `.completed` → онбординг уже был завершён, не пытаемся продолжить; чистим и стартуем заново.
    /// - Сохранён `.submitting` → submit был прерван (краш / kill приложения). Возвращаемся
    ///   на ПОСЛЕДНИЙ шаг формы, сохраняя все введённые данные. Юзер видит свою форму,
    ///   может тапнуть Continue → submit, или Back → проверить и поправить.
    /// - Любой другой шаг → восстанавливаем как есть.
    static func resolveStartState(
        forceFresh: Bool,
        store: OnboardingProgressStore,
        registry: OnboardingRoleRegistry,
        formCatalog: OnboardingFormCatalog
    ) -> OnboardingRegistrationState {
        if forceFresh {
            store.clear()
            return OnboardingRegistrationState()
        }
        guard var saved = store.load() else {
            return OnboardingRegistrationState()
        }
        switch saved.currentStep {
        case .completed:
            divoLog("Onboarding restore: saved state was .completed → starting fresh", level: .info)
            store.clear()
            return OnboardingRegistrationState()
        case .submitting:
            // Откатываем на последний шаг формы, чтобы не терять введённые данные.
            if let roleId = saved.selectedRoleId,
               let def = registry.definition(for: roleId) {
                let lastIndex = max(0, formCatalog.stepCount(for: def.formId) - 1)
                saved.currentStep = .formStep(formId: def.formId, stepIndex: lastIndex)
                store.save(saved)
                divoLog("Onboarding restore: rewinding .submitting → last form step (\(def.formId.rawValue), \(lastIndex))", level: .info)
                return saved
            }
            // Не нашли роль/форму — данные потеряны, стартуем с нуля.
            divoLog("Onboarding restore: .submitting without selectedRoleId → starting fresh", level: .warning)
            store.clear()
            return OnboardingRegistrationState()
        default:
            return saved
        }
    }
}

// MARK: - Safe-index helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
