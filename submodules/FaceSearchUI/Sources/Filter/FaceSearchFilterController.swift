import Display
import UIKit
import DivoCore
import DivoUIKit

final class FaceSearchFilterController: UIViewController {

    var currentFilters: FaceSearchFilterState

    var hairLengthOptions: [FilterOptionAppearanceItem] = []

    var roleOptions: [FilterOptionItem] = [
        FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllRoles),
        FilterOptionItem(id: "model", title: DivoStrings.debugModel),
        FilterOptionItem(id: "new_face", title: DivoStrings.debugNewTalent),
        FilterOptionItem(id: "agency_employee", title: DivoStrings.debugAgency)
    ]

    lazy var countryOptions: [FilterOptionItem] = {
        var options = [FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllCountries)]
        options.append(contentsOf: CountryHelper.getAllCountries())
        return options
    }()

    var onApply: ((FaceSearchFilterState) -> Void)?
    var onClose: ((FaceSearchFilterState) -> Void)?

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

    // MARK: Similarity

    private let similarityCard: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let similarityTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText
        label.text = DivoStrings.faceSearchFilterSimilarity
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let similarityValueLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let similaritySlider: SimilarityStepSlider = {
        let slider = SimilarityStepSlider()
        slider.steps = FaceSearchFilterState.similaritySteps.map { CGFloat($0) }
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    private let similarityHintLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(13)
        label.textColor = DivoColorPalette.systemLabelPlaceholder
        label.numberOfLines = 0
        label.text = DivoStrings.faceSearchFilterSimilarityHint
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: Main rows

    private let roleRow = FilterRowView(title: DivoStrings.debugRole)
    private let countryRow = FilterRowView(title: DivoStrings.debugCountry)

    // MARK: Expandable

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

    // MARK: Bottom

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

    init(currentFilters: FaceSearchFilterState) {
        self.currentFilters = currentFilters
        super.init(nibName: nil, bundle: nil)

        navigationBar.makeNavigationBar(
            title: DivoStrings.faceSearchFilterTitle,
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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        setupScrollViewInsets()
    }

    // MARK: - Private

    private func setupScrollViewInsets() {
        let bottomInset = applyButton.frame.height + 66
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
    }

    private func setupAppearanceFilterItems() {
        var items: [AppearanceFilterItem] = [
            AppearanceFilterItem(
                title: DivoStrings.ageYo,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.ageRange else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(title: DivoStrings.ageYo, keyPath: \.ageRange, min: 14, max: 100)
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.heightCm,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.heightRange else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(title: DivoStrings.heightCm, keyPath: \.heightRange, min: 150, max: 200)
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
                    self?.showRangeFilter(title: DivoStrings.paramWaist, keyPath: \.waistRange, min: 50, max: 120)
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.hipsCm,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.hipsRange else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(title: DivoStrings.paramHips, keyPath: \.hipsRange, min: 70, max: 130)
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.shoeSizeEU,
                getValues: { [weak self] in
                    guard let range = self?.currentFilters.shoeSizeRange else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(title: DivoStrings.paramShoeSize, keyPath: \.shoeSizeRange, min: 35, max: 46)
                }
            )
        ]

        if !hairLengthOptions.isEmpty {
            items.append(AppearanceFilterItem(
                title: DivoStrings.hairLength,
                getValues: { [weak self] in
                    guard let self, let selectedIds = self.currentFilters.hairLength, !selectedIds.isEmpty else {
                        return []
                    }
                    return self.hairLengthOptions
                        .filter { selectedIds.contains($0.id) }
                        .map { $0.title }
                },
                emptyTitle: DivoStrings.debugAll,
                onTap: { [weak self] in self?.showHairLengthFilter() }
            ))
        }

        appearanceFilterItems = items
    }

    private func setupCustomNavBar() {
        view.addSubview(navigationBar)
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DivoDesignTokens.Spacing.m),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.keyboardDismissMode = .onDrag
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -DivoDesignTokens.Spacing.xl)
        ])

        setupSimilarityCard()
        stackView.addArrangedSubview(similarityCard)

        let innerStack = UIStackView(arrangedSubviews: [roleRow, countryRow])
        innerStack.axis = .vertical
        innerStack.spacing = DivoDesignTokens.Spacing.m
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(innerStack)

        moreFiltersButton.addTarget(self, action: #selector(moreFiltersTapped), for: .touchUpInside)
        moreFiltersButton.addDivoPressState(.text)
        stackView.addArrangedSubview(moreFiltersButton)
        NSLayoutConstraint.activate([moreFiltersButton.heightAnchor.constraint(equalToConstant: 22)])

        let isAgency = DivoConfig.currentUserRole == .agency
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
            appearanceContainerStack.bottomAnchor.constraint(equalTo: appearanceBackgroundView.bottomAnchor)
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
        countryRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(countryTapped)))

        similaritySlider.addTarget(self, action: #selector(similarityChanged), for: .valueChanged)

        reloadAppearanceOptions()
    }

    private func setupSimilarityCard() {
        similarityCard.addSubview(similarityTitleLabel)
        similarityCard.addSubview(similarityValueLabel)
        similarityCard.addSubview(similaritySlider)
        similarityCard.addSubview(similarityHintLabel)

        NSLayoutConstraint.activate([
            similarityTitleLabel.topAnchor.constraint(equalTo: similarityCard.topAnchor, constant: 12),
            similarityTitleLabel.leadingAnchor.constraint(equalTo: similarityCard.leadingAnchor, constant: 18),

            similarityValueLabel.topAnchor.constraint(equalTo: similarityCard.topAnchor, constant: 14),
            similarityValueLabel.trailingAnchor.constraint(equalTo: similarityCard.trailingAnchor, constant: -18),

            similaritySlider.topAnchor.constraint(equalTo: similarityCard.topAnchor, constant: 38),
            similaritySlider.leadingAnchor.constraint(equalTo: similarityCard.leadingAnchor, constant: 18),
            similaritySlider.trailingAnchor.constraint(equalTo: similarityCard.trailingAnchor, constant: -18),
            similaritySlider.heightAnchor.constraint(equalToConstant: 40),

            similarityCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 118),

            similarityHintLabel.topAnchor.constraint(equalTo: similaritySlider.bottomAnchor, constant: 12),
            similarityHintLabel.leadingAnchor.constraint(equalTo: similarityCard.leadingAnchor, constant: 18),
            similarityHintLabel.trailingAnchor.constraint(equalTo: similarityCard.trailingAnchor, constant: -18),
            similarityHintLabel.bottomAnchor.constraint(equalTo: similarityCard.bottomAnchor, constant: -12)
        ])
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
        countryRow.setItems(currentFilters.countryTitles, emptyTitle: DivoStrings.feedSearchAllCountries)

        let sliderIndex = FaceSearchFilterState.similaritySteps.firstIndex(of: currentFilters.similarity) ?? 0
        similaritySlider.selectedIndex = sliderIndex
        similarityValueLabel.text = "\(Int((currentFilters.similarity * 100).rounded()))%"

        updateAppearanceValues()
        updateResetButtonState()
    }

    private func updateResetButtonState() {
        let canReset = currentFilters.hasActiveFilters
        navigationBar.setEnableRightButton(canReset)
    }

    private func showRangeFilter<T>(
        title: String,
        keyPath: WritableKeyPath<FaceSearchFilterState, ClosedRange<T>?>,
        min: T,
        max: T
    ) where T: RangeFilterable {
        var currentMin: Double?
        var currentMax: Double?
        if let currentRange = currentFilters[keyPath: keyPath] {
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
            guard let self else { return }
            if let firstValue, let secondValue {
                self.currentFilters[keyPath: keyPath] = T(firstValue)...T(secondValue)
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

    @objc private func similarityChanged() {
        let index = similaritySlider.selectedIndex
        let newValue = FaceSearchFilterState.similaritySteps[index]
        currentFilters.similarity = newValue
        similarityValueLabel.text = "\(Int((newValue * 100).rounded()))%"
        updateResetButtonState()
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

    @objc private func roleTapped() {
        let selectedIds = currentFilters.roleIds
        let vc = FilterOptionsController(title: DivoStrings.debugRole, options: roleOptions, selectedOptionIds: selectedIds, isMultiSelect: true)
        vc.onSave = { [weak self] selectedItems in
            self?.currentFilters.roleIds = selectedItems.map { $0.id }
            self?.currentFilters.roleTitles = selectedItems.map { $0.title }
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
}
