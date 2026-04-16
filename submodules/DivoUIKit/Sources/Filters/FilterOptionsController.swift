//
//  FilterOptionsController.swift
//  DivoUIKit
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Display
import UIKit
import DivoCore

/// Экран выбора из списка опций (одиночный или множественный выбор) с опциональным поиском.
///
/// Параметризован `FilterOptionItem` — общим value type DivoUIKit. Колбэк `onSave` получает
/// массив выбранных опций (пустой массив означает сброс/«все»).
public final class FilterOptionsController: UIViewController {

    private var allOptions: [FilterOptionItem]
    private var filteredOptions: [FilterOptionItem]
    private var selectedOptionIds: Set<String>
    private let isMultiSelect: Bool
    private let showSearch: Bool
    private let isOpenPresent: Bool
    private let isResetButton: Bool
   
    public var onSave: (([FilterOptionItem]) -> Void)?

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.backgroundColor = .clear
        return stackView
    }()

    private let customNavBar: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let closeButton: UIButton = {
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

    private let searchFieldContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.layer.applyDivoShadow()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let searchIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = DivoImage.searchFieldIcon
        imageView.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let searchTextField: UITextField = {
        let field = UITextField()
        field.font = Font.regular(14)
        field.textColor = DivoColorPalette.primaryText
        field.tintColor = DivoColorPalette.accentSecondary
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
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
        options: [FilterOptionItem],
        selectedOptionIds: [String],
        isMultiSelect: Bool = false,
        showSearch: Bool = false,
        isOpenPresent: Bool = false,
        isResetButton: Bool = true
    ) {
        self.titleLabel.text = title
        self.allOptions = options
        self.filteredOptions = options
        self.selectedOptionIds = Set(selectedOptionIds)
        self.isMultiSelect = isMultiSelect
        self.showSearch = showSearch
        self.isOpenPresent = isOpenPresent
        self.isResetButton = isResetButton
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = DivoColorPalette.screenBackground

        setupCustomNavBar()
        setupSearchField()
        setupScrollView()
        setupConstraints()

        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        closeButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        closeButton.addDivoPressState(.pill)

        closeCircleButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeCircleButton.addDivoPressState(.pill)

        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.addDivoPressState(.primary)

        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton.addDivoPressState(.secondary)

        if showSearch {
            scrollView.keyboardDismissMode = .onDrag

            let tapDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardTap))
            tapDismiss.cancelsTouchesInView = false
            view.addGestureRecognizer(tapDismiss)
        }

        reloadOptions()
    }

    @objc private func dismissKeyboardTap() {
        view.endEditing(true)
    }

    private func setupCustomNavBar() {
        view.addSubview(customNavBar)
        if isOpenPresent {
            customNavBar.addSubview(closeCircleButton)
        } else {
            customNavBar.addSubview(closeButton)
        }
        customNavBar.addSubview(titleLabel)
        customNavBar.addSubview(saveButton)
    }

    private func setupSearchField() {
        if showSearch {
            view.addSubview(searchFieldContainer)
            searchFieldContainer.addSubview(searchIcon)
            searchFieldContainer.addSubview(searchTextField)
        }
    }

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        if isResetButton {
            scrollView.addSubview(deleteButton)
        }

        let backgroundView = UIView()
        backgroundView.backgroundColor = DivoColorPalette.cardBackground
        backgroundView.layer.cornerRadius = DivoDesignTokens.Radius.l
        backgroundView.clipsToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.tag = 999
        scrollView.insertSubview(backgroundView, belowSubview: stackView)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: stackView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor)
        ])
    }

    private func setupConstraints() {
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
                
                closeButton.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                closeButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
                closeButton.heightAnchor.constraint(equalToConstant: 40),
                
                titleLabel.centerXAnchor.constraint(equalTo: customNavBar.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
                
                saveButton.trailingAnchor.constraint(equalTo: customNavBar.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                saveButton.centerYAnchor.constraint(equalTo: customNavBar.centerYAnchor),
                saveButton.widthAnchor.constraint(equalToConstant: 40),
                saveButton.heightAnchor.constraint(equalToConstant: 40),
            ])
        }
        
        if showSearch {
            NSLayoutConstraint.activate([
                searchFieldContainer.topAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: 20),
                searchFieldContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                searchFieldContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                searchFieldContainer.heightAnchor.constraint(equalToConstant: 40),
                
                searchIcon.leadingAnchor.constraint(equalTo: searchFieldContainer.leadingAnchor, constant: 14),
                searchIcon.centerYAnchor.constraint(equalTo: searchFieldContainer.centerYAnchor),
                searchIcon.widthAnchor.constraint(equalToConstant: 20),
                searchIcon.heightAnchor.constraint(equalToConstant: 20),
                
                searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
                searchTextField.trailingAnchor.constraint(equalTo: searchFieldContainer.trailingAnchor, constant: -14),
                searchTextField.topAnchor.constraint(equalTo: searchFieldContainer.topAnchor),
                searchTextField.bottomAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor)
            ])
        }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: showSearch ? searchFieldContainer.bottomAnchor : customNavBar.bottomAnchor, constant: showSearch ? 10.0 : 20.0),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
        ])
        
        if isResetButton {
            NSLayoutConstraint.activate([
                deleteButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 32),
                deleteButton.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                deleteButton.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
                deleteButton.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                deleteButton.heightAnchor.constraint(equalToConstant: 48)
            ])
        }
    }
    
    private func reloadOptions() {
        // Очищаем stackView
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let allOptionId = allOptions.first?.id ?? ""

        for (index, option) in filteredOptions.enumerated() {
            let cell = createOptionCell(
                option: option,
                isSelected: selectedOptionIds.contains(option.id) || (selectedOptionIds.isEmpty && option.id == allOptionId),
                isLast: index == filteredOptions.count - 1
            )

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
            cell.addGestureRecognizer(tapGesture)
            cell.tag = index
            cell.addPressState(alpha: DivoDesignTokens.PressState.alphaOnClear)

            stackView.addArrangedSubview(cell)
        }
        updateDeleteButtonState()
    }

    private func updateDeleteButtonState() {
        let isDefault = selectedOptionIds.isEmpty
        deleteButton.isEnabled = !isDefault
        deleteButton.backgroundColor = isDefault ? DivoColorPalette.buttonDisabledBackground : DivoColorPalette.secondaryButtonBackground
    }

    private func createOptionCell(option: FilterOptionItem, isSelected: Bool, isLast: Bool) -> UIView {
        let cell = UIView()
        cell.backgroundColor = .clear
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.heightAnchor.constraint(equalToConstant: 50).isActive = true
        cell.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - 32).isActive = true

        let label = UILabel()
        label.text = option.title
        label.font = Font.regular(16)
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)

        let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
        checkmark.tintColor = DivoColorPalette.accent
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = !isSelected
        cell.addSubview(checkmark)

        if !isLast {
            let separator = UIView()
            separator.backgroundColor = DivoColorPalette.separatorSystem
            separator.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(separator)

            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                separator.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                separator.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: checkmark.leadingAnchor, constant: -DivoDesignTokens.Spacing.s),

            checkmark.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            checkmark.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 20),
            checkmark.heightAnchor.constraint(equalToConstant: 20)
        ])

        return cell
    }

    @objc private func optionTapped(_ gesture: UITapGestureRecognizer) {
        guard let cell = gesture.view, let index = cell.tag as Int? else { return }
        let option = filteredOptions[index]
        let allOptionId = allOptions.first?.id ?? ""

        if isMultiSelect {
            if option.id == allOptionId {
                selectedOptionIds.removeAll()
            } else {
                if selectedOptionIds.contains(option.id) {
                    selectedOptionIds.remove(option.id)
                } else {
                    selectedOptionIds.insert(option.id)
                }
            }
        } else {
            selectedOptionIds = [option.id]
        }
        reloadOptions()
    }

    @objc private func searchTextChanged() {
        let text = searchTextField.text ?? ""

        if text.isEmpty {
            filteredOptions = allOptions
        } else {
            filteredOptions = allOptions.filter { $0.title.lowercased().contains(text.lowercased()) }
        }

        reloadOptions()
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func closeTapped() {
        navigationController?.dismiss(animated: true)
    }

    @objc private func saveTapped() {
        if selectedOptionIds.isEmpty {
            onSave?([])
        } else {
            let selectedItems = allOptions.filter { selectedOptionIds.contains($0.id) }
            onSave?(selectedItems)
        }
        if isOpenPresent {
            navigationController?.dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func deleteTapped() {
        onSave?([])
        if isOpenPresent {
            navigationController?.dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}


// MARK: - UITextFieldDelegate

extension FilterOptionsController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
