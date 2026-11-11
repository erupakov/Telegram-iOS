//
//  CitySearchController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 04.06.2026.
//

import Display
import UIKit
import DivoCore

/// Выбор города по локальной базе (GeoNames, `DivoCityDatabase`) — как в Android-клиенте. Раньше поиск шёл
/// через подсказки Apple Maps: для стран с редким покрытием (Армения, Афганистан) не находились даже столицы.
public final class CitySearchController: UIViewController {

    private var searchDebounceTimer: Foundation.Timer?

    /// Строка результата. `id` — ключ для вызывающих экранов: «название|||страна (en)», из него они
    /// собирают запрос к бэкенду («Yerevan, Armenia»); `title` — что видит пользователь.
    private struct CityRow {
        let id: String
        let title: String
    }

    // Единственный источник правды для экрана — render() рисует только из state.
    private enum SearchState {
        case idle                                  // поле пустое, показываем предвыбор
        case searching(stale: [CityRow])           // идёт поиск, на экране прошлые результаты
        case loaded([CityRow])
        case notFound
        case error(String)

        var visibleResults: [CityRow] {
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

    private static let confirmButtonHeight: CGFloat = 48

    /// Нижняя плавающая «Подтвердить» — как в шторке выбора страны (`FilterOptionsController`).
    private let confirmButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.confirm, for: .normal)
        button.setTitleColor(DivoColorPalette.primaryTextOnDark, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(18)
        button.backgroundColor = DivoColorPalette.accent
        button.layer.cornerRadius = DivoDesignTokens.Radius.card
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Нижний inset списка: кнопка + отступы (+ перекрытие клавиатурой), чтобы последний пункт не прятался за кнопкой.
    private func bottomInset(keyboardOverlap: CGFloat) -> CGFloat {
        return max(keyboardOverlap, view.safeAreaInsets.bottom) + Self.confirmButtonHeight + DivoDesignTokens.Spacing.m * 2
    }

    private var filterCountryCode: String?
    /// Номер запроса: результат устаревшего поиска не должен затирать новый.
    private var searchGeneration = 0

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
        
        navigationBar.makeNavigationBar(
            title: title,
            font: Font.medium(16),
            backButtonConfiguration: isOpenPresent ? .circle(DivoImage.searchCloseIcon) : .circle(DivoImage.searchChevronLeft),
            onBackTapped: isOpenPresent ?
            { [weak self] in
                self?.navigationController?.dismiss(animated: true)
            }
            :
            { [weak self] in
                self?.navigationController?.popViewController(animated: true)
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

        confirmButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        confirmButton.addDivoPressState(.primary)

        // Разбор базы (~8 МБ) — в фоне, пока пользователь набирает первые буквы.
        DivoCityDatabase.shared.preload()

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
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        // scrollView прибит к view.bottomAnchor, поэтому перекрытие = высота вьюхи минус верх клавиатуры.
        let keyboardTop = view.convert(frame, from: nil).minY
        let overlap = max(0, view.bounds.maxY - keyboardTop)
        scrollView.contentInset.bottom = bottomInset(keyboardOverlap: overlap)
        scrollView.verticalScrollIndicatorInsets.bottom = scrollView.contentInset.bottom
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = bottomInset(keyboardOverlap: 0)
        scrollView.verticalScrollIndicatorInsets.bottom = scrollView.contentInset.bottom
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

        // Кнопка закреплена внизу и поднимается над клавиатурой поиска.
        view.addSubview(confirmButton)
        scrollView.contentInset.bottom = Self.confirmButtonHeight + DivoDesignTokens.Spacing.m * 2
        scrollView.verticalScrollIndicatorInsets.bottom = scrollView.contentInset.bottom
        NSLayoutConstraint.activate([
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            confirmButton.heightAnchor.constraint(equalToConstant: Self.confirmButtonHeight)
        ])
        if #available(iOS 15.0, *) {
            confirmButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -DivoDesignTokens.Spacing.m).isActive = true
        } else {
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DivoDesignTokens.Spacing.m).isActive = true
        }
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

    private func renderResults(_ results: [CityRow]) {
        for (index, row) in results.enumerated() {
            let cell = createOptionCell(
                title: row.title,
                isSelected: selectedCities[row.id] != nil,
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

    // MARK: - Поиск по локальной базе

    private var trimmedQuery: String {
        (searchTextField.text ?? "").trimmingCharacters(in: .whitespaces)
    }

    private func runSearch(query: String) {
        searchGeneration += 1
        let generation = searchGeneration
        let countryCode = filterCountryCode

        DivoCityDatabase.shared.search(query: query, countryCode: countryCode) { [weak self] cities in
            guard let self = self, generation == self.searchGeneration else { return }

            guard let cities = cities else {
                divoLog("CitySearch: база городов недоступна", level: .error)
                self.state = .error(DivoStrings.genericError)
                return
            }
            let rows = self.makeRows(from: cities, query: query)
            divoLog("CitySearch: query=\"\(query)\" country=\(countryCode ?? "-") results=\(rows.count)")
            self.state = rows.isEmpty ? .notFound : .loaded(rows)
        }
    }

    private func makeRows(from cities: [DivoLocalCity], query: String) -> [CityRow] {
        // Одноимённые города одной страны (Newark в NJ, OH, DE) различаем регионом — как в Android;
        // admin-код показываем, только если он читаем (буквы: «NJ»), а не число.
        var nameCounts: [String: Int] = [:]
        for city in cities {
            nameCounts["\(city.countryCode)|\(city.name)", default: 0] += 1
        }

        let appLocale = Locale(identifier: DivoStrings.current.rawValue)
        let englishLocale = Locale(identifier: "en")

        return cities.map { city in
            let displayName = DivoCityDatabase.displayName(for: city, query: query)
            let region = city.adminCode.contains(where: { $0.isLetter }) && (nameCounts["\(city.countryCode)|\(city.name)"] ?? 0) > 1
                ? city.adminCode : nil

            let flag = CountryHelper.emojiFlag(for: city.countryCode)
            let localizedCountry = appLocale.localizedString(forRegionCode: city.countryCode)
                ?? englishLocale.localizedString(forRegionCode: city.countryCode) ?? city.countryCode
            let englishCountry = englishLocale.localizedString(forRegionCode: city.countryCode) ?? city.countryCode

            var titleParts = [displayName]
            if let region = region { titleParts.append(region) }
            titleParts.append(localizedCountry)
            let title = (flag.isEmpty ? "" : flag + " ") + titleParts.joined(separator: ", ")

            // В id — каноническое (GeoNames) название и английская страна: по ним бэкенд находит город
            // стабильнее, чем по локализованному отображаемому имени («Эривань»).
            return CityRow(id: city.name + "|||" + englishCountry, title: title)
        }
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
        let row = results[index]

        if isMultiSelect {
            if selectedCities[row.id] != nil {
                selectedCities.removeValue(forKey: row.id)
            } else {
                selectedCities[row.id] = row.title
            }
        } else {
            selectedCities.removeAll()
            selectedCities[row.id] = row.title
        }

        render()
    }

    @objc private func searchTextChanged() {
        let text = trimmedQuery

        searchDebounceTimer?.invalidate()
        // Сдвигаем поколение: результат отменённого поиска не должен примениться к новому тексту.
        searchGeneration += 1

        if text.isEmpty {
            state = .idle
        } else {
            // Пока идёт новый поиск, держим на экране прошлые результаты — без мигания заглушками.
            state = .searching(stale: state.visibleResults)
            searchDebounceTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                self?.runSearch(query: text)
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
