//
//  SearchFilterController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Display
import UIKit
import TelegramCore

final class SearchFilterController: UIViewController, UITextFieldDelegate {
    
    var currentFilters: SearchFilterState
    
    var genderOptions: [FilterOptionItem] = []
    var roleOptions: [FilterOptionItem] = [
        FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllRoles),
        FilterOptionItem(id: "model", title: DivoStrings.debugModel),
        FilterOptionItem(id: "new_face", title: DivoStrings.debugNewTalent),
        FilterOptionItem(id: "agency_employee", title: DivoStrings.debugAgency)
    ]
    
    lazy var countryOptions:[FilterOptionItem] = {
        var options = [FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllCountries)]
        options.append(contentsOf: CountryHelper.getAllCountries())
        return options
    }()
    
    var onApply: ((SearchFilterState) -> Void)?
    var onSelectCountry: ((@escaping (String, String) -> Void) -> Void)?
    
    private let stackView = UIStackView()
    private let roleRow = FilterRowView(title: DivoStrings.debugRole)
    private let genderRow = FilterRowView(title: DivoStrings.paramGender)
    private let countryRow = FilterRowView(title: DivoStrings.debugCountry)
    
    private let cityTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = DivoStrings.debugCity
        tf.backgroundColor = .white
        tf.layer.cornerRadius = 23
        tf.font = Font.regular(16)
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 46))
        tf.leftView = paddingView
        tf.leftViewMode = .always
        tf.rightView = paddingView
        tf.rightViewMode = .always
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let applyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(DivoStrings.feedSearchApplyFilter, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitleColor(UIColor(hexString: "#AFAFB1"), for: .disabled)
        btn.titleLabel?.font = Font.helveticaNeue(20)
        btn.backgroundColor = UIColor(hexString: "#FF772D")
        btn.layer.cornerRadius = 28
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let customNavBar: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.feedSearchFilter
        label.font = Font.medium(16)
        label.textColor = UIColor(hexString: "#222222")
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let resetButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(DivoStrings.feedSearchReset, for: .normal)
        btn.setTitleColor(UIColor(hexString: "#FF772D"), for: .normal)
        btn.titleLabel?.font = Font.regular(15)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        let image = UIImage(bundleImageName: "CloseIcon") ?? UIImage(systemName: "xmark")
        button.setImage(image, for: .normal)
        button.tintColor = .black
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 12
        button.layer.masksToBounds = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    init(currentFilters: SearchFilterState) {
        self.currentFilters = currentFilters
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hexString: "#F0F0F0")
        setupCustomNavBar()
        setupUI()
        updateUI()
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
    }
    
    
    private func setupCustomNavBar() {
        view.addSubview(customNavBar)
        customNavBar.addSubview(closeButton)
        customNavBar.addSubview(titleLabel)
        customNavBar.addSubview(resetButton)
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        closeButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        resetButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        resetButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        NSLayoutConstraint.activate([
            customNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            customNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customNavBar.heightAnchor.constraint(equalToConstant: 50),
            
            closeButton.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.centerXAnchor.constraint(equalTo: customNavBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
            
            resetButton.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor, constant: -16),
            resetButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor)
        ])
    }
    
    private func setupUI() {
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        
        let innerStack = UIStackView(arrangedSubviews: [roleRow, genderRow, countryRow])
        innerStack.axis = .vertical
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.spacing = 16
        
        stackView.addArrangedSubview(innerStack)
        
        cityTextField.delegate = self
        cityTextField.addTarget(self, action: #selector(cityChanged), for: .editingChanged)
        
        NSLayoutConstraint.activate([cityTextField.heightAnchor.constraint(equalToConstant: 46)])
        stackView.addArrangedSubview(cityTextField)
        
        view.addSubview(applyButton)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: 32),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            applyButton.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        roleRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(roleTapped)))
        genderRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(genderTapped)))
        countryRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(countryTapped)))
    }
    
    private func createDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(hexString: "#E5E5EA")
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([view.heightAnchor.constraint(equalToConstant: 1)])
        
        let container = UIView()
        container.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
    
    private func updateUI() {
        let roleText = currentFilters.roleTitles.isEmpty ? DivoStrings.feedSearchAllRoles : currentFilters.roleTitles.joined(separator: ", ")
        roleRow.setValue(roleText)

        let genderText = currentFilters.genderTitles.isEmpty ? DivoStrings.feedSearchAllGenders : currentFilters.genderTitles.joined(separator: ", ")
        genderRow.setValue(genderText)

        let countryText = currentFilters.countryTitles.isEmpty ? DivoStrings.feedSearchAllCountries : currentFilters.countryTitles.joined(separator: ", ")
        countryRow.setValue(countryText)
        
        cityTextField.text = currentFilters.city

        let hasFilters = currentFilters.hasActiveFilters
        applyButton.isEnabled = hasFilters
        applyButton.backgroundColor = hasFilters ? UIColor(hexString: "#FF772D") : UIColor(hexString: "#E4E4E4")
    }
    
    @objc private func closeTapped() { dismiss(animated: true) }
    
    @objc private func resetTapped() {
        currentFilters.reset()
        updateUI()
    }
    
    @objc private func applyTapped() {
        onApply?(currentFilters)
        dismiss(animated: true)
    }
    
    @objc private func cityChanged() {
        currentFilters.city = cityTextField.text
        updateUI()
    }
    
    @objc private func dismissKeyboard() { view.endEditing(true) }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { textField.resignFirstResponder(); return true }
    
    @objc private func roleTapped() {
        let selectedIds = currentFilters.roleIds 
        let vc = FilterOptionsController(title: DivoStrings.debugRole, options: roleOptions, selectedOptionIds: selectedIds, isMultiSelect: true)
        
        vc.onSelectMulti = {[weak self] selectedItems in
            self?.currentFilters.roleIds = selectedItems.map { $0.id }
            self?.currentFilters.roleTitles = selectedItems.map { $0.title }
            self?.updateUI()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func genderTapped() {
        var displayOptions = [FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllGenders)]
        displayOptions.append(contentsOf: genderOptions)
        
        let selectedIds = currentFilters.genderIds
        let vc = FilterOptionsController(title: DivoStrings.paramGender, options: displayOptions, selectedOptionIds: selectedIds, isMultiSelect: true)
        
        vc.onSelectMulti = { [weak self] selectedItems in
            self?.currentFilters.genderIds = selectedItems.map { $0.id }
            self?.currentFilters.genderTitles = selectedItems.map { $0.title }
            self?.updateUI()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func countryTapped() {
        // Передаем все выбранные страны (если есть)
        let selectedIds = currentFilters.countryIds
        
        let vc = FilterOptionsController(
            title: DivoStrings.debugCountry,
            options: countryOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            showSearch: true
        )

        vc.onSelectMulti = { [weak self] selectedItems in
            if selectedItems.isEmpty {
                self?.currentFilters.countryIds = []
                self?.currentFilters.countryTitles = []
            } else {
                self?.currentFilters.countryIds = selectedItems.map { $0.id }
                self?.currentFilters.countryTitles = selectedItems.map { $0.title }
            }
            self?.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
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
