//
//  OnboardingFormFieldRow.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 20.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

// MARK: - Field row

/// Универсальная строка поля формы. Отрисовка зависит от `field.kind`.
/// Скелетная реализация — Михаил подменяет на финальные DivoUIKit-компоненты.
final class OnboardingFormFieldRow: UIView {

    let field: FormField
    var onValueChanged: ((FormFieldValue) -> Void)?
    var presentController: (() -> Void)?
    var isGrouped: Bool = false {
        didSet {
            if oldValue != isGrouped {
                updateIsGrouped()
            }
        }
    }

    private let helpLabel: UILabel = {
        let helpLabel = UILabel()
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = Font.regular(12)
        helpLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        helpLabel.numberOfLines = 0
        return helpLabel
    }()
    private var helpLabelTopConstraint: NSLayoutConstraint!
    
    var textField: DivoTextField

    private lazy var pickerRow = FilterRowView(title: OnboardingStrings.resolve(field.titleKey ?? ""))
    private var pickerRowTitle: String?
    
    private let photoArea = DashedBorderControl()
    
    private let photoLabel: UILabel = {
        let photoLabel = UILabel()
        photoLabel.translatesAutoresizingMaskIntoConstraints = false
        photoLabel.font = Font.bold(16)
        photoLabel.textColor = DivoColorPalette.primaryText
        photoLabel.textAlignment = .center
        photoLabel.numberOfLines = 0
        return photoLabel
    }()
    
    private let photoPreview: UIImageView = {
        let photoPreview = UIImageView()
        photoPreview.translatesAutoresizingMaskIntoConstraints = false
        photoPreview.contentMode = .scaleAspectFit
        photoPreview.clipsToBounds = true
        photoPreview.isHidden = true
        return photoPreview
    }()
    
    private let emptyIconPhoto: UIImageView = {
        let emptyIconPhoto = UIImageView()
        emptyIconPhoto.translatesAutoresizingMaskIntoConstraints = false
        emptyIconPhoto.contentMode = .scaleAspectFill
        emptyIconPhoto.clipsToBounds = true
        emptyIconPhoto.isHidden = true
        emptyIconPhoto.image = DivoImage.uploadPhoto
        return emptyIconPhoto
    }()
    

    init(field: FormField, value: FormFieldValue?) {
        self.field = field
        
        self.textField = DivoTextField(title: "", prefix: "")
        self.textField.textField.attributedPlaceholder = NSAttributedString(
            string: field.placeholderKey.map(OnboardingStrings.resolve) ?? "",
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        self.textField.isUserInteractionEnabled = true
        
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        self.textField.textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        self.textField.textField.returnKeyType = .next
        self.textField.textField.autocapitalizationType = .words
        
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
        photoArea.isUserInteractionEnabled = false
        addPressState(alpha: DivoDesignTokens.PressState.alpha, scale: DivoDesignTokens.PressState.scaleListRow)
        
        updateDropdownsUI()
    }

    @objc private func rowTapped() {
        switch field.kind {
        case .text, .multilineText, .email, .url, .phone, .city:
            textField.becomeFirstResponder()
        case .picker, .multiPicker, .country, .date, .photo:
            presentController?()
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }

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
        textField.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField.view)
        addSubview(helpLabel)
        
        helpLabelTopConstraint = helpLabel.topAnchor.constraint(equalTo: textField.view.bottomAnchor, constant: DivoDesignTokens.Spacing.xs)
        NSLayoutConstraint.activate([
            textField.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.view.topAnchor.constraint(equalTo: topAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 46),
            
            helpLabel.leadingAnchor.constraint(equalTo: textField.view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            helpLabel.trailingAnchor.constraint(lessThanOrEqualTo: textField.view.trailingAnchor),
            helpLabelTopConstraint,
            helpLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        helpLabel.isHidden = (field.helpTextKey == nil)
        helpLabelTopConstraint.constant = (field.helpTextKey == nil) ? 0 : DivoDesignTokens.Spacing.xs
        helpLabel.text = field.helpTextKey.map { OnboardingStrings.resolve($0) }
        helpLabel.textAlignment = .left
    }
    
    private func updateDropdownsUI() {
        let emptyKey = field.placeholderKey ?? field.titleKey ?? ""
        pickerRow.setItems(pickerRowTitle.map { [$0] } ?? [], emptyTitle: OnboardingStrings.resolve(emptyKey))
    }

    private func installPickerButton() {
        pickerRow.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(pickerRow)
        addSubview(helpLabel)
        
        helpLabelTopConstraint = helpLabel.topAnchor.constraint(equalTo: pickerRow.bottomAnchor, constant: DivoDesignTokens.Spacing.xs)
        NSLayoutConstraint.activate([
            pickerRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            pickerRow.trailingAnchor.constraint(equalTo: trailingAnchor),
            pickerRow.topAnchor.constraint(equalTo: topAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 46),
            
            helpLabel.leadingAnchor.constraint(equalTo: pickerRow.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            helpLabel.trailingAnchor.constraint(lessThanOrEqualTo: pickerRow.trailingAnchor),
            helpLabelTopConstraint,
            helpLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        helpLabel.isHidden = (field.helpTextKey == nil)
        helpLabelTopConstraint.constant = (field.helpTextKey == nil) ? 0 : DivoDesignTokens.Spacing.xs
        helpLabel.text = field.helpTextKey.map { OnboardingStrings.resolve($0) }
        helpLabel.textAlignment = .left
    }

    private func installPhotoArea() {
        photoArea.translatesAutoresizingMaskIntoConstraints = false
        photoLabel.text = field.placeholderKey.map { OnboardingStrings.resolve($0) }

        addSubview(photoArea)
        photoArea.addSubview(photoPreview)
        photoArea.addSubview(emptyIconPhoto)
        photoArea.addSubview(photoLabel)
        photoArea.addSubview(helpLabel)
        NSLayoutConstraint.activate([
            photoArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            photoArea.trailingAnchor.constraint(equalTo: trailingAnchor),
            photoArea.topAnchor.constraint(equalTo: topAnchor),
            photoArea.bottomAnchor.constraint(equalTo: bottomAnchor),
            photoArea.heightAnchor.constraint(equalToConstant: 370),
            
            photoPreview.topAnchor.constraint(equalTo: photoArea.topAnchor),
            photoPreview.leadingAnchor.constraint(equalTo: photoArea.leadingAnchor),
            photoPreview.trailingAnchor.constraint(equalTo: photoArea.trailingAnchor),
            photoPreview.bottomAnchor.constraint(equalTo: photoArea.bottomAnchor),
            
            emptyIconPhoto.centerXAnchor.constraint(equalTo: photoArea.centerXAnchor),
            emptyIconPhoto.widthAnchor.constraint(equalToConstant: 68),
            emptyIconPhoto.heightAnchor.constraint(equalToConstant: 68),
            emptyIconPhoto.bottomAnchor.constraint(equalTo: photoLabel.topAnchor, constant: -DivoDesignTokens.Spacing.m),

            photoLabel.centerXAnchor.constraint(equalTo: photoArea.centerXAnchor),
            photoLabel.centerYAnchor.constraint(equalTo: photoArea.centerYAnchor, constant: DivoDesignTokens.Spacing.m),
            photoLabel.leadingAnchor.constraint(greaterThanOrEqualTo: photoArea.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            photoLabel.trailingAnchor.constraint(lessThanOrEqualTo: photoArea.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            helpLabel.leadingAnchor.constraint(lessThanOrEqualTo: photoArea.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            helpLabel.trailingAnchor.constraint(lessThanOrEqualTo: photoArea.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            helpLabel.topAnchor.constraint(equalTo: photoLabel.bottomAnchor, constant: 6),
            helpLabel.centerXAnchor.constraint(equalTo: photoArea.centerXAnchor),
        ])
        
        helpLabel.font = Font.regular(14)
        helpLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        helpLabel.isHidden = (field.helpTextKey == nil)
        helpLabel.text = field.helpTextKey.map { OnboardingStrings.resolve($0) }
        helpLabel.textAlignment = .center
    }

    func updateIsGrouped() {
        textField.isGrouped = self.isGrouped
    }

    func applyValue(_ value: FormFieldValue) {
        switch field.kind {
        case .text, .multilineText, .email, .url, .phone, .city:
            if case .string(let s) = value { textField.textField.text = s }

        case .picker(let options), .multiPicker(let options, _, _):
            if case .option(let id) = value, let opt = options.first(where: { $0.id == id }) {
                pickerRowTitle = OnboardingStrings.resolve(opt.titleKey)
                updateDropdownsUI()
            }

        case .country(let options):
            if case .option(let id) = value, let opt = options.first(where: { $0.id == id }) {
                pickerRowTitle = OnboardingStrings.resolve(opt.titleKey)
                updateDropdownsUI()
            }

        case .date:
            if case .date(let d) = value {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                pickerRowTitle = formatter.string(from: d)
                updateDropdownsUI()
            }

        case .photo:
            if case .asset(let path) = value, !path.isEmpty {
                let image = UIImage(contentsOfFile: path)
                divoLog("applyValue.photo[\(field.key)]: path=\(path), imageLoaded=\(image != nil), photoPreview.bounds=\(photoPreview.bounds)", level: .info)
                if let image = image {
                    photoPreview.image = image
                    photoPreview.isHidden = false

                    emptyIconPhoto.isHidden = true
                    photoLabel.isHidden = true
                    helpLabel.isHidden = true

                    // Когда фото загружено — убираем пунктирную обводку и серый card-фон,
                    // чтобы фото отображалось чисто.
                    photoArea.isBordered = false

                    // После выбора фото view может быть ещё не layout'нут (dismiss-анимация picker'а
                    // только завершилась). Форсируем layout, чтобы photoPreview получил bounds и отрисовался.
                    setNeedsLayout()
                    layoutIfNeeded()
                } else {
                    // Не смогли подгрузить — оставляем placeholder, но обновляем подпись.
                    photoLabel.text = OnboardingStrings.resolve("onboarding.form.field.profilePhoto.selected")
                    photoLabel.isHidden = false
                    emptyIconPhoto.isHidden = false
                    helpLabel.isHidden = false
                    photoPreview.isHidden = true
                    photoArea.isBordered = true
                }
            } else {
                // Пустое значение — сбрасываем обратно к placeholder.
                photoPreview.image = nil
                photoPreview.isHidden = true
                photoLabel.text = field.placeholderKey.map { OnboardingStrings.resolve($0) }
                photoLabel.isHidden = false
                emptyIconPhoto.isHidden = false
                helpLabel.isHidden = false
                photoArea.isBordered = true
            }
        }
    }

    // MARK: - Actions

    @objc private func textChanged() {
        let value: FormFieldValue = (textField.textField.text?.isEmpty ?? true) ? .empty : .string(textField.textField.text ?? "")
        onValueChanged?(value)
    }
}
