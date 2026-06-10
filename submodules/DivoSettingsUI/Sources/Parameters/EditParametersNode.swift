import Display
import UIKit
import AsyncDisplayKit
import AccountContext
import AppBundle
import DivoUIKit
import DivoCore

enum EditParametersPhase: Equatable {
    case loading
    case content
    case failed
}

private struct AppearanceEditItem {
    let title: String
    let getValues: () -> [String]
    let emptyTitle: String
    let onTap: () -> Void
}

final class EditParametersNode: ASDisplayNode {

    private enum Layout {
        static let buttonBottomInset: CGFloat = 40
        static let bottomFadeHeight: CGFloat = 140
        static let bottomFadeOpaqueLocation: NSNumber = 0.45
        /// Отступ от низа navigationBar до первого элемента контента.
        static let navBarToContentSpacing: CGFloat = 24
    }

    private let context: AccountContext

    var onBackTapped: (() -> Void)?
    var presentController: ((UIViewController) -> Void)?
    var saveProfile: ((UpdateBiographyPageRequest) -> Void)?

    private var phase: EditParametersPhase = .loading {
        didSet {
            if oldValue != phase {
                applyState()
            }
        }
    }

    private let navigationBar = DivoNavigationBar()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.contentInsetAdjustmentBehavior = .never
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let genderDropdown = FilterRowView(title: DivoStrings.paramGender)

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

    private var selectedGenderId: String?
    private var selectedGenderTitle: String?
    
    private var selectedBirthdayTimestamp: Int32?
    private var selectedAge: Int? {
        guard let timestamp = selectedBirthdayTimestamp else { return nil }
        let birthDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }
    
    private var selectedHeight: Double?
    private var selectedWeight: Double?
    private var selectedWaist: Double?
    private var selectedHips: Double?
    private var selectedShoeSize: Double?

    private var selectedHairLengthId: Int?
    private var selectedHairLengthTitle: String?
    private var selectedHairColorId: Int?
    private var selectedHairColorTitle: String?
    private var selectedEyeColorId: Int?
    private var selectedEyeColorTitle: String?
    private var selectedSkinColorId: Int?
    private var selectedSkinColorTitle: String?

    private struct ParametersSnapshot: Equatable {
        let genderId: String?
        let age: Int?
        let height: Double?
        let weight: Double?
        let waist: Double?
        let hips: Double?
        let shoeSize: Double?
        let hairLengthId: Int?
        let hairColorId: Int?
        let eyeColorId: Int?
        let skinColorId: Int?
        let birthdayTimestamp: Int32?
    }

    private var initialSnapshot: ParametersSnapshot?

    private let hairLengthDropdown = FilterRowView(title: DivoStrings.hairLength)
    private let hairColorDropdown = FilterRowView(title: DivoStrings.hairColor)
    private let eyeColorDropdown = FilterRowView(title: DivoStrings.eyeColor)
    private let skinColorDropdown = FilterRowView(title: DivoStrings.skinColor)

    private var appearanceEditItems: [AppearanceEditItem] = []

    private let applyButton = DivoButton()
    private var applyButtonBottomConstraint: NSLayoutConstraint?

    private let bottomFadeOverlay: UIView = {
        let view = EditSocialLinksNodeGradientView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
                DivoColorPalette.screenBackground.cgColor,
            ]
            gradient.locations = [0, Layout.bottomFadeOpaqueLocation]
        }
        return view
    }()

    private var bottomFadeOverlayBottomConstraint: NSLayoutConstraint?

    private var appearanceDictionaries: AppearanceDictionaryData?
    private var genderDictionaries: GenderResponse?

    private let model: UserDetail?

    private let loadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground.withAlphaComponent(0.6)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        return view
    }()

    private let loadingSpinner = DivoSegmentedSpinner()

    private let snackbar = DivoSnackbar()
    typealias SnackbarStyle = DivoSnackbar.Style

    // MARK: - Init

    init(context: AccountContext, model: UserDetail?) {
        self.context = context
        self.model = model
        super.init()

        if let app = model?.model?.appearance {
            // Числа с сервера приводим к метрике по маркеру записи: запись могла быть сделана в imperial
            self.selectedHeight = app.height.map { DivoMeasuring.normalizedMetric($0, sourceSystem: app.measuringSystem, kind: .height) }
            self.selectedWeight = app.weight.map { DivoMeasuring.normalizedMetric($0, sourceSystem: app.measuringSystem, kind: .weight) }
            self.selectedWaist = app.waist.map { DivoMeasuring.normalizedMetric($0, sourceSystem: app.measuringSystem, kind: .waist) }
            self.selectedHips = app.hips.map { DivoMeasuring.normalizedMetric($0, sourceSystem: app.measuringSystem, kind: .hips) }
            self.selectedShoeSize = app.shoesSize

            self.selectedHairLengthId = app.hairLength?.id
            self.selectedHairLengthTitle = app.hairLength?.title
            self.selectedHairColorId = app.hairColor?.id
            self.selectedHairColorTitle = app.hairColor?.title
            self.selectedEyeColorId = app.eyeColor?.id
            self.selectedEyeColorTitle = app.eyeColor?.title
            self.selectedSkinColorId = app.skinColor?.id
            self.selectedSkinColorTitle = app.skinColor?.title
        }
        let genderDisplay = DivoGender.display(for: model?.gender)
        self.selectedGenderId = genderDisplay?.id
        self.selectedGenderTitle = genderDisplay?.title
        self.selectedBirthdayTimestamp = parseBirthday(model?.birthday)

        self.backgroundColor = DivoColorPalette.screenBackground

        navigationBar.makeNavigationBar(
            title: DivoStrings.myParameters.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            rightButtonConfiguration: .text(DivoStrings.save),
            onBackTapped: { [weak self] in self?.onBackTapped?() },
            onCircleTextTapped: { [weak self] in self?.saveButtonPressed() }
        )

        applyButton.makeDivoButton(title: DivoStrings.saveParameters, loading: DivoStrings.saving)

        setupAppearanceEditItems()
    }

    override func didLoad() {
        super.didLoad()
        setupUI()
        setupConstraints()
        setupAppearanceContent()
        setupInteractions()
        applyState()

        applyButton.isEnabled = false
        navigationBar.setEnableRightButton(false)

        // Резервируем место под applyButton + safe area, чтобы контент не закрывался
        // нижней кнопкой и градиентным fade-оверлеем.
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Layout.bottomFadeHeight, right: 0)
        scrollView.scrollIndicatorInsets = scrollView.contentInset
    }

    // MARK: - Snapshot / age

    private func makeSnapshot() -> ParametersSnapshot {
        ParametersSnapshot(
            genderId: selectedGenderId,
            age: selectedAge,
            height: selectedHeight,
            weight: selectedWeight,
            waist: selectedWaist,
            hips: selectedHips,
            shoeSize: selectedShoeSize,
            hairLengthId: selectedHairLengthId,
            hairColorId: selectedHairColorId,
            eyeColorId: selectedEyeColorId,
            skinColorId: selectedSkinColorId,
            birthdayTimestamp: selectedBirthdayTimestamp
        )
    }

    private func parseBirthday(_ birthdayString: String?) -> Int32? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let birthdayString = birthdayString,
              let date = formatter.date(from: birthdayString)
        else { return nil }
        return Int32(date.timeIntervalSince1970)
    }
    
    private func getFormattedBirthdayForAPI() -> String? {
        guard let ts = selectedBirthdayTimestamp else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
    }

    private func updateSaveButtonState() {
        let hasChanges = makeSnapshot() != initialSnapshot
        applyButton.isEnabled = hasChanges
        navigationBar.setEnableRightButton(hasChanges)
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(navigationBar)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        view.addSubview(bottomFadeOverlay)
        view.addSubview(applyButton)
    }

    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide

        let buttonBottomCns = applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Layout.buttonBottomInset)
        self.applyButtonBottomConstraint = buttonBottomCns

        let bottomFadeOverlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.bottomFadeOverlayBottomConstraint = bottomFadeOverlayCns

        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: safeArea.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Layout.navBarToContentSpacing),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),

            buttonBottomCns,
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            bottomFadeOverlayCns,
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: Layout.bottomFadeHeight),
        ])

        view.addSubview(loadingOverlay)
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingSpinner)

        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingSpinner.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor),
            loadingSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            loadingSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
        ])
    }

    private func setupInteractions() {
        applyButton.addTarget(self, action: #selector(saveButtonPressed), for: .touchUpInside)
    }

    private func setupAppearanceContent() {
        genderDropdown.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(genderDropdown)

        contentStackView.addArrangedSubview(appearanceBackgroundView)
        appearanceBackgroundView.addSubview(appearanceContainerStack)

        NSLayoutConstraint.activate([
            appearanceBackgroundView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor),
            appearanceBackgroundView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor),

            appearanceContainerStack.topAnchor.constraint(equalTo: appearanceBackgroundView.topAnchor),
            appearanceContainerStack.leadingAnchor.constraint(equalTo: appearanceBackgroundView.leadingAnchor),
            appearanceContainerStack.trailingAnchor.constraint(equalTo: appearanceBackgroundView.trailingAnchor),
            appearanceContainerStack.bottomAnchor.constraint(equalTo: appearanceBackgroundView.bottomAnchor),
        ])

        contentStackView.addArrangedSubview(hairLengthDropdown)
        contentStackView.addArrangedSubview(hairColorDropdown)
        contentStackView.addArrangedSubview(eyeColorDropdown)
        contentStackView.addArrangedSubview(skinColorDropdown)

        genderDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(genderTapped)))
        hairLengthDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hairLengthTapped)))
        hairColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hairColorTapped)))
        eyeColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(eyeColorTapped)))
        skinColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skinColorTapped)))

        reloadAppearanceOptions()
        updateDropdownsUI()
        initialSnapshot = makeSnapshot()
    }

    private func reloadAppearanceOptions() {
        appearanceContainerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, item) in appearanceEditItems.enumerated() {
            let isLast = index == appearanceEditItems.count - 1
            let cell = AppearanceFilterRowView(title: item.title, isLast: isLast)
            cell.setItems(item.getValues(), emptyTitle: DivoStrings.notSet)

            let tap = UITapGestureRecognizer(target: self, action: #selector(appearanceCellTapped(_:)))
            cell.addGestureRecognizer(tap)
            cell.tag = index
            appearanceContainerStack.addArrangedSubview(cell)
        }
    }

    private func updateDropdownsUI() {
        genderDropdown.setItems([selectedGenderTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
        hairLengthDropdown.setItems([selectedHairLengthTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
        hairColorDropdown.setItems([selectedHairColorTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
        eyeColorDropdown.setItems([selectedEyeColorTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
        skinColorDropdown.setItems([selectedSkinColorTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
    }

    private func updateAppearanceValues() {
        for (index, item) in appearanceEditItems.enumerated() {
            if index < appearanceContainerStack.arrangedSubviews.count,
               let cell = appearanceContainerStack.arrangedSubviews[index] as? AppearanceFilterRowView {
                cell.setItems(item.getValues(), emptyTitle: DivoStrings.notSet)
            }
        }
    }

    private func presentSheet(_ vc: UIViewController) {
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = DivoDesignTokens.Radius.card
            }
        }
        presentController?(nav)
    }

    private func showDictionaryFilter(title: String, dict: [AppearanceOption]?, currentId: Int?, completion: @escaping (Int?, String?) -> Void) {
        guard let dict = dict else { return }

        let options = dict.map { FilterOptionItem(id: String($0.id), title: $0.title) }
        let selectedIds = currentId.map { [String($0)] } ?? []

        let vc = FilterOptionsController(
            title: title,
            options: options,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: false,
            isOpenPresent: true,
            isResetButton: false
        )

        vc.onSave = { selectedItems in
            guard let selected = selectedItems.first, selected.id != "all", let id = Int(selected.id) else {
                completion(nil, nil)
                return
            }
            completion(id, selected.title)
        }
        presentSheet(vc)
    }

    private func showSingleInput(kind: DivoMeasureKind, min: Double, max: Double, current: Double?, completion: @escaping (Double?) -> Void) {
        let system = DivoMeasuringSystem.current
        let displayCurrent = current.map { DivoMeasuring.displayValue(metric: $0, kind: kind, system: system) }
        let vc = RangeFilterController(
            title: DivoMeasuring.inputTitle(kind: kind, system: system),
            min: DivoMeasuring.displayValue(metric: min, kind: kind, system: system),
            max: DivoMeasuring.displayValue(metric: max, kind: kind, system: system),
            currentLower: nil,
            currentUpper: displayCurrent,
            isSingleValue: true,
            isOpenPresent: true,
            isResetButton: false
        )

        vc.onSave = { [weak self] _, upperVal in
            // Ползунок не двигали — оставляем исходную метрику, иначе обратная
            // конвертация с округлением сдвигала бы значение на каждом сохранении
            let metricVal = upperVal == displayCurrent
                ? current
                : upperVal.map { DivoMeasuring.metricValue(display: $0, kind: kind, system: system) }
            completion(metricVal)
            self?.updateAppearanceValues()
            self?.updateSaveButtonState()
        }
        presentSheet(vc)
    }

    private func setupAppearanceEditItems() {
        appearanceEditItems = [
            AppearanceEditItem(
                title: DivoStrings.ageYo,
                getValues: { [weak self] in self?.selectedAge.map { ["\($0)"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    guard let self = self else { return }
                    self.view.endEditing(true)
                    
                    let todayStart = Calendar.current.startOfDay(for: Date())
                    
                    // Минимальная дата: Сегодня минус 100 лет (максимальный возраст 100)
                    let minDate = Calendar.current.date(byAdding: .year, value: -100, to: todayStart) ?? todayStart
                    let minTimestamp = Int32(minDate.timeIntervalSince1970)
                    
                    // Максимальная дата: Сегодня минус 14 лет (минимальный возраст 14)
                    let maxDate = Calendar.current.date(byAdding: .year, value: -14, to: todayStart) ?? todayStart
                    let maxTimestamp = Int32(maxDate.timeIntervalSince1970)
                    
                    // По умолчанию предлагаем возраст 18 лет (или старше)
                    let defaultDate = Calendar.current.date(byAdding: .year, value: -18, to: todayStart) ?? maxDate
                    let initialTs = self.selectedBirthdayTimestamp ?? Int32(defaultDate.timeIntervalSince1970)
                    
                    let controller = DivoDatePickerController(
                        mode: .date,
                        initialTimestamp: initialTs,
                        title: DivoStrings.dateOfBirth,
                        minimumTimestamp: minTimestamp,
                        maximumTimestamp: maxTimestamp
                    )
                    
                    controller.onSave = { [weak self] timestamp in
                        self?.selectedBirthdayTimestamp = timestamp
                        self?.updateAppearanceValues()
                        self?.updateSaveButtonState()
                    }
                    
                    self.presentSheet(controller)
                }
            ),
            AppearanceEditItem(
                title: DivoMeasuring.title(kind: .height),
                getValues: { [weak self] in self?.selectedHeight.map { [DivoMeasuring.valueWithUnit(metric: $0, kind: .height)] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(kind: .height, min: 140, max: 210, current: self?.selectedHeight) { val in
                        self?.selectedHeight = val
                    }
                }
            ),
            AppearanceEditItem(
                title: DivoMeasuring.title(kind: .weight),
                getValues: { [weak self] in self?.selectedWeight.map { [DivoMeasuring.valueWithUnit(metric: $0, kind: .weight)] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(kind: .weight, min: 40, max: 130, current: self?.selectedWeight) { val in
                        self?.selectedWeight = val
                    }
                }
            ),
            AppearanceEditItem(
                title: DivoMeasuring.title(kind: .waist),
                getValues: { [weak self] in self?.selectedWaist.map { [DivoMeasuring.valueWithUnit(metric: $0, kind: .waist)] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(kind: .waist, min: 50, max: 120, current: self?.selectedWaist) { val in
                        self?.selectedWaist = val
                    }
                }
            ),
            AppearanceEditItem(
                title: DivoMeasuring.title(kind: .hips),
                getValues: { [weak self] in self?.selectedHips.map { [DivoMeasuring.valueWithUnit(metric: $0, kind: .hips)] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(kind: .hips, min: 70, max: 140, current: self?.selectedHips) { val in
                        self?.selectedHips = val
                    }
                }
            ),
            AppearanceEditItem(
                title: DivoMeasuring.title(kind: .shoeSize),
                getValues: { [weak self] in self?.selectedShoeSize.map { [DivoMeasuring.valueString(metric: $0, kind: .shoeSize)] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(kind: .shoeSize, min: 34, max: 48, current: self?.selectedShoeSize) { val in
                        self?.selectedShoeSize = val
                    }
                }
            ),
        ]
    }

    // MARK: - State

    private func applyState() {
        switch phase {
        case .loading:
            loadingOverlay.backgroundColor = DivoColorPalette.screenBackground.withAlphaComponent(0.6)
            loadingOverlay.isHidden = false
            loadingSpinner.isHidden = false
            loadingSpinner.startAnimating()
            view.bringSubviewToFront(loadingSpinner)
        case .content:
            loadingOverlay.isHidden = true
            loadingSpinner.stopAnimating()
            loadingSpinner.isHidden = true
        case .failed:
            // .failed визуально остаётся диммированной поверх контента — ошибка покрывается
            // persistent snackbar на уровне выше (см. EditParametersController).
            loadingOverlay.backgroundColor = DivoColorPalette.screenBackground.withAlphaComponent(0.1)
            loadingOverlay.isHidden = false
            loadingSpinner.stopAnimating()
            loadingSpinner.isHidden = true
        }
    }

    // MARK: - Internal

    func toggleSpinner(active: Bool) {
        applyButton.isUserInteractionEnabled = !active
    }

    func configureAppearanceDictionaries(_ dict: AppearanceDictionaryData) {
        self.appearanceDictionaries = dict
    }

    func configureGenderDictionaries(_ dict: GenderResponse) {
        self.genderDictionaries = dict
    }

    func toggleSaving(active: Bool) {
        applyButton.setSaving(active, in: view)
    }

    func markLoading() {
        phase = .loading
    }

    func markContent() {
        phase = .content
    }

    func markFailed() {
        phase = .failed
    }

    // MARK: - Actions

    @objc private func appearanceCellTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < appearanceEditItems.count else { return }
        appearanceEditItems[view.tag].onTap()
    }

    @objc private func saveButtonPressed() {
        view.endEditing(true)

        let data = UpdateBiographyPageRequest(
            fullName: model?.fullName,
            gender: selectedGenderId,
            birthday: getFormattedBirthdayForAPI(),
            model: UpdateBiographyPageRequest.ModelData(
                description: model?.model?.description,
                appearance: Appearance(
                    measuringSystem: "metric",
                    height: selectedHeight,
                    weight: selectedWeight,
                    breastSize: nil,
                    waist: selectedWaist,
                    hips: selectedHips,
                    shoesSize: selectedShoeSize,
                    hairColor: selectedHairColorId,
                    hairLength: selectedHairLengthId,
                    eyeColor: selectedEyeColorId,
                    skinColor: selectedSkinColorId
                )
            )
        )

        toggleSaving(active: true)
        saveProfile?(data)
    }

    @objc private func genderTapped() {
        view.endEditing(true)
        guard let dict = genderDictionaries?.data else { return }

        let options = DivoGender.pickerOptions(from: dict).map { FilterOptionItem(id: $0.id, title: $0.title) }
        let selectedIds = selectedGenderId.map { [$0] } ?? []

        let vc = FilterOptionsController(
            title: DivoStrings.paramGender,
            options: options,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: false,
            isOpenPresent: true,
            isResetButton: false
        )

        vc.onSave = { [weak self] selectedItems in
            guard let self = self else { return }
            if let selected = selectedItems.first {
                self.selectedGenderId = selected.id
                self.selectedGenderTitle = selected.title
            } else {
                self.selectedGenderId = nil
                self.selectedGenderTitle = nil
            }
            self.updateDropdownsUI()
            self.updateSaveButtonState()
        }
        presentSheet(vc)
    }

    @objc private func hairLengthTapped() {
        view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.hairLength, dict: appearanceDictionaries?.hairLength, currentId: selectedHairLengthId) { [weak self] id, title in
            self?.selectedHairLengthId = id
            self?.selectedHairLengthTitle = title
            self?.updateDropdownsUI()
            self?.updateSaveButtonState()
        }
    }

    @objc private func hairColorTapped() {
        view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.hairColor, dict: appearanceDictionaries?.hairColor, currentId: selectedHairColorId) { [weak self] id, title in
            self?.selectedHairColorId = id
            self?.selectedHairColorTitle = title
            self?.updateDropdownsUI()
            self?.updateSaveButtonState()
        }
    }

    @objc private func eyeColorTapped() {
        view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.eyeColor, dict: appearanceDictionaries?.eyeColor, currentId: selectedEyeColorId) { [weak self] id, title in
            self?.selectedEyeColorId = id
            self?.selectedEyeColorTitle = title
            self?.updateDropdownsUI()
            self?.updateSaveButtonState()
        }
    }

    @objc private func skinColorTapped() {
        view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.skinColor, dict: appearanceDictionaries?.skinColor, currentId: selectedSkinColorId) { [weak self] id, title in
            self?.selectedSkinColorId = id
            self?.selectedSkinColorTitle = title
            self?.updateDropdownsUI()
            self?.updateSaveButtonState()
        }
    }

    // MARK: - Snackbar

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: view,
            message: message,
            style: style,
            bottomInset: DivoDesignTokens.Spacing.m,
            bottomAnchor: applyButton.topAnchor,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }
}

// MARK: - Gradient view

private final class EditSocialLinksNodeGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}
