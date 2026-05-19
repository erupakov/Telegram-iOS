import UIKit
import Display
import DivoCore
import DivoUIKit

/// Bottom-sheet с UIDatePicker. Открывается из `OnboardingFormStepViewController`
/// (через coordinator) когда юзер тапает по полю с `FormFieldKind.date(...)`.
///
/// Михаил при вёрстке оставляет API (`init(titleKey:selectedDate:min:max:presentation:onSelect:)`)
/// и контракт `onSelect: (Date?) -> Void` неизменным; меняет стиль кнопки подтверждения,
/// типографику и dim-фон, если потребует дизайн.
public final class OnboardingDateSheetViewController: UIViewController {

    private let titleKey: String
    private let min: Date?
    private let max: Date?
    private let presentation: FormFieldKind.DatePresentation
    private let onSelect: (Date?) -> Void

    private var pickedDate: Date

    private let titleLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let datePicker = UIDatePicker()

    public init(
        titleKey: String,
        selectedDate: Date?,
        min: Date?,
        max: Date?,
        presentation: FormFieldKind.DatePresentation,
        onSelect: @escaping (Date?) -> Void
    ) {
        self.titleKey = titleKey
        self.min = min
        self.max = max
        self.presentation = presentation
        self.onSelect = onSelect
        // Стартовая дата: то, что юзер выбирал раньше; иначе — разумный дефолт
        // (для date-of-birth — 20 лет назад, для остальных — сегодня).
        if let s = selectedDate {
            self.pickedDate = s
        } else {
            self.pickedDate = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.sheetBackgroundLight
        setupUI()
    }

    private func setupUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Font.helveticaNeue(17)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.textAlignment = .center
        titleLabel.text = OnboardingStrings.resolve(titleKey)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle(DivoStrings.cancel, for: .normal)
        cancelButton.setTitleColor(DivoColorPalette.secondaryText, for: .normal)
        cancelButton.titleLabel?.font = Font.regular(15)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
        confirmButton.tintColor = DivoColorPalette.accent
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .date
        if #available(iOS 14.0, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
        datePicker.date = pickedDate
        if let min = min { datePicker.minimumDate = min }
        if let max = max { datePicker.maximumDate = max }
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)

        view.addSubview(titleLabel)
        view.addSubview(cancelButton)
        view.addSubview(confirmButton)
        view.addSubview(datePicker)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            cancelButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),

            confirmButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            confirmButton.widthAnchor.constraint(equalToConstant: 32),
            confirmButton.heightAnchor.constraint(equalToConstant: 32),

            datePicker.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            datePicker.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
    }

    @objc private func dateChanged() {
        pickedDate = datePicker.date
    }

    @objc private func confirmTapped() {
        onSelect(pickedDate)
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}
