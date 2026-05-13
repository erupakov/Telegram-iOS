import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle
import DivoUIKit
import DivoCore

private struct AppearanceEditItem {
    let title: String
    let getValues: () -> [String]
    let emptyTitle: String
    let onTap: () -> Void
}

final class EditParametersNode: ASDisplayNode, UITextFieldDelegate {
    
    private let context: AccountContext
    
    var onBackTapped: (() -> Void)?
    var saveSocialLinks: ((LinksData) -> Void)?
    var presentController: ((UIViewController) -> Void)?
    var saveProfile: ((UpdateBiographyPageRequest) -> Void)?
    
    private let navigationBar = DivoNavigationBar()
        
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
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
    
    private var selectedAge: Int?
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
    }
    
    private var initialSnapshot: ParametersSnapshot?
    private var avatarChanged = false

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
                DivoColorPalette.screenBackground.cgColor
            ]
            gradient.locations = [0, 0.45]
        }
        return view
    }()

    private var bottomFadeOverlayBottomConstraint: NSLayoutConstraint?
    private var keyboardHandler: DivoKeyboardHandler?
    
    private var appearanceDictionaries: AppearanceDictionaryData?
    private var genderDictionaries: GenderResponse?
    
    private let model: UserDetail?

    private let loadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground.withAlphaComponent(0.6)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private let loadingSpinner = DivoSegmentedSpinner()
    

    // MARK: - Init
    
    init(context: AccountContext, model: UserDetail?) {
        self.context = context
        self.model = model
        super.init()
        
        if let app = model?.model?.appearance {
            self.selectedHeight = app.height
            self.selectedWeight = app.weight
            self.selectedWaist = app.waist
            self.selectedHips = app.hips
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
        self.selectedGenderId = model?.gender?.id
        self.selectedGenderTitle = model?.gender?.title
        self.selectedAge = calculateAge(from: model?.birthday ?? "")
        
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didLoad() {
        super.didLoad()
        setupUI()
        setupConstraints()
        setupAppearanceContent()
        setupInteractions()

        applyButton.isEnabled = false
        navigationBar.setEnableRightButton(false)
    }
    
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
            skinColorId: selectedSkinColorId
        )
    }
    
    private func calculateAge(from birthdayString: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let birthday = formatter.date(from: birthdayString) else { return 0 }
        
        let now = Date()
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthday, to: now)
        return ageComponents.year ?? 0
    }

    private func updateSaveButtonState() {
        applyButton.makeDivoButton(title: DivoStrings.saveParameters, loading: DivoStrings.saving)
        let hasChanges = makeSnapshot() != initialSnapshot
        applyButton.isEnabled = hasChanges
        navigationBar.setEnableRightButton(hasChanges)
    }
    
    private func setupUI() {
        view.addSubview(navigationBar)
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        view.addSubview(bottomFadeOverlay)
        view.addSubview(applyButton)
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        let buttonBottomCns = applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        self.applyButtonBottomConstraint = buttonBottomCns

        let bottomFadeOverlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.bottomFadeOverlayBottomConstraint = bottomFadeOverlayCns
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: safeArea.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // --- ScrollView ---
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: DivoDesignTokens.Spacing.m),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),
            
            buttonBottomCns,
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            bottomFadeOverlayCns,
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: 140)
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
    
    private func scrollToField(_ field: DivoTextField) {
        let frame = field.view.frame.insetBy(dx: 0, dy: -16)
        scrollView.scrollRectToVisible(frame, animated: true)
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
            appearanceContainerStack.bottomAnchor.constraint(equalTo: appearanceBackgroundView.bottomAnchor)
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
        let selectedIds = currentId != nil ? [String(currentId!)] :[]
        
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
            var id = 0
            var title = ""
            if !selectedItems.isEmpty && !selectedItems.contains(where: { $0.id == "all" }) {
                id = selectedItems.map { Int($0.id) ?? 0 }.first ?? 0
                title =  selectedItems.first?.title ?? ""
            }
            completion(id, title)
        }
        presentSheet(vc)
    }
    
    private func showSingleInput(title: String, min: Double, max: Double, current: Double?, completion: @escaping (Double?) -> Void) {
        let vc = RangeFilterController(
            title: title,
            min: min,
            max: max,
            currentLower: nil,
            currentUpper: current,
            isSingleValue: true,
            isOpenPresent: true,
            isResetButton: false
        )
        
        vc.onSave = {[weak self] _, upperVal in
            completion(upperVal)
            self?.updateAppearanceValues()
            self?.updateSaveButtonState()
        }
        presentSheet(vc)
    }
    
    private func setupAppearanceEditItems() {
        appearanceEditItems = [
            AppearanceEditItem(
                title: DivoStrings.ageYo,
                getValues: { [weak self] in self?.selectedAge.map {["\($0)"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.ageYo, min: 14, max: 100, current: self?.selectedAge.map{Double($0)}) { val in
                        self?.selectedAge = val.map { Int($0) }
                    }
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.heightCm,
                getValues: { [weak self] in self?.selectedHeight.map { ["\(Int($0)) cm"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.heightCm, min: 100, max: 300, current: self?.selectedHeight) { val in
                        self?.selectedHeight = val
                    }
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.weightKg,
                getValues: { [weak self] in self?.selectedWeight.map { ["\(Int($0)) kg"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: {[weak self] in
                    self?.showSingleInput(title: DivoStrings.weightKg, min: 30, max: 150, current: self?.selectedWeight) { val in
                        self?.selectedWeight = val
                    }
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.waistCm,
                getValues: { [weak self] in self?.selectedWaist.map { ["\(Int($0)) cm"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.waistCm, min: 40, max: 120, current: self?.selectedWaist) { val in
                        self?.selectedWaist = val
                    }
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.hipsCm,
                getValues: { [weak self] in self?.selectedHips.map { ["\(Int($0)) cm"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.hipsCm, min: 60, max: 150, current: self?.selectedHips) { val in
                        self?.selectedHips = val
                    }
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.shoeSizeEU,
                getValues: {[weak self] in self?.selectedShoeSize.map { ["\(Int($0))"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.shoeSizeEU, min: 30, max: 50, current: self?.selectedShoeSize) { val in
                        self?.selectedShoeSize = val
                    }
                }
            ),
        ]
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
        applyButton.setSaving(active, in: self.view)
    }
    
    func showScreenLoading() {
        loadingOverlay.backgroundColor = DivoColorPalette.screenBackground.withAlphaComponent(0.6)
        loadingOverlay.isHidden = false
        loadingSpinner.isHidden = false
        loadingSpinner.startAnimating()
        self.view.bringSubviewToFront(loadingSpinner)
    }
    
    func hideScreenLoading() {
        loadingOverlay.isHidden = true
        loadingSpinner.stopAnimating()
        loadingSpinner.isHidden = true
    }

    func changeBackgroundScreenLoading() {
        loadingOverlay.backgroundColor = DivoColorPalette.screenBackground.withAlphaComponent(0.1)
        loadingSpinner.stopAnimating()
        loadingSpinner.isHidden = true
    }
    
    
    // MARK: - Actions
    
    @objc private func appearanceCellTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < appearanceEditItems.count else { return }
        appearanceEditItems[view.tag].onTap()
    }
    
    @objc private func textFieldDidChangeValue() {
        updateSaveButtonState()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func saveButtonPressed() {
        self.view.endEditing(true)

        let data = UpdateBiographyPageRequest(
            fullName: self.model?.fullName,
            gender: self.selectedGenderId,
            model: UpdateBiographyPageRequest.ModelData(
                description: self.model?.model?.description,
                appearance: Appearance(
                    measuringSystem: "metric",
                    height: self.selectedHeight,
                    weight: self.selectedWeight,
                    breastSize: nil,
                    waist: self.selectedWaist,
                    hips: self.selectedHips,
                    shoesSize: self.selectedShoeSize,
                    hairColor: self.selectedHairColorId,
                    hairLength: self.selectedHairLengthId,
                    eyeColor: self.selectedEyeColorId,
                    skinColor: selectedSkinColorId
                )
            )
        )
        
        self.toggleSaving(active: true)
        self.saveProfile?(data)
    }
    
    @objc private func genderTapped() {
        self.view.endEditing(true)
        guard let dict = genderDictionaries?.data else { return }
        
        let options = dict.map { FilterOptionItem(id: String($0.id), title: $0.title) }
        let selectedIds = selectedGenderId != nil ? [String(selectedGenderId!)] :[]
        
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
            if let selected = selectedItems.first {
                self?.selectedGenderId = selected.id
                self?.selectedGenderTitle = selected.title
            } else {
                self?.selectedGenderId = nil
                self?.selectedGenderTitle = nil
            }
            self?.updateDropdownsUI()
            self?.updateSaveButtonState()
        }
        presentSheet(vc)
    }
    
    @objc private func hairLengthTapped() {
        self.view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.hairLength, dict: appearanceDictionaries?.hairLength, currentId: selectedHairLengthId) {[weak self] id, title in
            self?.selectedHairLengthId = id
            self?.selectedHairLengthTitle = title
            self?.updateDropdownsUI()
            self?.updateSaveButtonState()
        }
    }
    
    @objc private func hairColorTapped() {
        self.view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.hairColor, dict: appearanceDictionaries?.hairColor, currentId: selectedHairColorId) { [weak self] id, title in
            self?.selectedHairColorId = id
            self?.selectedHairColorTitle = title
            self?.updateDropdownsUI()
            self?.updateSaveButtonState()
        }
    }
    
    @objc private func eyeColorTapped() {
        self.view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.eyeColor, dict: appearanceDictionaries?.eyeColor, currentId: selectedEyeColorId) { [weak self] id, title in
            self?.selectedEyeColorId = id
            self?.selectedEyeColorTitle = title
            self?.updateDropdownsUI()
            self?.updateSaveButtonState()
        }
    }
    
    @objc private func skinColorTapped() {
        self.view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.skinColor, dict: appearanceDictionaries?.skinColor, currentId: selectedSkinColorId) { [weak self] id, title in
            self?.selectedSkinColorId = id
            self?.selectedSkinColorTitle = title
            self?.updateDropdownsUI()
            self?.updateSaveButtonState()
        }
    }
    
    
    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: 16,
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

// MARK: - EditSocialLinksNodeGradientView

private final class EditSocialLinksNodeGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}
