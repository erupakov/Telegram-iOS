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

    private let backButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private let progressLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let fieldsStack = UIStackView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
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
        // Стартовый нижний инсет — содержит кнопку и часть fade-overlay. То же, что
        // `DivoKeyboardHandler.defaultScrollInset` — handler выставляет тот же `100` при keyboardWillHide.
        scrollView.contentInset.bottom = Self.defaultScrollInset
        scrollView.verticalScrollIndicatorInsets.bottom = Self.defaultScrollInset

        // Тап по контенту скрывает клавиатуру — стандартный паттерн для форм.
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)

        // Keyboard handling — стандартный DIVO-handler из DivoUIKit (тот же, что в EditProfile).
        // Сам корректирует contentInset и положение primary-кнопки + fade-overlay.
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
        // Гасим клавиатуру перед уходом — иначе после возврата может «зависнуть»
        // лишний отступ снизу.
        view.endEditing(true)
    }

    deinit {
        keyboardHandler?.unsubscribe()
    }

    private func setupUI() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = DivoColorPalette.primaryText
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.titleLabel?.font = Font.helveticaNeue(15)
        skipButton.setTitleColor(DivoColorPalette.accent, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = Font.regular(13)
        progressLabel.textColor = DivoColorPalette.secondaryText
        progressLabel.textAlignment = .center

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Font.helveticaNeue(22)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.numberOfLines = 0

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = Font.regular(13)
        subtitleLabel.textColor = DivoColorPalette.secondaryText
        subtitleLabel.numberOfLines = 0

        fieldsStack.translatesAutoresizingMaskIntoConstraints = false
        fieldsStack.axis = .vertical
        fieldsStack.spacing = DivoDesignTokens.Spacing.s
        fieldsStack.alignment = .fill

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        view.addSubview(backButton)
        view.addSubview(skipButton)
        view.addSubview(progressLabel)
        view.addSubview(scrollView)
        // bottomFadeOverlay поверх scrollView, под primaryButton — нижний контент уходит в плавный
        // переход к фону экрана. `DivoKeyboardHandler` поднимает overlay над клавиатурой по
        // `bottomFadeOverlayBottomConstraint`.
        view.addSubview(bottomFadeOverlay)
        view.addSubview(primaryButton)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(fieldsStack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: DivoDesignTokens.Spacing.s),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            skipButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            progressLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: OnboardingBottomFadeOverlay.defaultHeight),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DivoDesignTokens.Spacing.s),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.xs),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            fieldsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.l),
            fieldsStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            fieldsStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            fieldsStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -DivoDesignTokens.Spacing.l),

            primaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            primaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            primaryButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        // Привязка primary-кнопки и fade-overlay к view.bottom — модифицируется
        // `DivoKeyboardHandler`'ом по событиям клавиатуры. Константа в покое = `defaultButtonOffset`.
        let buttonCns = primaryButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: Self.defaultButtonOffset)
        buttonCns.isActive = true
        primaryButtonBottomConstraint = buttonCns

        let overlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        overlayCns.isActive = true
        bottomFadeOverlayBottomConstraint = overlayCns
    }

    /// Базовый offset primary-кнопки от низа view, когда клавиатура спрятана.
    /// `-40` — то же значение, что в EditProfile (DIVO convention для нижних форм-кнопок).
    private static let defaultButtonOffset: CGFloat = -40
    /// Базовый нижний инсет scrollView без клавиатуры — содержит кнопку и часть fade-overlay.
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
        if let progress = step.stepProgressKey {
            progressLabel.text = OnboardingStrings.resolve(progress)
            progressLabel.isHidden = false
        } else {
            progressLabel.isHidden = true
        }

        skipButton.isHidden = !step.allowSkip
        if step.allowSkip {
            skipButton.setTitle(OnboardingStrings.resolve("onboarding.button.skip"), for: .normal)
        }

        primaryButton.makeDivoButton(title: OnboardingStrings.resolve(step.primaryButtonKey))

        fieldsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        fieldRows.removeAll()
        for field in step.fields {
            let row = OnboardingFormFieldRow(field: field, value: values[field.key])
            row.onValueChanged = { [weak self] value in
                guard let self = self else { return }
                self.values[field.key] = value
                self.delegate?.formStepController(self, didChangeField: field.key, to: value)
                self.updatePrimaryEnabled()
            }
            row.onTapPickerOpen = { [weak self] in
                guard let self = self else { return }
                self.delegate?.formStepController(self, didRequestPickerForField: field.key)
            }
            fieldsStack.addArrangedSubview(row)
            fieldRows[field.key] = row
        }
        updatePrimaryEnabled()
    }

    private func updatePrimaryEnabled() {
        primaryButton.isEnabled = FormValidator.isStepValid(step, values: values) || step.allowSkip
    }

    @objc private func backTapped()    { delegate?.formStepControllerDidTapBack(self) }
    @objc private func skipTapped()    { delegate?.formStepControllerDidTapSkip(self) }
    @objc private func primaryTapped() { delegate?.formStepControllerDidTapPrimary(self) }
}

// MARK: - Field row

/// Универсальная строка поля формы. Отрисовка зависит от `field.kind`.
/// Скелетная реализация — Михаил подменяет на финальные DivoUIKit-компоненты.
final class OnboardingFormFieldRow: UIView, UITextFieldDelegate {

    let field: FormField
    var onValueChanged: ((FormFieldValue) -> Void)?
    var onTapPickerOpen: (() -> Void)?

    private let helpLabel = UILabel()
    private let textField = UITextField()
    private let pickerButton = UIButton(type: .system)
    private let photoArea = UIControl()
    private let photoLabel = UILabel()
    private let photoPreview = UIImageView()

    init(field: FormField, value: FormFieldValue?) {
        self.field = field
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = DivoColorPalette.cardBackground
        layer.cornerRadius = DivoDesignTokens.Radius.m
        layer.borderWidth = 1
        layer.borderColor = DivoColorPalette.separatorLight.cgColor

        setupCommon()
        setupForKind()
        applyValue(value ?? .empty)

        // Тап по всей строке: для text-полей фокусируем UITextField, для picker/date/photo
        // вызываем onTapPickerOpen (тот же путь, что и у внутренней кнопки/area). Раньше
        // tap-зона ограничивалась `pickerButton`/`textField`, мимо chevron'а / pad'ов клик в пустоту.
        let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)

        // Press-state — feedback нажатия на ячейку. UIButton управляет своим press-стейтом сам,
        // поэтому делаем чтобы внутренние кнопки/area пропускали тач к row, а row отвечала на тач.
        pickerButton.isUserInteractionEnabled = false
        photoArea.isUserInteractionEnabled = false
        addPressState(alpha: DivoDesignTokens.PressState.alpha, scale: DivoDesignTokens.PressState.scaleListRow)
    }

    @objc private func rowTapped() {
        switch field.kind {
        case .text, .multilineText, .email, .url, .phone, .city:
            textField.becomeFirstResponder()
        case .picker, .multiPicker, .country, .date, .photo:
            onTapPickerOpen?()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCommon() {
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = Font.regular(11)
        helpLabel.textColor = DivoColorPalette.secondaryText
        helpLabel.numberOfLines = 0
        helpLabel.isHidden = (field.helpTextKey == nil)
        helpLabel.text = field.helpTextKey.map { OnboardingStrings.resolve($0) }
    }

    private func setupForKind() {
        switch field.kind {
        case .text, .multilineText, .email, .url, .phone, .city:
            installTextField()
        case .picker, .country, .multiPicker:
            installPickerButton()
        case .date:
            installPickerButton()
        case .photo:
            installPhotoArea()
        }
    }

    private func installTextField() {
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = Font.regular(15)
        textField.textColor = DivoColorPalette.primaryText
        textField.placeholder = field.placeholderKey.map { OnboardingStrings.resolve($0) }
        textField.delegate = self
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        addSubview(textField)
        addSubview(helpLabel)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),

            helpLabel.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            helpLabel.trailingAnchor.constraint(equalTo: textField.trailingAnchor),
            helpLabel.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 2),
            helpLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6),
        ])
    }

    private func installPickerButton() {
        pickerButton.translatesAutoresizingMaskIntoConstraints = false
        pickerButton.contentHorizontalAlignment = .leading
        pickerButton.titleLabel?.font = Font.regular(15)
        pickerButton.setTitleColor(DivoColorPalette.systemLabelPlaceholder, for: .normal)
        pickerButton.setTitle(field.placeholderKey.map { OnboardingStrings.resolve($0) }, for: .normal)
        // Тап обрабатывается на уровне row (`rowTapped`), сам button работает только как
        // визуальный лейбл значения — отсюда `isUserInteractionEnabled = false` в init.

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = DivoColorPalette.systemLabelTertiary

        addSubview(pickerButton)
        addSubview(chevron)
        addSubview(helpLabel)
        NSLayoutConstraint.activate([
            pickerButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            pickerButton.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),
            pickerButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            chevron.centerYAnchor.constraint(equalTo: pickerButton.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),

            helpLabel.leadingAnchor.constraint(equalTo: pickerButton.leadingAnchor),
            helpLabel.trailingAnchor.constraint(equalTo: chevron.trailingAnchor),
            helpLabel.topAnchor.constraint(equalTo: pickerButton.bottomAnchor, constant: 2),
            helpLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -6),
        ])
    }

    private func installPhotoArea() {
        photoArea.translatesAutoresizingMaskIntoConstraints = false
        photoArea.backgroundColor = DivoColorPalette.placeholderCardBackground
        photoArea.layer.cornerRadius = DivoDesignTokens.Radius.card
        photoArea.clipsToBounds = true
        // Тап обрабатывается на уровне row (`rowTapped`) — photoArea пропускает тач (см. init).

        photoPreview.translatesAutoresizingMaskIntoConstraints = false
        photoPreview.contentMode = .scaleAspectFill
        photoPreview.clipsToBounds = true
        photoPreview.isHidden = true

        photoLabel.translatesAutoresizingMaskIntoConstraints = false
        photoLabel.font = Font.regular(13)
        photoLabel.textColor = DivoColorPalette.secondaryText
        photoLabel.textAlignment = .center
        photoLabel.numberOfLines = 0
        photoLabel.text = field.placeholderKey.map { OnboardingStrings.resolve($0) }

        photoArea.addSubview(photoPreview)
        photoArea.addSubview(photoLabel)
        NSLayoutConstraint.activate([
            photoPreview.topAnchor.constraint(equalTo: photoArea.topAnchor),
            photoPreview.leadingAnchor.constraint(equalTo: photoArea.leadingAnchor),
            photoPreview.trailingAnchor.constraint(equalTo: photoArea.trailingAnchor),
            photoPreview.bottomAnchor.constraint(equalTo: photoArea.bottomAnchor),

            photoLabel.centerXAnchor.constraint(equalTo: photoArea.centerXAnchor),
            photoLabel.centerYAnchor.constraint(equalTo: photoArea.centerYAnchor),
            photoLabel.leadingAnchor.constraint(greaterThanOrEqualTo: photoArea.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            photoLabel.trailingAnchor.constraint(lessThanOrEqualTo: photoArea.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])

        addSubview(photoArea)
        addSubview(helpLabel)
        NSLayoutConstraint.activate([
            photoArea.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            photoArea.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            photoArea.topAnchor.constraint(equalTo: topAnchor, constant: DivoDesignTokens.Spacing.s),
            photoArea.heightAnchor.constraint(equalToConstant: 220),

            helpLabel.leadingAnchor.constraint(equalTo: photoArea.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            helpLabel.trailingAnchor.constraint(equalTo: photoArea.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
            helpLabel.topAnchor.constraint(equalTo: photoArea.bottomAnchor, constant: 4),
            helpLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    func applyValue(_ value: FormFieldValue) {
        switch field.kind {
        case .text, .multilineText, .email, .url, .phone, .city:
            if case .string(let s) = value { textField.text = s }

        case .picker(let options), .multiPicker(let options, _, _):
            if case .option(let id) = value, let opt = options.first(where: { $0.id == id }) {
                pickerButton.setTitle(OnboardingStrings.resolve(opt.titleKey), for: .normal)
                pickerButton.setTitleColor(DivoColorPalette.primaryText, for: .normal)
            }

        case .country:
            if case .option(let id) = value {
                pickerButton.setTitle(id, for: .normal)  // ISO-код — заглушка
                pickerButton.setTitleColor(DivoColorPalette.primaryText, for: .normal)
            }

        case .date:
            if case .date(let d) = value {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                pickerButton.setTitle(formatter.string(from: d), for: .normal)
                pickerButton.setTitleColor(DivoColorPalette.primaryText, for: .normal)
            }

        case .photo:
            if case .asset(let path) = value, !path.isEmpty {
                if let image = UIImage(contentsOfFile: path) {
                    photoPreview.image = image
                    photoPreview.isHidden = false
                    photoLabel.isHidden = true
                } else {
                    // Не смогли подгрузить — оставляем placeholder, но обновляем подпись.
                    photoLabel.text = OnboardingStrings.resolve("onboarding.form.field.profilePhoto.selected")
                    photoLabel.isHidden = false
                    photoPreview.isHidden = true
                }
            } else {
                // Пустое значение — сбрасываем обратно к placeholder.
                photoPreview.image = nil
                photoPreview.isHidden = true
                photoLabel.text = field.placeholderKey.map { OnboardingStrings.resolve($0) }
                photoLabel.isHidden = false
            }
        }
    }

    // MARK: - Actions

    @objc private func textChanged() {
        let value: FormFieldValue = (textField.text?.isEmpty ?? true) ? .empty : .string(textField.text ?? "")
        onValueChanged?(value)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textChanged()
    }
}
