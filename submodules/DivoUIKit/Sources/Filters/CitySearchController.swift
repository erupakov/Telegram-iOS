//
//  CitySearchController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 04.06.2026.
//

import Display
import UIKit
import MapKit
import DivoCore

public final class CitySearchController: UIViewController, MKLocalSearchCompleterDelegate {

    private let completer = MKLocalSearchCompleter()
    private var searchDebounceTimer: Foundation.Timer?
    private var throttleRetryTimer: Foundation.Timer?

    // Единственный источник правды для экрана — render() рисует только из state.
    private enum SearchState {
        case idle                                        // поле пустое, показываем предвыбор
        case searching(stale: [MKLocalSearchCompletion]) // ждём комплитер, на экране прошлые результаты
        case loaded([MKLocalSearchCompletion])
        case notFound
        case error(String)

        var visibleResults: [MKLocalSearchCompletion] {
            switch self {
            case .searching(let stale): return stale
            case .loaded(let results): return results
            case .idle, .notFound, .error: return []
            }
        }
    }

    private var state: SearchState = .idle {
        didSet { render() }
    }

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
        field.placeholder = DivoStrings.citySearchPlaceholder
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private lazy var countryNameToCodeMap: [String: String] = {
        var map: [String: String] = [:]
        let preferredLocale = Locale(identifier: DivoStrings.current.rawValue)
        let enLocale = Locale(identifier: "en")
        
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

    private var filterCountryCode: String?
    private var allowedCountryNames: Set<String> = []
    

    // MARK: - Init

    public init(
        title: String,
        preselectedItems: [FilterOptionItem] = [],
        isMultiSelect: Bool = false,
        isOpenPresent: Bool = false,
        filterCountryCode: String? = nil
    ) {
        self.isMultiSelect = isMultiSelect
        self.isOpenPresent = isOpenPresent
        self.filterCountryCode = filterCountryCode
        super.init(nibName: nil, bundle: nil)
        
        for item in preselectedItems {
            self.selectedCities[item.id] = item.title
        }
        
        if let countryCode = filterCountryCode {
            let preferredLocale = Locale(identifier: DivoStrings.current.rawValue)
            let enLocale = Locale(identifier: "en")
            
            if let name = preferredLocale.localizedString(forRegionCode: countryCode) {
                self.allowedCountryNames.insert(name.lowercased())
            }
            if let enName = enLocale.localizedString(forRegionCode: countryCode) {
                self.allowedCountryNames.insert(enName.lowercased())
            }
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

        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light

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

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Сразу показываем уже выбранные города (предвыбор) — до первого ввода.
        render()

        searchTextField.becomeFirstResponder()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        searchDebounceTimer?.invalidate()
        throttleRetryTimer?.invalidate()
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        // scrollView прибит к view.bottomAnchor, поэтому перекрытие = высота вьюхи минус верх клавиатуры.
        let keyboardTop = view.convert(frame, from: nil).minY
        let overlap = max(0, view.bounds.maxY - keyboardTop)
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
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
    
    private func render() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch state {
        case .error(let text):
            stackView.addArrangedSubview(makeMessageView(text))
        case .notFound:
            // С непустым предвыбором заглушку не показываем — как и раньше, остаётся список выбранного.
            if selectedCities.isEmpty {
                stackView.addArrangedSubview(makeMessageView(DivoStrings.cityNotFound))
            } else {
                renderPreselectedCities()
            }
        case .idle:
            renderPreselectedCities()
        case .searching, .loaded:
            let results = state.visibleResults
            if results.isEmpty {
                renderPreselectedCities()
            } else {
                renderResults(results)
            }
        }
    }

    private func renderPreselectedCities() {
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
    }

    private func renderResults(_ results: [MKLocalSearchCompletion]) {
        for (index, completion) in results.enumerated() {
            let id = completion.title + "|||" + completion.subtitle
            let flag = extractFlag(from: completion.subtitle)

            let countryName = completion.subtitle.split(separator: ",").last?.trimmingCharacters(in: .whitespaces) ?? ""
            let fullTitle = countryName.isEmpty ? "\(flag) \(completion.title)" : "\(flag) \(completion.title), \(countryName)"

            let isSelected = selectedCities[id] != nil
            
            let cell = createOptionCell(
                title: fullTitle,
                isSelected: isSelected,
                isLast: index == results.count - 1
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

    private func makeMessageView(_ text: String) -> UIView {
        let cell = UIView()
        cell.backgroundColor = .clear
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.heightAnchor.constraint(equalToConstant: 50).isActive = true
        cell.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - 32).isActive = true

        let label = UILabel()
        label.text = text
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    private func extractFlag(from subtitle: String) -> String {
        let components = subtitle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let countryName = components.last?.lowercased() else { return "🌍" }

        if let code = countryNameToCodeMap[countryName] {
            return CountryHelper.emojiFlag(for: code)
        }

        for (name, code) in countryNameToCodeMap {
            if countryName.contains(name) || name.contains(countryName) {
                return CountryHelper.emojiFlag(for: code)
            }
        }

        return "🌍"
    }


    // MARK: - MKLocalSearchCompleterDelegate
    
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let filtered = completer.results.filter { completion in
            let subtitle = completion.subtitle.lowercased()
            
            let hasHouseNumber = subtitle.rangeOfCharacter(from: .decimalDigits) != nil
            guard !hasHouseNumber else { return false }
            
            if !allowedCountryNames.isEmpty {
                let matchesCountry = allowedCountryNames.contains { countryName in
                    subtitle.contains(countryName)
                }
                return matchesCountry
            }
            
            return true
        }

        if !filtered.isEmpty {
            state = .loaded(filtered)
        } else if !completer.isSearching {
            state = settledEmptyState()
        }
        // Промежуточный пустой апдейт (isSearching == true) не показываем — ждём финальный.
    }

    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        divoLog("CitySearch completer failed: \(error)", level: .error)

        // Запрос отменён сменой текста — результат уже неактуален.
        if containsURLError(error, codes: [NSURLErrorCancelled]) {
            return
        }

        switch (error as? MKError)?.code {
        case .placemarkNotFound?:
            // Для комплитера это «ничего не нашлось», а не ошибка.
            state = settledEmptyState()
        case .loadingThrottled?:
            scheduleThrottledRetry()
        default:
            state = .error(isNoInternet(error) ? DivoStrings.noInternetConnection : DivoStrings.genericError)
        }
    }

    // Троттлинг MapKit — не ошибка: остаёмся на прошлых результатах и повторяем запрос позже.
    private func scheduleThrottledRetry() {
        throttleRetryTimer?.invalidate()
        throttleRetryTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self, case .searching = self.state else { return }
            let query = self.trimmedQuery
            guard !query.isEmpty else { return }
            self.completer.queryFragment = query
        }
    }

    // Поиск завершился пустым: по 1 символу подсказок почти не бывает, «не найдено» не утверждаем.
    private func settledEmptyState() -> SearchState {
        trimmedQuery.count >= 2 ? .notFound : .loaded([])
    }

    private var trimmedQuery: String {
        (searchTextField.text ?? "").trimmingCharacters(in: .whitespaces)
    }

    private func isNoInternet(_ error: Error) -> Bool {
        containsURLError(error, codes: [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed])
    }

    private func containsURLError(_ error: Error, codes: Set<Int>) -> Bool {
        var current: NSError? = error as NSError
        while let nsError = current {
            if nsError.domain == NSURLErrorDomain && codes.contains(nsError.code) {
                return true
            }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
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

        render()
    }

    @objc private func optionTapped(_ gesture: UITapGestureRecognizer) {
        let results = state.visibleResults
        guard let cell = gesture.view, let index = cell.tag as Int?, index < results.count else { return }
        let selectedCompletion = results[index]
        
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

        render()
    }

    @objc private func searchTextChanged() {
        let text = searchTextField.text ?? ""

        searchDebounceTimer?.invalidate()
        throttleRetryTimer?.invalidate()

        if text.isEmpty {
            completer.cancel()
            state = .idle
        } else {
            // Пока идёт новый поиск, держим на экране прошлые результаты — без мигания заглушками.
            state = .searching(stale: state.visibleResults)
            searchDebounceTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.completer.queryFragment = text
            }
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
