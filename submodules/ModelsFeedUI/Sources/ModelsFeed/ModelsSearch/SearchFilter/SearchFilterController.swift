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
    var hairLengthOptions: [FilterOptionApperanceItem] = []
    var hairColorOptions: [FilterOptionApperanceItem] = []
    var eyeColorOptions: [FilterOptionApperanceItem] = []
    var skinColorOptions: [FilterOptionApperanceItem] = []
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
    var onClose: ((SearchFilterState) -> Void)?
    var onSelectCountry: ((@escaping (String, String) -> Void) -> Void)?
    
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
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let roleRow = FilterRowView(title: DivoStrings.debugRole)
    private let genderRow = FilterRowView(title: DivoStrings.paramGender)
    private let countryRow = FilterRowView(title: DivoStrings.debugCountry)
    
    private let cityTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = DivoStrings.debugCity
        tf.backgroundColor = .white
        tf.layer.cornerRadius = 23 // TODO: DS alignment — не в шкале Radius (border inset от card=24)
        tf.font = Font.regular(16)
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 46))
        tf.leftView = paddingView
        tf.leftViewMode = .always
        tf.rightView = paddingView
        tf.rightViewMode = .always
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
        
    private let moreFiltersButton: UIButton = {
        let btn = UIButton(type: .system)
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
        view.backgroundColor = .white
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let applyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(DivoStrings.feedSearchApplyFilter, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitleColor(DivoColorPalette.disabledText, for: .disabled)
        btn.titleLabel?.font = Font.helveticaNeue(20)
        btn.backgroundColor = DivoColorPalette.accent
        btn.layer.cornerRadius = 28 // TODO: DS alignment — не в шкале Radius
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
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let resetButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(DivoStrings.feedSearchReset, for: .normal)
        btn.setTitleColor(DivoColorPalette.accent, for: .normal)
        btn.titleLabel?.font = Font.regular(15)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        let image = UIImage(bundleImageName: "Components/Search/SearchCloseIcon") ?? UIImage(systemName: "xmark")
        button.setImage(image, for: .normal)
        button.tintColor = .black
        button.layer.applyDivoShadow()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()
    
    init(currentFilters: SearchFilterState) {
        self.currentFilters = currentFilters
        super.init(nibName: nil, bundle: nil)
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
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
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
                        max: 100,
                        unit: ""
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
                        title: DivoStrings.ageYo,
                        keyPath: \.heightRange,
                        min: 150,
                        max: 200,
                        unit: "cm"
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
                        max: 120,
                        unit: "kg"
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
                        max: 120,
                        unit: "cm"
                    ) }
            ),
            AppearanceFilterItem(
                title: DivoStrings.hipsCm,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.hipsRange else { return []}
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramHips, keyPath: \.hipsRange, min: 70, max: 130, unit: "cm") }
            ),
            AppearanceFilterItem(
                title: DivoStrings.shoeSizeEU,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.shoeSizeRange else { return []}
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramShoeSize, keyPath: \.shoeSizeRange, min: 35, max: 46, unit: "") }
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
        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])

        let innerStack = UIStackView(arrangedSubviews: [roleRow, genderRow, countryRow])
        innerStack.axis = .vertical
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.spacing = 16

        stackView.addArrangedSubview(innerStack)

        cityTextField.delegate = self
        cityTextField.addTarget(self, action: #selector(cityChanged), for: .editingChanged)

        NSLayoutConstraint.activate([cityTextField.heightAnchor.constraint(equalToConstant: 46)])
        stackView.addArrangedSubview(cityTextField)
        
        let isAgency = DivoConfig.currentUserRole == .agency
        
        moreFiltersButton.addTarget(self, action: #selector(moreFiltersTapped), for: .touchUpInside)
        
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
        
        NSLayoutConstraint.activate([
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            applyButton.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        roleRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(roleTapped)))
        genderRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(genderTapped)))
        countryRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(countryTapped)))
        
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
    
    private func createAppearanceCell(title: String, value: String, isLast: Bool) -> UIView {
        let cell = UIView()
        cell.backgroundColor = .clear
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Font.regular(16)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(titleLabel)
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = Font.regular(14)
        valueLabel.textColor = DivoColorPalette.systemLabelTertiary
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(valueLabel)
        
        let chevronImageView = UIImageView()
        chevronImageView.image = UIImage(bundleImageName: "Components/Search/ChevronRight") ?? UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(chevronImageView)
        
        if !isLast {
            let separator = UIView()
            separator.backgroundColor = DivoColorPalette.separatorSystem
            separator.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(separator)
            
            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 16),
                separator.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -16),
                separator.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            
            chevronImageView.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 20),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20),
            
            valueLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            valueLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 16)
        ])
        
        return cell
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

        cityTextField.text = currentFilters.city
        
        updateAppearanceValues()
    }

    private func showRangeFilter<T>(title: String, keyPath: WritableKeyPath<SearchFilterState, ClosedRange<T>?>, min: T, max: T, unit: String) where T: RangeFilterable {
        
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
            unit: unit,
            currentLower: currentMin,
            currentUpper: currentMax
        ) { [weak self] newRange in
            guard let self = self else { return }
            
            if let newRange = newRange {
                let newClosedRange = T(newRange.0)...T(newRange.1)
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
        updateUI()
        reloadAppearanceOptions()
    }
    
    @objc private func applyTapped() {
        onApply?(currentFilters)
        dismiss(animated: true)
    }
    
    @objc private func cityChanged() {
        currentFilters.city = cityTextField.text
        updateUI()
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
            isMultiSelect: true,
            showSearch: true
        )

        vc.onSave = { [weak self] selectedItems in
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

// 1. Создаем общий протокол для фильтров
protocol RangeFilterable: Comparable {
    var doubleValue: Double { get }
    init(_ value: Double)
}

// 2. Учим Int работать с этим протоколом
extension Int: RangeFilterable {
    var doubleValue: Double { return Double(self) }
}

// 3. Учим Double работать с этим протоколом
extension Double: RangeFilterable {
    var doubleValue: Double { return self }
}

// Если где-то используете Float или CGFloat, можно добавить и их:
extension Float: RangeFilterable {
    var doubleValue: Double { return Double(self) }
}
