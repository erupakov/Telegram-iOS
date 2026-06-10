//
//  EventsSearchFilterController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 29.05.2026.
//

import Display
import UIKit
import DivoCore
import DivoUIKit

final class EventsSearchFilterController: UIViewController, UITextFieldDelegate {
    
    var currentFilters: EventsSearchFilterState
    
    var genderOptions: [FilterOptionItem] = []
    var eventTypeOptions: [FilterOptionItem] = []
    var hairLengthOptions: [FilterOptionAppearanceItem] = []
    var hairColorOptions: [FilterOptionAppearanceItem] = []
    var eyeColorOptions: [FilterOptionAppearanceItem] = []
    var skinColorOptions: [FilterOptionAppearanceItem] = []
    
    var roleOptions: [FilterOptionItem] = [
        FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllRoles),
        FilterOptionItem(id: "model", title: DivoStrings.debugModel),
        FilterOptionItem(id: "new_face", title: DivoStrings.debugNewTalent)
    ]
    
    lazy var countryOptions: [FilterOptionItem] = {
        var options = [FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllCountries)]
        options.append(contentsOf: CountryHelper.getAllCountries())
        return options
    }()
    
    var onApply: ((EventsSearchFilterState) -> Void)?
    var onClose: ((EventsSearchFilterState) -> Void)?
    
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
    
    // Основные поля
    private let eventTypeRow = FilterRowView(title: DivoStrings.eventsSearchTypeEvents)
    
    private let cityTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = DivoStrings.debugCity
        tf.backgroundColor = DivoColorPalette.cardBackground
        tf.layer.cornerRadius = 23
        tf.font = Font.regular(16)
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: DivoDesignTokens.Spacing.m, height: 46))
        tf.leftView = paddingView
        tf.leftViewMode = .always
        tf.rightView = paddingView
        tf.rightViewMode = .always
        tf.autocapitalizationType = .words
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let ageRow = FilterRowView(title: DivoStrings.ageYo)
    private let dateOfBirthRow = FilterRowView(title: DivoStrings.eventsSearchDateOfEvent)
    
    private let paidOnlyRow: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = 23
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = DivoStrings.eventsSearchPaidOnly
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let toggle = UISwitch()
        toggle.onTintColor = DivoColorPalette.accent
        toggle.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        view.addSubview(toggle)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            toggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            toggle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            view.heightAnchor.constraint(equalToConstant: 46)
        ])
        return view
    }()
    
    private var paidOnlySwitch: UISwitch {
        return paidOnlyRow.subviews.compactMap { $0 as? UISwitch }.first!
    }
    
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
        btn.layer.cornerRadius = 28
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
    
    private let initialFilters: EventsSearchFilterState

    init(currentFilters: EventsSearchFilterState) {
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
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
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

        // Главный вертикальный стек полей ввода
        let innerStack = UIStackView(arrangedSubviews: [eventTypeRow, cityTextField, ageRow, dateOfBirthRow, paidOnlyRow])
        innerStack.axis = .vertical
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.spacing = DivoDesignTokens.Spacing.m
        stackView.addArrangedSubview(innerStack)

        cityTextField.delegate = self
        cityTextField.addTarget(self, action: #selector(cityChanged), for: .editingChanged)
        NSLayoutConstraint.activate([cityTextField.heightAnchor.constraint(equalToConstant: 46)])
        
        paidOnlySwitch.addTarget(self, action: #selector(paidOnlyChanged), for: .valueChanged)

        moreFiltersButton.addTarget(self, action: #selector(moreFiltersTapped), for: .touchUpInside)
        moreFiltersButton.addDivoPressState(.text)

        stackView.addArrangedSubview(moreFiltersButton)
        NSLayoutConstraint.activate([
            moreFiltersButton.heightAnchor.constraint(equalToConstant: 22),
        ])
        
        stackView.addArrangedSubview(appearanceBackgroundView)
        appearanceBackgroundView.addSubview(appearanceContainerStack)
        
        // ИСПРАВЛЕНО: Добавляем пропущенную связку границ между контейнером-карточкой и внутренним стеком параметров
        NSLayoutConstraint.activate([
            appearanceBackgroundView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            appearanceBackgroundView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            
            appearanceContainerStack.topAnchor.constraint(equalTo: appearanceBackgroundView.topAnchor),
            appearanceContainerStack.leadingAnchor.constraint(equalTo: appearanceBackgroundView.leadingAnchor),
            appearanceContainerStack.trailingAnchor.constraint(equalTo: appearanceBackgroundView.trailingAnchor),
            appearanceContainerStack.bottomAnchor.constraint(equalTo: appearanceBackgroundView.bottomAnchor),
        ])
        
        appearanceBackgroundView.isHidden = true
        appearanceContainerStack.isHidden = true
        
        view.addSubview(applyButton)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        applyButton.addDivoPressState(.primary)
        
        NSLayoutConstraint.activate([
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButton.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        eventTypeRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(eventTypeTapped)))
        ageRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ageTapped)))
        dateOfBirthRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dateOfBirthTapped)))
        
        reloadAppearanceOptions()
    }
    
    private func setupAppearanceFilterItems() {
        appearanceFilterItems = [
            AppearanceFilterItem(
                title: DivoStrings.debugRole,
                getValues: { [weak self] in
                    guard let self = self else { return [] }
                    let selectedIds = self.currentFilters.roleIds
                    
                    let cleanIds = selectedIds.filter { $0 != "all" }
                    guard !cleanIds.isEmpty else { return [] }
                    
                    return self.roleOptions
                        .filter { cleanIds.contains($0.id) }
                        .map { $0.title }
                },
                emptyTitle: DivoStrings.debugAll,
                onTap: { [weak self] in
                    self?.roleTapped()
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.paramGender,
                getValues: { [weak self] in
                    guard let self = self else { return [] }
                    let selectedIds = self.currentFilters.genderIds
                    
                    let cleanIds = selectedIds.filter { $0 != "all" }
                    guard !cleanIds.isEmpty else { return [] }
                    
                    return self.genderOptions
                        .filter { cleanIds.contains($0.id) }
                        .map { $0.title }
                },
                emptyTitle: DivoStrings.debugAll,
                onTap: { [weak self] in
                    self?.genderTapped()
                }
            ),
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
                title: DivoMeasuring.title(kind: .height),
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.heightRange else { return [] }
                    return DivoMeasuring.rangeString(fromMetric: range.lowerBound.doubleValue, toMetric: range.upperBound.doubleValue, kind: .height).map { [$0] } ?? []
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.heightCm,
                        kind: .height,
                        keyPath: \.heightRange,
                        min: 140,
                        max: 210
                    )
                }
            ),
            AppearanceFilterItem(
                title: DivoMeasuring.title(kind: .weight),
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.weightRange else { return [] }
                    return DivoMeasuring.rangeString(fromMetric: range.lowerBound.doubleValue, toMetric: range.upperBound.doubleValue, kind: .weight).map { [$0] } ?? []
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.paramWeight,
                        kind: .weight,
                        keyPath: \.weightRange,
                        min: 40,
                        max: 130
                    )
                }
            ),
            AppearanceFilterItem(
                title: DivoMeasuring.title(kind: .waist),
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.waistRange else { return [] }
                    return DivoMeasuring.rangeString(fromMetric: range.lowerBound.doubleValue, toMetric: range.upperBound.doubleValue, kind: .waist).map { [$0] } ?? []
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.paramWaist,
                        kind: .waist,
                        keyPath: \.waistRange,
                        min: 50,
                        max: 120
                    ) }
            ),
            AppearanceFilterItem(
                title: DivoMeasuring.title(kind: .hips),
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.hipsRange else { return []}
                    return DivoMeasuring.rangeString(fromMetric: range.lowerBound.doubleValue, toMetric: range.upperBound.doubleValue, kind: .hips).map { [$0] } ?? []
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramHips, kind: .hips, keyPath: \.hipsRange, min: 70, max: 140) }
            ),
            AppearanceFilterItem(
                title: DivoMeasuring.title(kind: .shoeSize),
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.shoeSizeRange else { return []}
                    return DivoMeasuring.rangeString(fromMetric: range.lowerBound.doubleValue, toMetric: range.upperBound.doubleValue, kind: .shoeSize).map { [$0] } ?? []
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramShoeSize, kind: .shoeSize, keyPath: \.shoeSizeRange, min: 34, max: 48) }
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
        eventTypeRow.setItems(currentFilters.eventTypeTitles, emptyTitle: DivoStrings.allTypes)
        cityTextField.text = currentFilters.city
        paidOnlySwitch.isOn = currentFilters.isPaidOnly

        let dobFormatter = DateFormatter()
        dobFormatter.locale = Locale(identifier: DivoStrings.current.rawValue)
        dobFormatter.dateFormat = "MMM d, yyyy"
        let dobString = currentFilters.dateOfEventTimestamp.map { dobFormatter.string(from: Date(timeIntervalSince1970: TimeInterval($0))) }
        dateOfBirthRow.setItems(dobString.map { [$0] } ?? [], emptyTitle: DivoStrings.debugAny)
        
        let ageRangeStr = currentFilters.ageRange.map { ["\(Int($0.lowerBound))-\(Int($0.upperBound))"] } ?? []
        ageRow.setItems(ageRangeStr, emptyTitle: DivoStrings.debugAny)

        updateAppearanceValues()
        updateResetButtonState()
        
        // Переключаем видимость полей под свернутое/развернутое состояние
        if isMoreFiltersExpanded {
            ageRow.isHidden = true
            dateOfBirthRow.isHidden = false
            appearanceBackgroundView.isHidden = false
            appearanceContainerStack.isHidden = false
        } else {
            ageRow.isHidden = false
            dateOfBirthRow.isHidden = true
            appearanceBackgroundView.isHidden = true
            appearanceContainerStack.isHidden = true
        }
    }

    private func updateResetButtonState() {
        let canReset = currentFilters.hasActiveFilters
        navigationBar.setEnableRightButton(canReset)
    }

    private func showRangeFilter<T>(title: String, kind: DivoMeasureKind? = nil, keyPath: WritableKeyPath<EventsSearchFilterState, ClosedRange<T>?>, min: T, max: T) where T: RangeFilterable {

        let system = DivoMeasuringSystem.current
        func toDisplay(_ value: Double) -> Double {
            kind.map { DivoMeasuring.displayValue(metric: value, kind: $0, system: system) } ?? value
        }

        var currentMin: Double? = nil
        var currentMax: Double? = nil

        if let currentRange = self.currentFilters[keyPath: keyPath] {
            currentMin = toDisplay(currentRange.lowerBound.doubleValue)
            currentMax = toDisplay(currentRange.upperBound.doubleValue)
        }

        let vc = RangeFilterController(
            title: kind.map { DivoMeasuring.inputTitle(kind: $0, system: system) } ?? title,
            min: toDisplay(min.doubleValue),
            max: toDisplay(max.doubleValue),
            currentLower: currentMin,
            currentUpper: currentMax
        )

        vc.onSave = { [weak self] firstValue, secondValue in
            guard let self = self else { return }

            if let firstValue = firstValue, let secondValue = secondValue {
                // Не сдвинутый ползунок оставляем в исходной метрике — обратная
                // конвертация с округлением дрейфовала бы значение на каждом сохранении
                func toMetric(_ display: Double, original: Double?, originalDisplay: Double?) -> Double {
                    if display == originalDisplay, let original { return original }
                    return kind.map { DivoMeasuring.metricValue(display: display, kind: $0, system: system) } ?? display
                }
                let original = self.currentFilters[keyPath: keyPath]
                let lower = toMetric(firstValue, original: original?.lowerBound.doubleValue, originalDisplay: currentMin)
                let upper = toMetric(secondValue, original: original?.upperBound.doubleValue, originalDisplay: currentMax)
                self.currentFilters[keyPath: keyPath] = T(lower)...T(upper)
            } else {
                self.currentFilters[keyPath: keyPath] = nil
            }
            self.updateUI()
        }

        navigationController?.pushViewController(vc, animated: true)
    }
    
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
    
    private func showHairLengthFilter() {
        var displayOptions = [FilterOptionItem(id: "all", title: DivoStrings.debugAll)]
        displayOptions.append(contentsOf: hairLengthOptions.map { FilterOptionItem(id: String($0.id), title: $0.title) })
        
        let selectedIds = (currentFilters.hairLength ?? []).map { String($0) }
        let vc = FilterOptionsController(title: DivoStrings.paramHairLength, options: displayOptions, selectedOptionIds: selectedIds, isMultiSelect: true, showSearch: false)
        
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
        let vc = FilterOptionsController(title: DivoStrings.paramHairColor, options: displayOptions, selectedOptionIds: selectedIds, isMultiSelect: true, showSearch: false)
        
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
        let vc = FilterOptionsController(title: DivoStrings.paramEyeColor, options: displayOptions, selectedOptionIds: selectedIds, isMultiSelect: true, showSearch: false)
        
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
        let vc = FilterOptionsController(title: DivoStrings.paramSkinColor, options: displayOptions, selectedOptionIds: selectedIds, isMultiSelect: true, showSearch: false)
        
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
        onApply?(currentFilters)
        dismiss(animated: true)
    }
    
    @objc private func applyTapped() {
        onApply?(currentFilters)
        dismiss(animated: true)
    }
    
    @objc private func cityChanged() {
        let text = cityTextField.text ?? ""
        currentFilters.city = text.isEmpty ? nil : text
        updateUI()
    }

    @objc private func paidOnlyChanged(_ sender: UISwitch) {
        currentFilters.isPaidOnly = sender.isOn
        updateUI()
    }
    
    @objc private func ageTapped() {
        self.showRangeFilter(title: DivoStrings.ageYo, keyPath: \.ageRange, min: 14, max: 100)
    }
    
    @objc private func dateOfBirthTapped() {
        self.view.endEditing(true)
        
        let todayStart = Calendar.current.startOfDay(for: Date())
        
        // Лимит назад: ровно 1 год назад от сегодняшнего дня
        let minDate = Calendar.current.date(byAdding: .year, value: -1, to: todayStart) ?? todayStart
        let minTimestamp = Int32(minDate.timeIntervalSince1970)
        
        // Лимит вперед: ровно 20 лет вперед от сегодняшнего дня
        let maxDate = Calendar.current.date(byAdding: .year, value: 10, to: todayStart) ?? todayStart
        let maxTimestamp = Int32(maxDate.timeIntervalSince1970)
        
        // По умолчанию предлагаем сегодняшнюю дату (если дата еще не была выбрана)
        let defaultTimestamp = Int32(todayStart.timeIntervalSince1970)
        let initialTs = self.currentFilters.dateOfEventTimestamp ?? defaultTimestamp
        
        let controller = DivoDatePickerController(
            mode: .date,
            initialTimestamp: initialTs,
            title: DivoStrings.eventsSearchDateOfEvent, // Заголовок в самом календаре
            minimumTimestamp: minTimestamp,
            maximumTimestamp: maxTimestamp
        )
        
        controller.onSave = { [weak self] timestamp in
            self?.currentFilters.dateOfEventTimestamp = timestamp
            self?.updateUI()
        }
        
        let nav = UINavigationController(rootViewController: controller)
        nav.setNavigationBarHidden(true, animated: false)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = DivoDesignTokens.Radius.card
            }
        }
        self.present(nav, animated: true)
    }
    
    @objc private func eventTypeTapped() {
        let selectedIds = currentFilters.eventTypeIds.map { String($0) }
        let vc = FilterOptionsController(
            title: DivoStrings.eventsSearchTypeEvents,
            options: eventTypeOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true
        )
        
        vc.onSave = { [weak self] selectedItems in
            self?.currentFilters.eventTypeIds = selectedItems.compactMap { Int($0.id) }
            self?.currentFilters.eventTypeTitles = selectedItems.map { $0.title }
            self?.updateUI()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func countryTapped() {
        let selectedIds = currentFilters.countryIds
        let selectedSet = Set(selectedIds)

        var orderedOptions = countryOptions
        if !selectedSet.isEmpty {
            let allOption = orderedOptions[0]
            let rest = Array(orderedOptions.dropFirst())
            let selected = rest.filter { selectedSet.contains($0.id) }
            let unselected = rest.filter { !selectedSet.contains($0.id) }
            orderedOptions = [allOption] + selected + unselected
        }

        let vc = FilterOptionsController(
            title: DivoStrings.debugCountry,
            options: orderedOptions,
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
                self.updateUI() // Переключает видимость полей под новый стейт
                self.view.layoutIfNeeded()
            }
        } else {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn]) {
                self.appearanceBackgroundView.alpha = 0
                self.appearanceContainerStack.alpha = 0
                self.appearanceBackgroundView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.moreFiltersButton.setTitle(DivoStrings.feedSearchMoreFilters, for: .normal)
                self.updateUI() // Переключает видимость полей под новый стейт
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.appearanceBackgroundView.isHidden = true
                self.appearanceContainerStack.isHidden = true
                self.appearanceBackgroundView.transform = .identity
            }
        }
    }
    
    @objc private func dismissKeyboard() { view.endEditing(true) }
}
