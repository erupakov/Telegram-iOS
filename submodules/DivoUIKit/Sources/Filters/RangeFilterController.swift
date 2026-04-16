//
//  RangeFilterController.swift
//  DivoUIKit
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import UIKit
import Display
import DivoCore

/// Экран выбора числового диапазона (возраст, рост, вес и т.п.).
///
/// Параметризован значениями `min`/`max` и текущим выбором. Колбэк `onSave` получает
/// `(lower, upper)` при сохранении и `nil` при сбросе.
public final class RangeFilterController: UIViewController, UITextFieldDelegate {

    private let filterTitle: String
    private let minValue: Double
    private let maxValue: Double
    private let isSingleValue: Bool
    private let isOpenPresent: Bool
    private let isResetButton: Bool

    public var onSave: ((Double?, Double?) -> Void)?

    private let customNavBar = UIView()

    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill

        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = UIImage(systemName: "chevron.left", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = DivoColorPalette.primaryText

        button.setTitle(DivoStrings.back, for: .normal)
        button.setTitleColor(DivoColorPalette.primaryText, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)

        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 20)

        button.layer.applyDivoShadow()

        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let closeCircleButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = 20
        let image = DivoImage.searchCloseIcon
        button.setImage(image, for: .normal)
        button.tintColor = DivoColorPalette.primaryText

        button.layer.applyDivoShadow()

        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = Font.medium(16)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        return titleLabel
    }()

    private let saveButton: UIButton = {
        let saveButton = UIButton(type: .custom)
        saveButton.backgroundColor = DivoColorPalette.accent
        saveButton.layer.cornerRadius = DivoDesignTokens.Radius.pill
        saveButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        saveButton.tintColor = DivoColorPalette.primaryTextOnDark
        saveButton.layer.applyDivoShadow()
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        return saveButton
    }()

    private let minTextField = UITextField()
    private let maxTextField = UITextField()

    private let dashLabel: UILabel = {
        let dashLabel = UILabel()
        dashLabel.text = "—"
        dashLabel.font = Font.regular(16)
        dashLabel.textColor = DivoColorPalette.primaryText
        dashLabel.translatesAutoresizingMaskIntoConstraints = false
        return dashLabel
    }()

    private let rangeSlider = RangeSlider()

    private let deleteButton: UIButton = {
        let deleteButton = UIButton(type: .custom)
        deleteButton.setTitle(DivoStrings.feedSearchResetParameter, for: .normal)
        deleteButton.setTitleColor(DivoColorPalette.primaryTextOnDark, for: .normal)
        deleteButton.titleLabel?.font = Font.helveticaNeue(18)
        deleteButton.backgroundColor = DivoColorPalette.secondaryButtonBackground
        deleteButton.layer.cornerRadius = DivoDesignTokens.Radius.card
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        return deleteButton
    }()
    
    public init(
        title: String,
        min: Double,
        max: Double,
        currentLower: Double?,
        currentUpper: Double?,
        isSingleValue: Bool = false,
        isOpenPresent: Bool = false,
        isResetButton: Bool = true
    ) {
        self.filterTitle = title
        self.minValue = min
        self.maxValue = max
        self.isSingleValue = isSingleValue
        self.isOpenPresent = isOpenPresent
        self.isResetButton = isResetButton
        super.init(nibName: nil, bundle: nil)

        self.rangeSlider.minimumValue = CGFloat(min)
        self.rangeSlider.maximumValue = CGFloat(max)
        self.rangeSlider.isSingleSlider = isSingleValue
        
        if isSingleValue {
            self.rangeSlider.upperValue = CGFloat(currentUpper ?? max)
            self.rangeSlider.lowerValue = CGFloat(min)
        } else {
            self.rangeSlider.lowerValue = CGFloat(currentLower ?? min)
            self.rangeSlider.upperValue = CGFloat(currentUpper ?? max)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = DivoColorPalette.screenBackground

        setupNavBar()
        setupUI()
        updateTextFields()
        updateDeleteButtonState()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    private func setupNavBar() {
        view.addSubview(customNavBar)
        customNavBar.translatesAutoresizingMaskIntoConstraints = false

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.addDivoPressState(.pill)

        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.addDivoPressState(.primary)

        closeCircleButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeCircleButton.addDivoPressState(.pill)

        titleLabel.text = filterTitle

        if isOpenPresent {
            customNavBar.addSubview(closeCircleButton)
        } else {
            customNavBar.addSubview(backButton)
        }
        customNavBar.addSubview(titleLabel)
        customNavBar.addSubview(saveButton)

        if isOpenPresent {
            NSLayoutConstraint.activate([
                customNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DivoDesignTokens.Spacing.m),
                customNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                customNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                customNavBar.heightAnchor.constraint(equalToConstant: 50),
                
                closeCircleButton.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                closeCircleButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
                closeCircleButton.heightAnchor.constraint(equalToConstant: 40),
                closeCircleButton.widthAnchor.constraint(equalToConstant: 40),
                
                titleLabel.centerXAnchor.constraint(equalTo: customNavBar.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
                
                saveButton.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                saveButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
                saveButton.widthAnchor.constraint(equalToConstant: 40),
                saveButton.heightAnchor.constraint(equalToConstant: 40),
            ])
        } else {
            NSLayoutConstraint.activate([
                customNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DivoDesignTokens.Spacing.m),
                customNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                customNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                customNavBar.heightAnchor.constraint(equalToConstant: 50),
                
                backButton.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                backButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
                backButton.heightAnchor.constraint(equalToConstant: 40),
                
                titleLabel.centerXAnchor.constraint(equalTo: customNavBar.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
                
                saveButton.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                saveButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
                saveButton.widthAnchor.constraint(equalToConstant: 40),
                saveButton.heightAnchor.constraint(equalToConstant: 40),
            ])
        }
    }
    
    private func setupUI() {
        let container = UIView()
        container.backgroundColor = DivoColorPalette.cardBackground
        container.layer.cornerRadius = DivoDesignTokens.Radius.l
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        setupTextField(minTextField)
        setupTextField(maxTextField)

        let textFieldsStack = UIStackView(arrangedSubviews: [minTextField, dashLabel, maxTextField])
        textFieldsStack.axis = .horizontal
        textFieldsStack.spacing = 12
        textFieldsStack.alignment = .center
        textFieldsStack.distribution = .fill
        textFieldsStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textFieldsStack)

        rangeSlider.translatesAutoresizingMaskIntoConstraints = false
        rangeSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        container.addSubview(rangeSlider)

        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton.addDivoPressState(.secondary)

        if isResetButton {
            view.addSubview(deleteButton)
        }

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            container.bottomAnchor.constraint(equalTo: rangeSlider.bottomAnchor, constant: 20),

            minTextField.widthAnchor.constraint(equalTo: maxTextField.widthAnchor),
            minTextField.heightAnchor.constraint(equalToConstant: 46),
            maxTextField.heightAnchor.constraint(equalToConstant: 46),

            textFieldsStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            textFieldsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            textFieldsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            rangeSlider.topAnchor.constraint(equalTo: textFieldsStack.bottomAnchor, constant: 20),
            rangeSlider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            rangeSlider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            rangeSlider.heightAnchor.constraint(equalToConstant: 28),
        ])

        if isResetButton {
            NSLayoutConstraint.activate([
                deleteButton.topAnchor.constraint(equalTo: container.bottomAnchor, constant: 32),
                deleteButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                deleteButton.heightAnchor.constraint(equalToConstant: 48)
            ])
        }

        minTextField.isHidden = isSingleValue
        dashLabel.isHidden = isSingleValue
    }

    private func setupTextField(_ textField: UITextField) {
        textField.backgroundColor = DivoColorPalette.cardBackground
        textField.layer.cornerRadius = 23 // TODO: DS alignment — не в шкале Radius (border inset от card=24)
        textField.layer.borderWidth = 1
        textField.layer.borderColor = DivoColorPalette.primaryText.withAlphaComponent(0.2).cgColor
        textField.textAlignment = .center
        textField.font = Font.regular(16)
        textField.textColor = DivoColorPalette.systemLabelSecondary
        textField.keyboardType = .numberPad
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }

    // MARK: - Actions

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func closeTapped() {
        navigationController?.dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        view.endEditing(true)
        if isSingleValue {
            onSave?(nil, Double(rangeSlider.upperValue))
        } else {
            onSave?(Double(rangeSlider.lowerValue), Double(rangeSlider.upperValue))
        }
        if isOpenPresent {
            navigationController?.dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @objc private func deleteTapped() {
        onSave?(nil, nil)
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func sliderChanged() {
        updateTextFields()
        updateDeleteButtonState()
    }

    private func updateTextFields() {
        if isSingleValue {
            maxTextField.text = "\(Int(rangeSlider.upperValue))"
        } else {
            minTextField.text = "\(Int(rangeSlider.lowerValue))"
            maxTextField.text = "\(Int(rangeSlider.upperValue))"
        }
    }

    private func updateDeleteButtonState() {
        let isDefault: Bool
        if isSingleValue {
            isDefault = Int(rangeSlider.upperValue) == Int(rangeSlider.maximumValue)
        } else {
            isDefault = Int(rangeSlider.lowerValue) == Int(rangeSlider.minimumValue) && Int(rangeSlider.upperValue) == Int(rangeSlider.maximumValue)
        }
        deleteButton.isEnabled = !isDefault
        deleteButton.backgroundColor = isDefault ? DivoColorPalette.buttonDisabledBackground : DivoColorPalette.secondaryButtonBackground
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard let text = textField.text, let value = Double(text) else { return }

        if textField == minTextField {
            rangeSlider.lowerValue = CGFloat(value)
        } else if textField == maxTextField {
            rangeSlider.upperValue = CGFloat(value)
        }
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text, let enteredValue = Double(text) else {
            updateTextFields()
            return
        }

        let clampedValue = max(minValue, min(enteredValue, maxValue))

        if textField == minTextField {
            if clampedValue > Double(rangeSlider.upperValue) {
                rangeSlider.upperValue = CGFloat(clampedValue)
            }
            rangeSlider.lowerValue = CGFloat(clampedValue)
            
        } else if textField == maxTextField {
            if clampedValue < Double(rangeSlider.lowerValue) && !isSingleValue {
                rangeSlider.lowerValue = CGFloat(clampedValue)
            }
            rangeSlider.upperValue = CGFloat(clampedValue)
        }
        updateTextFields()
        updateDeleteButtonState()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}
