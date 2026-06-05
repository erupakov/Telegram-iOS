//
//  SearchFilterController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import Display
import UIKit
import DivoCore
import DivoUIKit

final class SearchFilterController: UIViewController, UITextFieldDelegate {
    
    var currentFilters: SearchFilterState
    
    var genderOptions: [FilterOptionItem] = []
    var hairLengthOptions: [FilterOptionAppearanceItem] = []
    var hairColorOptions: [FilterOptionAppearanceItem] = []
    var eyeColorOptions: [FilterOptionAppearanceItem] = []
    var skinColorOptions: [FilterOptionAppearanceItem] = []
    var roleOptions: [FilterOptionItem] = [
        FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllRoles),
        FilterOptionItem(id: "model", title: DivoStrings.debugModel),
        FilterOptionItem(id: "new_face", title: DivoStrings.debugNewTalent),
        FilterOptionItem(id: "agency_employee", title: DivoStrings.debugAgency)
    ]
    
    lazy var countryOptions:[FilterOptionItem] = {
        var options: [FilterOptionItem] = []
        options.append(contentsOf: CountryHelper.getAllCountries())
        return options
    }()
    
    var onApply: ((SearchFilterState) -> Void)?
    var onClose: ((SearchFilterState) -> Void)?
    
    private struct AppearanceFilterItem {
        let title: String
        let getValues: () -> [String]
        let emptyTitle: String
        let onTap: () -> Void
    }
    
    private var appearanceFilterItems: [AppearanceFilterItem] = []
    
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = DivoDesignTokens.Spacing.m
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let roleRow = FilterRowView(title: DivoStrings.debugRole)
    private let genderRow = FilterRowView(title: DivoStrings.paramGender)
    private let countryRow = FilterRowView(title: DivoStrings.debugCountry)
    private let cityRow = FilterRowView(title: DivoStrings.debugCity)
    
    private let moreFiltersButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(DivoStrings.feedSearchMoreFilters, for: .normal)
        btn.setTitleColor(DivoColorPalette.accent, for: .normal)
        btn.titleLabel?.font = Font.regular(15)
        btn.contentHorizontalAlignment = .left
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private var isMoreFiltersExpanded = false
    
    private let appearanceContainerStack: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isHidden = true
        return stackView
    }()
    
    private let appearanceBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let applyButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(DivoStrings.feedSearchApplyFilter, for: .normal)
        btn.setTitleColor(DivoColorPalette.primaryTextOnDark, for: .normal)
        btn.titleLabel?.font = Font.helveticaNeue(20)
        btn.backgroundColor = DivoColorPalette.accent
        btn.layer.cornerRadius = 28 // TODO: DS alignment — не в шкале Radius
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let navigationBar = DivoNavigationBar()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()
    
    private let initialFilters: SearchFilterState

    init(currentFilters: SearchFilterState) {
        self.currentFilters = currentFilters
        self.initialFilters = currentFilters
        super.init(nibName: nil, bundle: nil)

        navigationBar.makeNavigationBar(
            title: DivoStrings.feedSearchFilter,
            font: Font.medium(16),
            backButtonConfiguration: .circle(DivoImage.searchCloseIcon),
            rightButtonConfiguration: .text(DivoStrings.feedSearchReset),
            onBackTapped: { [weak self] in self?.closeTapped() },
            onCircleTextTapped: { [weak self] in self?.resetTapped() }
        )

        setupAppearanceFilterItems()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.screenBackground
        setupCustomNavBar()
        setupUI()
        updateUI()
        
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissTap)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupScrollViewInsets()
    }


    // MARK: - Private
    
    private func setupAppearanceFilterItems() {
        appearanceFilterItems = [
            AppearanceFilterItem(
                title: DivoStrings.ageYo,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.ageRange else { return [] }
                    return["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.ageYo,
                        keyPath: \.ageRange,
                        min: 14,
                        max: 100
                    )
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.heightCm,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.heightRange else { return [] }
                    return["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.heightCm,
                        keyPath: \.heightRange,
                        min: 150,
                        max: 200
                    )
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.weightKg,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.weightRange else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.paramWeight,
                        keyPath: \.weightRange,
                        min: 40,
                        max: 120
                    )
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.waistCm,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.waistRange else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.paramWaist,
                        keyPath: \.waistRange,
                        min: 50,
                        max: 120
                    ) }
            ),
            AppearanceFilterItem(
                title: DivoStrings.hipsCm,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.hipsRange else { return []}
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramHips, keyPath: \.hipsRange, min: 70, max: 130) }
            ),
            AppearanceFilterItem(
                title: DivoStrings.shoeSizeEU,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.shoeSizeRange else { return []}
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramShoeSize, keyPath: \.shoeSizeRange, min: 35, max: 46) }
            ),
            AppearanceFilterItem(
                title: DivoStrings.hairLength,
                getValues: { [weak self] in
                    guard let self = self, let selectedIds = self.currentFilters.hairLength, !selectedIds.isEmpty else {
                        return[]
                    }
                    let selectedTitles = self.hairLengthOptions
                        .filter { selectedIds.contains($0.id) }
                        .map { $0.title }
                    return selectedTitles
                },
                emptyTitle: DivoStrings.debugAll,
                onTap: { [weak self] in self?.showHairLengthFilter() }
            ),
            AppearanceFilterItem(
                title: DivoStrings.hairColor,
                getValues: { [weak self] in
                    guard let self = self, let selectedIds = self.currentFilters.hairColor, !selectedIds.isEmpty else {
                        return[]
                    }
                    let selectedTitles = self.hairColorOptions
                        .filter { selectedIds.contains($0.id) }
                        .map { $0.title }
                    return selectedTitles
                },
                emptyTitle: DivoStrings.debugAll,
                onTap: { [weak self] in self?.showHairColorFilter() }
            ),
            AppearanceFilterItem(
                title: DivoStrings.eyeColor,
                getValues: { [weak self] in
                    guard let self = self, let selectedIds = self.currentFilters.eyeColor, !selectedIds.isEmpty else {
                        return[]
                    }
                    let selectedTitles = self.eyeColorOptions
                        .filter { selectedIds.contains($0.id) }
                        .map { $0.title }
                    return selectedTitles
                },
                emptyTitle: DivoStrings.debugAll,
                onTap: { [weak self] in self?.showEyeColorFilter() }
            ),
            AppearanceFilterItem(
                title: DivoStrings.skinColor,
                getValues: { [weak self] in
                    guard let self = self, let selectedIds = self.currentFilters.skinColor, !selectedIds.isEmpty else {
                        return[]
                    }
                    let selectedTitles = self.skinColorOptions
                        .filter { selectedIds.contains($0.id) }
                        .map { $0.title }
                    return selectedTitles
                },
                emptyTitle: DivoStrings.debugAll,
                onTap: { [weak self] in self?.showSkinColorFilter() }
            )
        ]
    }
    
    private func setupScrollViewInsets() {
        let bottomInset = applyButton.frame.height + 66
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
    }
    
    private func setupCustomNavBar() {
        view.addSubview(navigationBar)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DivoDesignTokens.Spacing.m),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.keyboardDismissMode = .onDrag
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -DivoDesignTokens.Spacing.xl)
        ])

        let innerStack = UIStackView(arrangedSubviews: [roleRow, genderRow, countryRow, cityRow])
        innerStack.axis = .vertical
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.spacing = DivoDesignTokens.Spacing.m

        stackView.addArrangedSubview(innerStack)
        
        let isAgency = DivoConfig.currentUserRole == .agency
        
        moreFiltersButton.addTarget(self, action: #selector(moreFiltersTapped), for: .touchUpInside)
        moreFiltersButton.addDivoPressState(.text)

        stackView.addArrangedSubview(moreFiltersButton)
        NSLayoutConstraint.activate([
            moreFiltersButton.heightAnchor.constraint(equalToConstant: 22),
        ])
        
        moreFiltersButton.isHidden = !isAgency
        
        stackView.addArrangedSubview(appearanceBackgroundView)
        appearanceBackgroundView.addSubview(appearanceContainerStack)
        
        appearanceBackgroundView.isHidden = true
        appearanceContainerStack.isHidden = true
        
        NSLayoutConstraint.activate([
            appearanceBackgroundView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            appearanceBackgroundView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            
            appearanceContainerStack.topAnchor.constraint(equalTo: appearanceBackgroundView.topAnchor),
            appearanceContainerStack.leadingAnchor.constraint(equalTo: appearanceBackgroundView.leadingAnchor),
            appearanceContainerStack.trailingAnchor.constraint(equalTo: appearanceBackgroundView.trailingAnchor),
            appearanceContainerStack.bottomAnchor.constraint(equalTo: appearanceBackgroundView.bottomAnchor),
        ])
        
        view.addSubview(applyButton)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        applyButton.addDivoPressState(.primary)
        
        NSLayoutConstraint.activate([
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButton.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        roleRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(roleTapped)))
        genderRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(genderTapped)))
        countryRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(countryTapped)))
        cityRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cityTapped)))
        
        reloadAppearanceOptions()
    }
    
    private func reloadAppearanceOptions() {
        appearanceContainerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (index, item) in appearanceFilterItems.enumerated() {
            let isLast = index == appearanceFilterItems.count - 1
            let cell = AppearanceFilterRowView(title: item.title, isLast: isLast)
            cell.setItems(item.getValues(), emptyTitle: item.emptyTitle)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(appearanceCellTapped(_:)))
            cell.addGestureRecognizer(tapGesture)
            cell.tag = index
            
            appearanceContainerStack.addArrangedSubview(cell)
        }
    }
    
    private func updateAppearanceValues() {
        for (index, item) in appearanceFilterItems.enumerated() {
            if index < appearanceContainerStack.arrangedSubviews.count,
               let cell = appearanceContainerStack.arrangedSubviews[index] as? AppearanceFilterRowView {
                cell.setItems(item.getValues(), emptyTitle: item.emptyTitle)
            }
        }
    }
    
    private func updateUI() {
        roleRow.setItems(currentFilters.roleTitles, emptyTitle: DivoStrings.feedSearchAllRoles)
        genderRow.setItems(currentFilters.genderTitles, emptyTitle: DivoStrings.feedSearchAllGenders)
        countryRow.setItems(currentFilters.countryTitles, emptyTitle: DivoStrings.feedSearchAllCountries)

        let hasCountry = !currentFilters.countryIds.isEmpty
        let hasCity = currentFilters.cityId != nil
        
        cityRow.isHidden = !hasCountry
        cityRow.setItems(currentFilters.cityTitle.map { [$0] } ?? [], emptyTitle: DivoStrings.chooseCity)
        
        let isApplyEnabled: Bool
        if hasCountry {
            isApplyEnabled = hasCity
        } else {
            isApplyEnabled = true
        }

        applyButton.isEnabled = isApplyEnabled

        updateAppearanceValues()
        updateResetButtonState()
        setupScrollViewInsets()
    }

    private func updateResetButtonState() {
        let canReset = currentFilters.hasActiveFilters
        navigationBar.setEnableRightButton(canReset)
    }

    private func showRangeFilter<T>(title: String, keyPath: WritableKeyPath<SearchFilterState, ClosedRange<T>?>, min: T, max: T) where T: RangeFilterable {

        var currentMin: Double? = nil
        var currentMax: Double? = nil

        if let currentRange = self.currentFilters[keyPath: keyPath] {
            currentMin = currentRange.lowerBound.doubleValue
            currentMax = currentRange.upperBound.doubleValue
        }

        let vc = RangeFilterController(
            title: title,
            min: min.doubleValue,
            max: max.doubleValue,
            currentLower: currentMin,
            currentUpper: currentMax
        ) 

        vc.onSave = { [weak self] firstValue, secondValue in
            guard let self = self else { return }
            
            if let firstValue = firstValue, let secondValue = secondValue {
                let newClosedRange = T(firstValue)...T(secondValue)
                self.currentFilters[keyPath: keyPath] = newClosedRange
            } else {
                self.currentFilters[keyPath: keyPath] = nil
            }
            self.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func showHairLengthFilter() {
        var displayOptions = [FilterOptionItem(id: "all", title: DivoStrings.debugAll)]
        displayOptions.append(contentsOf: hairLengthOptions.map { FilterOptionItem(id: String($0.id), title: $0.title) })
        
        let selectedIds = (currentFilters.hairLength ?? []).map { String($0) }
        
        let vc = FilterOptionsController(
            title: DivoStrings.paramHairLength,
            options: displayOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            showSearch: false
        )
        
        vc.onSave = { [weak self] selectedItems in
            if selectedItems.isEmpty || selectedItems.contains(where: { $0.id == "all" }) {
                self?.currentFilters.hairLength = nil
            } else {
                self?.currentFilters.hairLength = selectedItems.compactMap { Int($0.id) }
            }
            self?.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showHairColorFilter() {
        var displayOptions = [FilterOptionItem(id: "all", title: DivoStrings.debugAll)]
        displayOptions.append(contentsOf: hairColorOptions.map { FilterOptionItem(id: String($0.id), title: $0.title) })
        
        let selectedIds = (currentFilters.hairColor ?? []).map { String($0) }
        
        let vc = FilterOptionsController(
            title: DivoStrings.paramHairColor,
            options: displayOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            showSearch: false
        )
        
        vc.onSave = { [weak self] selectedItems in
            if selectedItems.isEmpty || selectedItems.contains(where: { $0.id == "all" }) {
                self?.currentFilters.hairColor = nil
            } else {
                self?.currentFilters.hairColor = selectedItems.compactMap { Int($0.id) }
            }
            self?.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showEyeColorFilter() {
        var displayOptions = [FilterOptionItem(id: "all", title: DivoStrings.debugAll)]
        displayOptions.append(contentsOf: eyeColorOptions.map { FilterOptionItem(id: String($0.id), title: $0.title) })
        
        let selectedIds = (currentFilters.eyeColor ?? []).map { String($0) }
        
        let vc = FilterOptionsController(
            title: DivoStrings.paramEyeColor,
            options: displayOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            showSearch: false
        )
        
        vc.onSave = { [weak self] selectedItems in
            if selectedItems.isEmpty || selectedItems.contains(where: { $0.id == "all" }) {
                self?.currentFilters.eyeColor = nil
            } else {
                self?.currentFilters.eyeColor = selectedItems.compactMap { Int($0.id) }
            }
            self?.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showSkinColorFilter() {
        var displayOptions = [FilterOptionItem(id: "all", title: DivoStrings.debugAll)]
        displayOptions.append(contentsOf: skinColorOptions.map { FilterOptionItem(id: String($0.id), title: $0.title) })
        
        let selectedIds = (currentFilters.skinColor ?? []).map { String($0) }
        
        let vc = FilterOptionsController(
            title: DivoStrings.paramSkinColor,
            options: displayOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            showSearch: false
        )
        
        vc.onSave = { [weak self] selectedItems in
            if selectedItems.isEmpty || selectedItems.contains(where: { $0.id == "all" }) {
                self?.currentFilters.skinColor = nil
            } else {
                self?.currentFilters.skinColor = selectedItems.compactMap { Int($0.id) }
            }
            self?.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }

    private func resolveFilterCityOnBackend(cityName: String) {
        self.cityRow.setLoading(true)
        
        Task { @MainActor in
            do {
                let encodedQuery = cityName
                let response: GeoSearchResponse = try await DivoAPIClient.shared.request(
                    path: "/geo/search-by-address-name?query=\(encodedQuery)",
                    method: "GET"
                )
                
                self.cityRow.setLoading(false)
                
                if let firstResult = response.data?.first, let cityId = firstResult.city?.id {
                    self.currentFilters.cityId = cityId
                    
                    let resolvedCityName = firstResult.city?.name ?? cityName
                    let countryCode = firstResult.country?.code ?? firstResult.city?.countryCode
                    
                    let flag = emojiFlag(from: countryCode)
                    let countryName = firstResult.country?.name ?? firstResult.city?.countryName ?? ""
                    let finalTitle = countryName.isEmpty ? "\(flag) \(resolvedCityName)" : "\(flag) \(resolvedCityName), \(countryName)"
                    
                    self.currentFilters.cityTitle = finalTitle
                } else {
                    self.currentFilters.cityId = nil
                    self.currentFilters.cityTitle = nil
                }
                
                self.updateUI()
            } catch {
                self.cityRow.setLoading(false)
                self.currentFilters.cityId = nil
                self.currentFilters.cityTitle = nil
                self.updateUI()
            }
        }
    }

    private func emojiFlag(from countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "🌍" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }


    // MARK: - Internal
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { textField.resignFirstResponder(); return true }
     
    
    // MARK: - @objc

    @objc private func appearanceCellTapped(_ gesture: UITapGestureRecognizer) {
        guard let cell = gesture.view, let index = cell.tag as Int?,
              index < appearanceFilterItems.count else { return }
        appearanceFilterItems[index].onTap()
    }

    @objc private func closeTapped() {
        onClose?(currentFilters)
        dismiss(animated: true)
    }
    
    @objc private func resetTapped() {
        currentFilters.reset()
        onApply?(currentFilters)
        dismiss(animated: true)
    }
    
    @objc private func applyTapped() {
        onApply?(currentFilters)
        dismiss(animated: true)
    }
    
    @objc private func moreFiltersTapped() {
        isMoreFiltersExpanded.toggle()
        
        if isMoreFiltersExpanded {
            appearanceBackgroundView.isHidden = false
            appearanceContainerStack.isHidden = false
            
            appearanceBackgroundView.alpha = 0
            appearanceContainerStack.alpha = 0
            appearanceBackgroundView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut]) {
                self.appearanceBackgroundView.alpha = 1
                self.appearanceContainerStack.alpha = 1
                self.appearanceBackgroundView.transform = .identity
                self.moreFiltersButton.setTitle(DivoStrings.feedSearchLessFilters, for: .normal)
                self.view.layoutIfNeeded()
            }
        } else {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn]) {
                self.appearanceBackgroundView.alpha = 0
                self.appearanceContainerStack.alpha = 0
                self.appearanceBackgroundView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.moreFiltersButton.setTitle(DivoStrings.feedSearchMoreFilters, for: .normal)
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.appearanceBackgroundView.isHidden = true
                self.appearanceContainerStack.isHidden = true
                self.appearanceBackgroundView.transform = .identity
            }
        }
    }
    
    @objc private func dismissKeyboard() { view.endEditing(true) }
    
    @objc private func roleTapped() {
        let selectedIds = currentFilters.roleIds
        let vc = FilterOptionsController(title: DivoStrings.debugRole, options: roleOptions, selectedOptionIds: selectedIds, isMultiSelect: true)
        
        vc.onSave = {[weak self] selectedItems in
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
        
        vc.onSave = { [weak self] selectedItems in
            self?.currentFilters.genderIds = selectedItems.map { $0.id }
            self?.currentFilters.genderTitles = selectedItems.map { $0.title }
            self?.updateUI()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
        @objc private func countryTapped() {
        let selectedIds = currentFilters.countryIds
        
        let vc = FilterOptionsController(
            title: DivoStrings.debugCountry,
            options: countryOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: true
        )

        vc.onSave = { [weak self] selectedItems in
            guard let self = self else { return }
            if let selected = selectedItems.first {
                let oldCountryId = self.currentFilters.countryIds.first
                self.currentFilters.countryIds = [selected.id]
                self.currentFilters.countryTitles = [selected.title]
                
                if oldCountryId != selected.id {
                    self.currentFilters.cityId = nil
                    self.currentFilters.cityTitle = nil
                    self.currentFilters.rawCityId = nil
                }
            } else {
                self.currentFilters.countryIds = []
                self.currentFilters.countryTitles = []
                self.currentFilters.cityId = nil
                self.currentFilters.cityTitle = nil
                self.currentFilters.rawCityId = nil
            }
            self.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func cityTapped() {
        guard let countryCode = currentFilters.countryIds.first, !countryCode.isEmpty else {
            return
        }
        
        let preselected: [FilterOptionItem]
        if let rawId = self.currentFilters.rawCityId, let title = self.currentFilters.cityTitle {
            preselected = [FilterOptionItem(id: rawId, title: title)]
        } else {
            preselected = []
        }
        
        let vc = CitySearchController(
            title: DivoStrings.chooseCity,
            preselectedItems: preselected,
            isOpenPresent: true,
            filterCountryCode: countryCode
        )
                
        vc.onSave = { [weak self] selectedItems in
            guard let self = self else { return }
            if let selected = selectedItems.first {
                self.currentFilters.rawCityId = selected.id
                
                let rawParts = selected.id.components(separatedBy: "|||")
                let cityName = rawParts.joined(separator: ", ")
                
                self.resolveFilterCityOnBackend(cityName: cityName)
            } else {
                self.currentFilters.cityId = nil
                self.currentFilters.cityTitle = nil
                self.currentFilters.rawCityId = nil
                self.updateUI()
            }
        }
        
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 24
            }
        }
        self.present(nav, animated: true)
    }
}

