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
    /// false для single-select (онбординг): первая опция — не псевдо-«Все».
    private let firstOptionIsAll: Bool
   
    public var onSave: (([FilterOptionItem]) -> Void)?

    private let navigationBar = DivoNavigationBar()

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

    private let searchFieldContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let searchFadeOverlay: UIView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.cgColor,
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
            ]
            gradient.locations = [0, 0.45]
        }
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
        field.tintColor = DivoColorPalette.accent
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
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
        isResetButton: Bool = true,
        firstOptionIsAll: Bool = true
    ) {
        self.allOptions = options
        self.filteredOptions = options
        self.selectedOptionIds = Set(selectedOptionIds)
        self.isMultiSelect = isMultiSelect
        self.showSearch = showSearch
        self.isOpenPresent = isOpenPresent
        self.isResetButton = isResetButton
        self.firstOptionIsAll = firstOptionIsAll
        super.init(nibName: nil, bundle: nil)

        navigationBar.makeNavigationBar(
            title: title,
            font: Font.medium(16),
            backButtonConfiguration: isOpenPresent ? .circle(DivoImage.searchCloseIcon) : .circle(DivoImage.searchChevronLeft),
            rightButtonConfiguration: .circle(DivoColorPalette.accent, DivoColorPalette.cardBackground, DivoImage.searchWhiteCheckmark, .primary),
            onBackTapped: isOpenPresent ?
            { [weak self] in
                self?.navigationController?.dismiss(animated: true)
            } 
            :
            { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            },
            onCircleRightTapped: { [weak self] in
                self?.saveTapped()
            }
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()

        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light

        view.backgroundColor = DivoColorPalette.screenBackground

        setupCustomNavBar()
        setupScrollView()
        setupSearchField()
        setupConstraints()

        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)

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
        view.addSubview(navigationBar)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DivoDesignTokens.Spacing.m),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupSearchField() {
        if showSearch {
            view.addSubview(searchFieldContainer)
            searchFieldContainer.addSubview(searchIcon)
            searchFieldContainer.addSubview(searchTextField)
            view.addSubview(searchFadeOverlay)
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
        if showSearch {
            NSLayoutConstraint.activate([
                searchFieldContainer.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 20),
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
                searchTextField.bottomAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),
                
                searchFadeOverlay.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),
                searchFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                searchFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                searchFadeOverlay.heightAnchor.constraint(equalToConstant: 60),
            ])
            
            scrollView.contentInset.top = DivoDesignTokens.Spacing.m
        }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: showSearch ? searchFieldContainer.bottomAnchor : navigationBar.bottomAnchor, constant: showSearch ? 0.0 : 20.0),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.bottomAnchor),
        ])
        
        if isResetButton {
            NSLayoutConstraint.activate([
                deleteButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: DivoDesignTokens.Spacing.xl),
                // Ширина от видимой области скролла, а не от stackView — он схлопывается в 0 при пустом поиске.
                deleteButton.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
                deleteButton.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
                deleteButton.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                deleteButton.heightAnchor.constraint(equalToConstant: 48)
            ])
        }
    }
    
    private func reloadOptions() {
        // Очищаем stackView
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // «Все» = пункт с id == "all", а не просто первый (иначе у списков без «Все» галочка на первом).
        let allOptionId = allOptions.first(where: { $0.id == "all" })?.id

        for (index, option) in filteredOptions.enumerated() {
            let cell = createOptionCell(
                option: option,
                isSelected: selectedOptionIds.contains(option.id) || (firstOptionIsAll && selectedOptionIds.isEmpty && option.id == allOptionId),
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
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)

        let checkmark = UIImageView(image: DivoImage.searchOrangeCheckmark)
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
        // «Все» = пункт с id == "all", а не просто первый (иначе у списков без «Все» галочка на первом).
        let allOptionId = allOptions.first(where: { $0.id == "all" })?.id

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
