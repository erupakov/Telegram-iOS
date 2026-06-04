//
//  CitySearchController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 04.06.2026.
//

import Display
import UIKit
import TelegramCore
import MapKit
import DivoCore

public final class CitySearchController: UIViewController, MKLocalSearchCompleterDelegate {

    private let completer = MKLocalSearchCompleter()
    private var currentResults: [MKLocalSearchCompletion] = []
    
    private var selectedCities: [String: String] = [:]
    
    private let isMultiSelect: Bool
    private let isOpenPresent: Bool
   
    public var onSave: (([FilterOptionItem]) -> Void)?

    private let navigationBar = DivoNavigationBar()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
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
        field.placeholder = DivoStrings.feedSearchPlaceholder
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private lazy var countryNameToCodeMap: [String: String] = {
        var map: [String: String] = [:]
        let preferredLocale = Locale(identifier: DivoStrings.current.rawValue)
        let enLocale = Locale(identifier: DivoStrings.current.rawValue)
        
        for code in Locale.isoRegionCodes {
            if let countryName = preferredLocale.localizedString(forRegionCode: code) {
                map[countryName.lowercased()] = code
            }
            if let enCountryName = enLocale.localizedString(forRegionCode: code) {
                map[enCountryName.lowercased()] = code
            }
        }
        return map
    }()

    // MARK: - Init
    public init(
        title: String,
        preselectedItems: [FilterOptionItem] = [],
        isMultiSelect: Bool = false,
        isOpenPresent: Bool = false
    ) {
        self.isMultiSelect = isMultiSelect
        self.isOpenPresent = isOpenPresent
        super.init(nibName: nil, bundle: nil)

        for item in preselectedItems {
            self.selectedCities[item.id] = item.title
        }

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

        view.backgroundColor = DivoColorPalette.screenBackground

        syncSystemLanguageWithAppLanguage()

        setupCustomNavBar()
        setupScrollView()
        setupSearchField()
        setupConstraints()

        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)

        completer.delegate = self
        completer.resultTypes = .address

        let tapDismiss = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardTap))
        tapDismiss.cancelsTouchesInView = false
        view.addGestureRecognizer(tapDismiss)

        searchTextField.becomeFirstResponder()
    }

    private func syncSystemLanguageWithAppLanguage() {
        let currentAppLang = DivoStrings.current.rawValue
        UserDefaults.standard.set([currentAppLang], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
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
        view.addSubview(searchFieldContainer)
        searchFieldContainer.addSubview(searchIcon)
        searchFieldContainer.addSubview(searchTextField)
        view.addSubview(searchFadeOverlay)
    }

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

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

            scrollView.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.bottomAnchor),
        ])
        
        scrollView.contentInset.top = DivoDesignTokens.Spacing.m
    }
    
    private func reloadOptions() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if currentResults.isEmpty && !selectedCities.isEmpty {
            let sortedKeys = Array(selectedCities.keys).sorted()
            for (index, key) in sortedKeys.enumerated() {
                if let fullTitle = selectedCities[key] {
                    let cell = createOptionCell(
                        title: fullTitle,
                        isSelected: true,
                        isLast: index == sortedKeys.count - 1
                    )
                    
                    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(preselectedOptionTapped(_:)))
                    cell.addGestureRecognizer(tapGesture)
                    cell.tag = index
                    cell.addPressState(alpha: DivoDesignTokens.PressState.alphaOnClear)
                    
                    stackView.addArrangedSubview(cell)
                }
            }
            return
        }
        
        for (index, completion) in currentResults.enumerated() {
            let id = completion.title + "|||" + completion.subtitle
            let flag = extractFlag(from: completion.subtitle)
            
            let countryName = completion.subtitle.split(separator: ",").last?.trimmingCharacters(in: .whitespaces) ?? ""
            let fullTitle = countryName.isEmpty ? "\(flag) \(completion.title)" : "\(flag) \(completion.title), \(countryName)"
            
            let isSelected = selectedCities[id] != nil
            
            let cell = createOptionCell(
                title: fullTitle,
                isSelected: isSelected,
                isLast: index == currentResults.count - 1
            )
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
            cell.addGestureRecognizer(tapGesture)
            cell.tag = index
            cell.addPressState(alpha: DivoDesignTokens.PressState.alphaOnClear)
            
            stackView.addArrangedSubview(cell)
        }
    }
    
    private func createOptionCell(title: String, isSelected: Bool, isLast: Bool) -> UIView {
        let cell = UIView()
        cell.backgroundColor = .clear
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.heightAnchor.constraint(equalToConstant: 50).isActive = true
        cell.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - 32).isActive = true
        
        let label = UILabel()
        label.text = title
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

    private func extractFlag(from subtitle: String) -> String {
        let components = subtitle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let countryName = components.last?.lowercased() else { return "🌍" }
        
        if let code = countryNameToCodeMap[countryName] {
            return emojiFlag(for: code)
        }
        
        for (name, code) in countryNameToCodeMap {
            if countryName.contains(name) || name.contains(countryName) {
                return emojiFlag(for: code)
            }
        }
        
        return "🌍"
    }
    
    private func emojiFlag(for countryCode: String) -> String {
        guard countryCode.count == 2 else { return "🌍" }
        return countryCode.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }


    // MARK: - MKLocalSearchCompleterDelegate
    
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.currentResults = completer.results.filter { completion in
            let subtitle = completion.subtitle.lowercased()
            let hasHouseNumber = subtitle.rangeOfCharacter(from: .decimalDigits) != nil
            return !hasHouseNumber
        }
        reloadOptions()
    }
    
    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Completer failed with error: \(error)")
    }


    // MARK: - Handlers

    @objc private func dismissKeyboardTap() {
        view.endEditing(true)
    }
    
    @objc private func preselectedOptionTapped(_ gesture: UITapGestureRecognizer) {
        guard let cell = gesture.view, let index = cell.tag as Int? else { return }
        let sortedKeys = Array(selectedCities.keys).sorted()
        guard index < sortedKeys.count else { return }
        let key = sortedKeys[index]
        
        if isMultiSelect {
            selectedCities.removeValue(forKey: key)
        } else {
            selectedCities.removeAll()
        }
        
        reloadOptions()
    }

    @objc private func optionTapped(_ gesture: UITapGestureRecognizer) {
        guard let cell = gesture.view, let index = cell.tag as Int?, index < currentResults.count else { return }
        let selectedCompletion = currentResults[index]
        
        let flag = extractFlag(from: selectedCompletion.subtitle)
        let countryName = selectedCompletion.subtitle.split(separator: ",").last?.trimmingCharacters(in: .whitespaces) ?? ""
        let fullTitle = countryName.isEmpty ? "\(flag) \(selectedCompletion.title)" : "\(flag) \(selectedCompletion.title), \(countryName)"
        
        let id = selectedCompletion.title + "|||" + selectedCompletion.subtitle
        
        if isMultiSelect {
            if selectedCities[id] != nil {
                selectedCities.removeValue(forKey: id)
            } else {
                selectedCities[id] = fullTitle
            }
        } else {
            selectedCities.removeAll()
            selectedCities[id] = fullTitle
        }
        
        reloadOptions()
    }

    @objc private func searchTextChanged() {
        let text = searchTextField.text ?? ""

        if text.isEmpty {
            completer.cancel()
            currentResults = []
            reloadOptions()
        } else {
            completer.queryFragment = text
        }
    }

    @objc private func saveTapped() {
        let selectedItems = selectedCities.map { id, title in
            FilterOptionItem(id: id, title: title)
        }
        
        onSave?(selectedItems)
        
        if isOpenPresent {
            navigationController?.dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}

// MARK: - UITextFieldDelegate

extension CitySearchController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
