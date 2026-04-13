//
//  RangeFilterController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import UIKit
import Display
import DivoCore
import DivoUIKit

final class RangeFilterController: UIViewController, UITextFieldDelegate {
    
    private let filterTitle: String
    private let minValue: Double
    private let maxValue: Double
    private let unit: String
    
    var onSave: ((Double, Double)?) -> Void
    
    private let customNavBar = UIView()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        
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
        
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 12
        button.layer.masksToBounds = false
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = Font.medium(16)
        titleLabel.textColor = .black
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        return titleLabel
    }()
    
    private let saveButton: UIButton = {
        let saveButton = UIButton(type: .custom)
        saveButton.backgroundColor = DivoColorPalette.accent
        saveButton.layer.cornerRadius = 20
        saveButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
        saveButton.tintColor = .white
        saveButton.layer.shadowColor = UIColor.black.cgColor
        saveButton.layer.shadowOpacity = 0.08
        saveButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        saveButton.layer.shadowRadius = 12
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
        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle(DivoStrings.feedSearchResetParameter, for: .normal)
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.titleLabel?.font = Font.helveticaNeue(18)
        deleteButton.backgroundColor = UIColor(hexString: "#343434")
        deleteButton.layer.cornerRadius = 24
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        return deleteButton
    }()
    
    init(title: String, min: Double, max: Double, unit: String, currentLower: Double?, currentUpper: Double?, onSave: @escaping ((Double, Double)?) -> Void) {
        self.filterTitle = title
        self.minValue = min
        self.maxValue = max
        self.unit = unit
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
        
        self.rangeSlider.minimumValue = CGFloat(min)
        self.rangeSlider.maximumValue = CGFloat(max)
        self.rangeSlider.lowerValue = CGFloat(currentLower ?? min)
        self.rangeSlider.upperValue = CGFloat(currentUpper ?? max)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(hexString: "#F0F0F0")
        
        setupNavBar()
        setupUI()
        updateTextFields()
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
    }
    
    private func setupNavBar() {
        view.addSubview(customNavBar)
        customNavBar.translatesAutoresizingMaskIntoConstraints = false
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        closeButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        saveButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        titleLabel.text = filterTitle
        
        customNavBar.addSubview(closeButton)
        customNavBar.addSubview(titleLabel)
        customNavBar.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            customNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            customNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customNavBar.heightAnchor.constraint(equalToConstant: 50),
            
            closeButton.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.centerXAnchor.constraint(equalTo: customNavBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            
            saveButton.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor, constant: -16),
            saveButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 40),
            saveButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupUI() {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 16
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
        view.addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: rangeSlider.bottomAnchor, constant: 20),
            
            minTextField.widthAnchor.constraint(equalTo: maxTextField.widthAnchor),
            minTextField.heightAnchor.constraint(equalToConstant: 46),
            maxTextField.heightAnchor.constraint(equalToConstant: 46),
            
            textFieldsStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            textFieldsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            textFieldsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            rangeSlider.topAnchor.constraint(equalTo: textFieldsStack.bottomAnchor, constant: 20),
            rangeSlider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            rangeSlider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            rangeSlider.heightAnchor.constraint(equalToConstant: 28),
            
            deleteButton.topAnchor.constraint(equalTo: container.bottomAnchor, constant: 32),
            deleteButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            deleteButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    private func setupTextField(_ textField: UITextField) {
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 23
        textField.layer.borderWidth = 1
        textField.layer.borderColor = DivoColorPalette.primaryText.withAlphaComponent(0.2).cgColor
        textField.textAlignment = .center
        textField.font = Font.regular(16)
        textField.textColor = UIColor(hexString: "#3C3C43")
        textField.keyboardType = .numberPad
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func saveTapped() {
        onSave((Double(rangeSlider.lowerValue), Double(rangeSlider.upperValue)))
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func deleteTapped() {
        onSave(nil)
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func sliderChanged() {
        updateTextFields()
    }
    
    private func updateTextFields() {
        minTextField.text = "\(Int(rangeSlider.lowerValue))"
        maxTextField.text = "\(Int(rangeSlider.upperValue))"
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard let text = textField.text, let value = Double(text) else { return }
        
        if textField == minTextField {
            rangeSlider.lowerValue = CGFloat(value)
        } else if textField == maxTextField {
            rangeSlider.upperValue = CGFloat(value)
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func buttonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            sender.alpha = 0.6
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        })
    }
    
    @objc private func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, animations: {
            sender.alpha = 1.0
            sender.transform = .identity
        })
    }
}
