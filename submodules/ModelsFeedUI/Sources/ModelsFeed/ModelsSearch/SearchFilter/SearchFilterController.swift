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
    var onSelectCountry: ((@escaping (String, String) -> Void) -> Void)?
    
    private struct AppearanceFilterItem {
        let title: String
        let getValue: () -> String
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
        
    private let moreFiltersButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(DivoStrings.feedSearchMoreFilters, for: .normal)
        btn.setTitleColor(UIColor(hexString: "#FF772D"), for: .normal)
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
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        view.backgroundColor = UIColor(hexString: "#F0F0F0")
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
                getValue: { [weak self] in
                    guard let range = self?.currentFilters.ageRange else { return DivoStrings.debugAny }
                    return "\(Int(range.lowerBound))-\(Int(range.upperBound))"
                },
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramAge, keyPath: \.ageRange, min: 15, max: 40, unit: "y.o") }
            ),
            AppearanceFilterItem(
                title: DivoStrings.heightCm,
                getValue: { [weak self] in
                    guard let range = self?.currentFilters.heightRange else { return DivoStrings.debugAny }
                    return "\(Int(range.lowerBound))-\(Int(range.upperBound))"
                },
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramHeight, keyPath: \.heightRange, min: 150, max: 200, unit: "cm") }
            ),
            AppearanceFilterItem(
                title: DivoStrings.weightKg,
                getValue: { [weak self] in
                    guard let range = self?.currentFilters.weightRange else { return DivoStrings.debugAny }
                    return "\(Int(range.lowerBound))-\(Int(range.upperBound))"
                },
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramWeight, keyPath: \.weightRange, min: 40, max: 120, unit: "kg") }
            ),
            AppearanceFilterItem(
                title: DivoStrings.waistCm,
                getValue: { [weak self] in
                    guard let range = self?.currentFilters.waistRange else { return DivoStrings.debugAny }
                    return "\(Int(range.lowerBound))-\(Int(range.upperBound))"
                },
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramWaist, keyPath: \.waistRange, min: 50, max: 120, unit: "cm") }
            ),
            AppearanceFilterItem(
                title: DivoStrings.hipsCm,
                getValue: { [weak self] in
                    guard let range = self?.currentFilters.hipsRange else { return DivoStrings.debugAny }
                    return "\(Int(range.lowerBound))-\(Int(range.upperBound))"
                },
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramHips, keyPath: \.hipsRange, min: 70, max: 130, unit: "cm") }
            ),
            AppearanceFilterItem(
                title: DivoStrings.shoeSizeEU,
                getValue: { [weak self] in
                    guard let range = self?.currentFilters.shoeSizeRange else { return DivoStrings.debugAny }
                    return "\(Int(range.lowerBound))-\(Int(range.upperBound))"
                },
                onTap: { [weak self] in self?.showRangeFilter(title: DivoStrings.paramShoeSize, keyPath: \.shoeSizeRange, min: 35, max: 46, unit: "") }
            ),
            AppearanceFilterItem(
                title: DivoStrings.hairLength,
                getValue: { [weak self] in
                    guard let self = self, let hairLength = self.currentFilters.hairLength, !hairLength.isEmpty else { return DivoStrings.debugAll }
                    return hairLength.joined(separator: ", ")
                },
                onTap: { [weak self] in self?.showHairLengthFilter() }
            ),
            AppearanceFilterItem(
                title: DivoStrings.hairColor,
                getValue: { [weak self] in
                    guard let self = self, let hairColor = self.currentFilters.hairColor, !hairColor.isEmpty else { return DivoStrings.debugAll }
                    return hairColor.joined(separator: ", ")
                },
                onTap: { [weak self] in self?.showHairColorFilter() }
            ),
            AppearanceFilterItem(
                title: DivoStrings.eyeColor,
                getValue: { [weak self] in
                    guard let self = self, let eyeColor = self.currentFilters.eyeColor, !eyeColor.isEmpty else { return DivoStrings.debugAll }
                    return eyeColor.joined(separator: ", ")
                },
                onTap: { [weak self] in self?.showEyeColorFilter() }
            ),
            AppearanceFilterItem(
                title: DivoStrings.skinColor,
                getValue: { [weak self] in
                    guard let self = self, let skinColor = self.currentFilters.skinColor, !skinColor.isEmpty else { return DivoStrings.debugAll }
                    return skinColor.joined(separator: ", ")
                },
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
        
        moreFiltersButton.addTarget(self, action: #selector(moreFiltersTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(moreFiltersButton)
        NSLayoutConstraint.activate([
            moreFiltersButton.heightAnchor.constraint(equalToConstant: 22),
        ])
        
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
            let cell = createAppearanceCell(
                title: item.title,
                value: item.getValue(),
                isLast: isLast
            )
            
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
        titleLabel.textColor = UIColor(hexString: "#222222")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(titleLabel)
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = Font.regular(14)
        valueLabel.textColor = UIColor(hexString: "#8E8E93")
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(valueLabel)
        
        let chevronImageView = UIImageView()
        chevronImageView.image = UIImage(bundleImageName: "ChevronRight") ?? UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = UIColor(hexString: "#222222")?.withAlphaComponent(0.8)
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(chevronImageView)
        
        if !isLast {
            let separator = UIView()
            separator.backgroundColor = UIColor(hexString: "#E5E5EA")
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
            if index < appearanceContainerStack.arrangedSubviews.count {
                let cell = appearanceContainerStack.arrangedSubviews[index]
                let valueLabel = cell.subviews.first(where: { $0 is UILabel && ($0 as? UILabel)?.textAlignment == .right }) as? UILabel
                valueLabel?.text = item.getValue()
            }
        }
    }
    
    private func updateUI() {
        let roleText = currentFilters.roleTitles.isEmpty ? DivoStrings.feedSearchAllRoles : currentFilters.roleTitles.joined(separator: ", ")
        roleRow.setValue(roleText)

        let genderText = currentFilters.genderTitles.isEmpty ? DivoStrings.feedSearchAllGenders : currentFilters.genderTitles.joined(separator: ", ")
        genderRow.setValue(genderText)

        let countryText = currentFilters.countryTitles.isEmpty ? DivoStrings.feedSearchAllCountries : currentFilters.countryTitles.joined(separator: ", ")
        countryRow.setValue(countryText)

        cityTextField.text = currentFilters.city
        
        updateAppearanceValues()

        let hasFilters = currentFilters.hasActiveFilters
        applyButton.isEnabled = hasFilters
        applyButton.backgroundColor = hasFilters ? UIColor(hexString: "#FF772D") : UIColor(hexString: "#E4E4E4")
    }
   
    private func showAgeFilter() {
        // TODO: Implement age range filter with slider
        print("Age filter tapped")
    }
    
    private func showRangeFilter<T>(title: String, keyPath: WritableKeyPath<SearchFilterState, ClosedRange<T>?>, min: T, max: T, unit: String) where T: BinaryFloatingPoint {
        
        // 1. ИСПРАВЛЕНИЕ: Безопасно извлекаем значения
        var currentMin: Double? = nil
        var currentMax: Double? = nil
        
        if let currentRange = self.currentFilters[keyPath: keyPath] {
            currentMin = Double(currentRange.lowerBound)
            currentMax = Double(currentRange.upperBound)
        }
        
        let vc = RangeFilterController(
            title: title,
            min: Double(min),
            max: Double(max),
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
        
        let selectedIds = currentFilters.hairLength ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.paramHairLength,
            options: displayOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            showSearch: false
        )
        
        vc.onSelectMulti = { [weak self] selectedItems in
            if selectedItems.isEmpty || selectedItems.first?.id == "all" {
                self?.currentFilters.hairLength = []
            } else {
                self?.currentFilters.hairLength = selectedItems.map { $0.id }
            }
            self?.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showHairColorFilter() {
        var displayOptions = [FilterOptionItem(id: "all", title: DivoStrings.debugAll)]
        displayOptions.append(contentsOf: hairColorOptions.map { FilterOptionItem(id: String($0.id), title: $0.title) })
        
        let selectedIds = currentFilters.hairColor ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.paramHairColor,
            options: displayOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            showSearch: false
        )
        
        vc.onSelectMulti = { [weak self] selectedItems in
            if selectedItems.isEmpty || selectedItems.first?.id == "all" {
                self?.currentFilters.hairColor = []
            } else {
                self?.currentFilters.hairColor = selectedItems.map { $0.id }
            }
            self?.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showEyeColorFilter() {
        var displayOptions = [FilterOptionItem(id: "all", title: DivoStrings.debugAll)]
        displayOptions.append(contentsOf: eyeColorOptions.map { FilterOptionItem(id: String($0.id), title: $0.title) })
        
        let selectedIds = currentFilters.eyeColor ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.paramEyeColor,
            options: displayOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            showSearch: false
        )
        
        vc.onSelectMulti = { [weak self] selectedItems in
            if selectedItems.isEmpty || selectedItems.first?.id == "all" {
                self?.currentFilters.eyeColor = []
            } else {
                self?.currentFilters.eyeColor = selectedItems.map { $0.id }
            }
            self?.updateUI()
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showSkinColorFilter() {
        var displayOptions = [FilterOptionItem(id: "all", title: DivoStrings.debugAll)]
        displayOptions.append(contentsOf: skinColorOptions.map { FilterOptionItem(id: String($0.id), title: $0.title) })
        
        let selectedIds = currentFilters.skinColor ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.paramSkinColor,
            options: displayOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            showSearch: false
        )
        
        vc.onSelectMulti = { [weak self] selectedItems in
            if selectedItems.isEmpty || selectedItems.first?.id == "all" {
                self?.currentFilters.skinColor = []
            } else {
                self?.currentFilters.skinColor = selectedItems.map { $0.id }
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

    @objc private func closeTapped() { dismiss(animated: true) }
    
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
