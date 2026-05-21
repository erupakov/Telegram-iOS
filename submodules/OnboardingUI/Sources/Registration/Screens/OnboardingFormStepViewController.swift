import UIKit
import Display
import DivoCore
import DivoUIKit

/// Универсальный экран-«шаг формы» Phase 4. Один на все 8 форм — отрисовка определяется
/// `FormStep` (заголовок, поля, кнопка) и текущим snapshot значений.
///
/// Михаил при вёрстке заменяет визуал field-row'ов (текстфилды, кнопки-пикеры, фото-области)
/// на финальные DivoUIKit-компоненты. **Не трогает**:
/// - `delegate` callbacks (`didChangeFieldValue`, `didTapPrimary`, `didTapBack`, `didTapSkip`).
/// - `valueSnapshot()` — coordinator зовёт его перед переходом, чтобы достать введённые значения.
/// - state машину enabled/disabled у primaryButton (валидация).
public final class OnboardingFormStepViewController: UIViewController {

    public protocol Delegate: AnyObject {
        func formStepController(_ controller: OnboardingFormStepViewController, didChangeField fieldKey: String, to value: FormFieldValue)
        func formStepController(_ controller: OnboardingFormStepViewController, didRequestPickerForField fieldKey: String)
        func formStepControllerDidTapPrimary(_ controller: OnboardingFormStepViewController)
        func formStepControllerDidTapBack(_ controller: OnboardingFormStepViewController)
        func formStepControllerDidTapSkip(_ controller: OnboardingFormStepViewController)
    }

    public weak var delegate: Delegate?

    private var step: FormStep
    private var values: [String: FormFieldValue]
    private var fieldRows: [String: OnboardingFormFieldRow] = [:]

    private let navigationBar = DivoNavigationBar()
    private let topFadeOverlay = OnboardingBottomFadeOverlay()
    
    private let progressLabel: UILabel = {
        let progressLabel = UILabel()
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = Font.regular(14)
        progressLabel.textColor = DivoColorPalette.primaryText
        progressLabel.textAlignment = .center
        return progressLabel
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(32)
        label.textColor = DivoColorPalette.primaryText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = Font.regular(16)
        subtitleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        subtitleLabel.numberOfLines = 0
        return subtitleLabel
    }()
    
    private let fieldsStack: UIStackView = {
        let fieldsStack = UIStackView()
        fieldsStack.translatesAutoresizingMaskIntoConstraints = false
        fieldsStack.axis = .vertical
        fieldsStack.spacing = DivoDesignTokens.Spacing.m
        fieldsStack.alignment = .fill
        return fieldsStack
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = false // Выключаем "пружину", когда контента мало
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.clipsToBounds = false
        return scrollView
    }()
    
    private let contentView = UIView()
    
    private let bottomTitleLabel: UILabel = {
        let bottomTitleLabel = UILabel()
        bottomTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomTitleLabel.font = Font.helveticaNeue(20)
        bottomTitleLabel.textColor = DivoColorPalette.primaryText
        bottomTitleLabel.textAlignment = .left
        bottomTitleLabel.numberOfLines = 0
        return bottomTitleLabel
    }()
    
    private let bottomSubitleLabel: UILabel = {
        let bottomSubitleLabel = UILabel()
        bottomSubitleLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomSubitleLabel.font = Font.regular(16)
        bottomSubitleLabel.textColor = DivoColorPalette.primaryText
        bottomSubitleLabel.textAlignment = .left
        bottomSubitleLabel.numberOfLines = 0
        return bottomSubitleLabel
    }()
    
    private let bottomFadeOverlay = OnboardingBottomFadeOverlay()
    private let primaryButton = DivoButton()

    /// Bottom-привязки primary-кнопки и fade-overlay. Меняются `DivoKeyboardHandler`'ом
    /// при подъёме/опускании клавиатуры — в покое они равны `defaultButtonOffset` и 0
    /// соответственно (см. инициализацию handler'а в `viewDidLoad`).
    private var primaryButtonBottomConstraint: NSLayoutConstraint?
    private var bottomFadeOverlayBottomConstraint: NSLayoutConstraint?
    private var keyboardHandler: DivoKeyboardHandler?

    public init(step: FormStep, currentValues: [String: FormFieldValue]) {
        self.step = step
        self.values = currentValues
        super.init(nibName: nil, bundle: nil)
        
        navigationBar.makeNavigationBar(
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            rightButtonConfiguration: step.allowSkip ? .text(OnboardingStrings.resolve("onboarding.button.skip")) : nil,
            onBackTapped: {
                [weak self] in self?.backTapped()
            },
            onCircleTextTapped: {
                [weak self] in self?.skipTapped()
            },
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    public func configure(step: FormStep, currentValues: [String: FormFieldValue]) {
        self.step = step
        self.values = currentValues
        if isViewLoaded { applyStep() }
    }

    public func valueSnapshot() -> [String: FormFieldValue] { return values }

    public func updateFieldValue(_ value: FormFieldValue, forKey key: String) {
        values[key] = value
        fieldRows[key]?.applyValue(value)
        updatePrimaryEnabled()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.screenBackground
        setupUI()
        applyStep()
        
        scrollView.contentInset.bottom = Self.defaultScrollInset
        scrollView.verticalScrollIndicatorInsets.bottom = Self.defaultScrollInset

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)

        if let buttonCns = primaryButtonBottomConstraint,
           let overlayCns = bottomFadeOverlayBottomConstraint {
            let handler = DivoKeyboardHandler(
                scrollView: scrollView,
                buttonConstraint: buttonCns,
                overlayConstraint: overlayCns,
                hostView: view,
                defaultButtonOffset: Self.defaultButtonOffset,
                defaultScrollInset: Self.defaultScrollInset
            )
            handler.subscribe()
            keyboardHandler = handler
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    deinit {
        keyboardHandler?.unsubscribe()
    }

    private func setupUI() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        view.addSubview(scrollView)
        view.addSubview(bottomFadeOverlay)
        view.addSubview(primaryButton)
        
        view.addSubview(topFadeOverlay)
        view.addSubview(navigationBar)
        view.addSubview(progressLabel)
        
        topFadeOverlay.transform = CGAffineTransform(rotationAngle: .pi)
        
        let topSpacer = UIView()
        topSpacer.translatesAutoresizingMaskIntoConstraints = false
        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(topSpacer)
        scrollView.addSubview(contentView)
        scrollView.addSubview(bottomSpacer)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(fieldsStack)
        contentView.addSubview(bottomTitleLabel)
        contentView.addSubview(bottomSubitleLabel)

        let safe = view.safeAreaLayoutGuide
        
        let topCollapseConstraint = topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        topCollapseConstraint.priority = .defaultHigh
        topCollapseConstraint.isActive = true
        
        bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        
        NSLayoutConstraint.activate([
            topFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topFadeOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            topFadeOverlay.heightAnchor.constraint(equalToConstant: 140),
            
            navigationBar.topAnchor.constraint(equalTo: safe.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            progressLabel.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: OnboardingBottomFadeOverlay.defaultHeight),

            scrollView.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor, constant: -Self.defaultScrollInset),
            
            topSpacer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            topSpacer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            topSpacer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            contentView.topAnchor.constraint(equalTo: topSpacer.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            bottomSpacer.topAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomSpacer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            bottomSpacer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            bottomSpacer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DivoDesignTokens.Spacing.s),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.xs),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            fieldsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            fieldsStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            fieldsStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
//            fieldsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DivoDesignTokens.Spacing.l),
            
            bottomTitleLabel.topAnchor.constraint(equalTo: fieldsStack.bottomAnchor, constant: DivoDesignTokens.Spacing.l),
            bottomTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bottomTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            bottomSubitleLabel.topAnchor.constraint(equalTo: bottomTitleLabel.bottomAnchor, constant: 6),
            bottomSubitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bottomSubitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bottomSubitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DivoDesignTokens.Spacing.l),

            primaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            primaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            primaryButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        let buttonCns = primaryButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: Self.defaultButtonOffset)
        buttonCns.isActive = true
        primaryButtonBottomConstraint = buttonCns

        let overlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        overlayCns.isActive = true
        bottomFadeOverlayBottomConstraint = overlayCns
    }

    private static let defaultButtonOffset: CGFloat = -40
    private static let defaultScrollInset: CGFloat = 100

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func applyStep() {
        titleLabel.text = OnboardingStrings.resolve(step.titleKey)
        if let sub = step.subtitleKey {
            subtitleLabel.text = OnboardingStrings.resolve(sub)
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
        if let bottomTitle = step.bottomTitle, let bottomSubitle = step.bottomSubtitle {
            bottomTitleLabel.text = OnboardingStrings.resolve(bottomTitle)
            bottomSubitleLabel.text = OnboardingStrings.resolve(bottomSubitle)
            bottomTitleLabel.isHidden = false
            bottomSubitleLabel.isHidden = false
        } else {
            bottomTitleLabel.isHidden = true
            bottomSubitleLabel.isHidden = true
        }
        if let progress = step.stepProgressKey {
            progressLabel.text = OnboardingStrings.resolve(progress)
            progressLabel.isHidden = false
        } else {
            progressLabel.isHidden = true
        }

        primaryButton.makeDivoButton(title: OnboardingStrings.resolve(step.primaryButtonKey))

        fieldsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        fieldRows.removeAll()
        
        var groupedFields: [FormField] = []
        
        // Вспомогательная функция, которая превращает накопленные поля в единую карточку
        func flushGroupedFields(titleStep: String) {
            if titleStep == "onboarding.form.4A.step3.title" {
                let groupContainer = UIView()
                groupContainer.backgroundColor = DivoColorPalette.cardBackground
                groupContainer.layer.cornerRadius = DivoDesignTokens.Radius.pill
                groupContainer.translatesAutoresizingMaskIntoConstraints = false
                
                let groupStack = UIStackView()
                groupStack.axis = .vertical
                groupStack.spacing = 0
                groupStack.translatesAutoresizingMaskIntoConstraints = false
                
                groupContainer.addSubview(groupStack)
                NSLayoutConstraint.activate([
                    groupStack.topAnchor.constraint(equalTo: groupContainer.topAnchor),
                    groupStack.bottomAnchor.constraint(equalTo: groupContainer.bottomAnchor),
                    groupStack.leadingAnchor.constraint(equalTo: groupContainer.leadingAnchor),
                    groupStack.trailingAnchor.constraint(equalTo: groupContainer.trailingAnchor)
                ])
                
                for (index, field) in groupedFields.enumerated() {
                    let isFirst = index == 0
                    let isLast = index == groupedFields.count - 1
                    
                    let row = createRow(for: field, isGrouped: true, isFirst: isFirst, isLast: isLast)
                    groupStack.addArrangedSubview(row.wrapper)
                    
                    if !isLast {
                        let separator = UIView()
                        separator.backgroundColor = DivoColorPalette.separatorLight
                        separator.translatesAutoresizingMaskIntoConstraints = false
                        let separatorWrapper = UIView()
                        separatorWrapper.translatesAutoresizingMaskIntoConstraints = false
                        separatorWrapper.addSubview(separator)
                        
                        NSLayoutConstraint.activate([
                            separatorWrapper.heightAnchor.constraint(equalToConstant: 1),
                            separator.leadingAnchor.constraint(equalTo: separatorWrapper.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                            separator.trailingAnchor.constraint(equalTo: separatorWrapper.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                            separator.topAnchor.constraint(equalTo: separatorWrapper.topAnchor),
                            separator.bottomAnchor.constraint(equalTo: separatorWrapper.bottomAnchor)
                        ])
                        groupStack.addArrangedSubview(separatorWrapper)
                    }
                }
                fieldsStack.addArrangedSubview(groupContainer)
            } else if !groupedFields.isEmpty {
                for field in groupedFields {
                    let row = createRow(for: field, isGrouped: false, isFirst: true, isLast: true)
                    fieldsStack.addArrangedSubview(row.wrapper)
                }
            }
            groupedFields.removeAll()
        }
        
        for field in step.fields {
            let isTextKind: Bool
            switch field.kind {
            case .text, .email, .url, .phone, .city: isTextKind = true
            default: isTextKind = false
            }
            
            if isTextKind && field.helpTextKey == nil {
                groupedFields.append(field)
            } else {
                flushGroupedFields(titleStep: step.titleKey)
                let row = createRow(for: field, isGrouped: false, isFirst: true, isLast: true)
                fieldsStack.addArrangedSubview(row.wrapper)
            }
        }
        
        flushGroupedFields(titleStep: step.titleKey)
        updatePrimaryEnabled()    
            
        setupTextFieldsChain()
    }
    
    private func setupTextFieldsChain() {
        // 1. Собираем все ряды в том порядке, в котором они идут на экране
        // Мы берем их из step.fields, чтобы сохранить порядок сортировки
        let textRows = step.fields.compactMap { field -> OnboardingFormFieldRow? in
            let row = fieldRows[field.key]
            switch field.kind {
            case .text, .email, .url, .phone, .city:
                return row
            default:
                return nil
            }
        }
        
        // 2. Связываем их между собой
        for (index, row) in textRows.enumerated() {
            let isLast = index == textRows.count - 1
            
            // Если это последнее текстовое поле на экране, кнопка должна быть Done (Готово)
            row.textField.textField.returnKeyType = isLast ? .done : .next
            
            // Передаем замыкание, которое выполнится при нажатии Return
            row.textField.onReturn = { [weak self, weak row] in
                guard let self = self, let currentRow = row else { return }
                
                // Если мы в группе, убираем рамку вручную (так как мы делаем resignFirstResponder неявно)
                if currentRow.isGrouped {
                    currentRow.textField.layer.borderWidth = 0.0
                }
                
                if isLast {
                    // Если это последнее поле, просто прячем клавиатуру
                    self.view.endEditing(true)
                } else {
                    // Если есть следующее поле, передаем фокус ему
                    let nextRow = textRows[index + 1]
                    nextRow.textField.textField.becomeFirstResponder()
                    
                    // Если следующее поле находится в самом низу скролла и может быть скрыто клавиатурой,
                    // мы можем слегка подскроллить к нему (DivoKeyboardHandler обычно делает это сам,
                    // но при быстром переходе фокуса лучше подстраховаться)
                    let frame = nextRow.convert(nextRow.bounds, to: self.scrollView).insetBy(dx: 0, dy: -20)
                    self.scrollView.scrollRectToVisible(frame, animated: true)
                }
            }
        }
    }
    
    // Вспомогательная функция для создания одного ряда формы (и его обертки)
    private func createRow(for field: FormField, isGrouped: Bool, isFirst: Bool, isLast: Bool) -> (wrapper: UIView, row: OnboardingFormFieldRow) {
        let row = OnboardingFormFieldRow(field: field, value: values[field.key])
        row.isGrouped = isGrouped
        row.onValueChanged = { [weak self] value in
            guard let self = self else { return }
            self.values[field.key] = value
            self.delegate?.formStepController(self, didChangeField: field.key, to: value)
            self.updatePrimaryEnabled()
        }
        
        row.presentController = { [weak self] in
            guard let self = self else { return }
            self.delegate?.formStepController(self, didRequestPickerForField: field.key)
        }
        
        fieldRows[field.key] = row
        
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        
        if isGrouped {
            row.layer.borderWidth = 0
            row.layer.cornerRadius = 0
            row.backgroundColor = .clear
        }
        
        wrapper.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: wrapper.topAnchor),
            row.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        
        return (wrapper, row)
    }

    private func updatePrimaryEnabled() {
        primaryButton.isEnabled = FormValidator.isStepValid(step, values: values) || step.allowSkip
    }

    @objc private func backTapped()    { delegate?.formStepControllerDidTapBack(self) }
    @objc private func skipTapped()    { delegate?.formStepControllerDidTapSkip(self) }
    @objc private func primaryTapped() {
        if view.isFirstResponder || containsFirstResponder(view) {
            UIView.performWithoutAnimation {
                view.endEditing(true)
                view.layoutIfNeeded()
            }
        }
        
        delegate?.formStepControllerDidTapPrimary(self)
    }
    
    // Вспомогательная функция для проверки, открыта ли клавиатура
    private func containsFirstResponder(_ view: UIView) -> Bool {
        if view.isFirstResponder { return true }
        for subview in view.subviews {
            if containsFirstResponder(subview) { return true }
        }
        return false
    }
}
