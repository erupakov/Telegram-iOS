import Display
import UIKit
import AsyncDisplayKit
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI
import DivoUIKit

private struct AppearanceEditItem {
    let title: String
    let getValues: () -> [String]
    let emptyTitle: String
    let onTap: () -> Void
}

final class EditProfileNode: ASDisplayNode {

    private static let avatarSize: CGFloat = 100

    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let model: UserDetail?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var presentationData: PresentationData
    private let presentationDataPromise: Promise<PresentationData>

    private var appearanceDictionaries: AppearanceDictionaryData?
    private var genderDictionaries: GenderResponse?
    
    private let _ready = Promise<Bool>()
    private var readyValue = false {
        didSet {
            if self.readyValue, self.readyValue != oldValue {
                self._ready.set(.single(self.readyValue))
            }
        }
    }
    var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    
    var saveProfile: ((UpdateBiographyPageRequest) -> Void)?
    var saveAgencyProfile: ((UpdateDescriptionAgencyRequest) -> Void)?
    var onAvatarTap: (() -> Void)?
    var onBackTapped: (() -> Void)?
    var presentController: ((UIViewController) -> Void)?
    
    private let navigationBar = DivoNavigationBar()
    
    // MARK: - ScrollView
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        return sv
    }()
    
    
    // MARK: - Main StackView
    
    private let mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.isLayoutMarginsRelativeArrangement = true
        stack.insetsLayoutMarginsFromSafeArea = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    
    // MARK: - Tab
    
    private lazy var segmentedControl: DivoSegmentedControl = {
        let control = DivoSegmentedControl(titles: [
            DivoStrings.biographyTitle,
            DivoStrings.myParameters,
            DivoStrings.experienceTitle
        ])
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private var selectedIndex: Int = 0

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
    
    
    // MARK: - Swipe Pager

    private lazy var horizontalPager: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.delegate = self
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.clipsToBounds = false
        sv.isScrollEnabled = false
        sv.contentInsetAdjustmentBehavior = .never 
        return sv
    }()
    
    private var pagerHeightConstraint: NSLayoutConstraint!
    
    private let bioStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.m
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let appearanceStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let experienceStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Work Experience UI (перенесено из WorkExperienceNode)
    
    private let workListBackgroundContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let workListStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let workEmptyStateContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true 
        return view
    }()

    private var workEmptyStateHeightConstraint: NSLayoutConstraint?

    private let workEmptyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(26)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.noWorkExperienceYet.uppercased()
        label.numberOfLines = 2
        return label
    }()
    
    private let workEmptySubTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.noWorkExperienceSubtitle
        label.numberOfLines = 3
        return label
    }()
    
    var workRawItems: [WorkHistoryItem] = []
    private var workHasStructuredData = false
    private var workIsLoading = true
    private let workShimmerCount = 4
    private var workExperienceCells: [Int: ExperienceView] = [:]
    
    var onEditWorkExperience: ((WorkHistoryItem) -> Void)?
    var onDeleteWorkExperience: ((Int) -> Void)?
    var onAddWorkExperience: (() -> Void)?
    
    
    // MARK: - Biography UI
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = avatarSize / 2
        iv.layer.borderColor = DivoColorPalette.cardBackground.cgColor
        iv.layer.borderWidth = 1.0
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let avatarImageSpinnerView: UIView = {
        let iv = UIView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = avatarSize / 2
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let chancePhotoView: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = DivoImage.addPhotoIcon
        button.setImage(image, for: .normal)
        button.setImage(image, for: .highlighted)
        button.tintColor = DivoColorPalette.accent
        button.layer.cornerRadius = DivoDesignTokens.Radius.l
        button.layer.borderColor = DivoColorPalette.accent.cgColor
        button.layer.borderWidth = 1
        button.layer.masksToBounds = true
        let padding: CGFloat = 4
        button.imageEdgeInsets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private let avatarSpinner = DivoSegmentedSpinner()
    
    private let nameTextField: DivoTextField
    private let aboutEventTextField: DivoTextView
    
    
    // MARK: - Appearance UI
    
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
    
    private struct ProfileSnapshot: Equatable {
        let name: String
        let bio: String
        let genderId: String?
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

    private var initialSnapshot: ProfileSnapshot?
    private var avatarChanged = false

    private let hairLengthDropdown = FilterRowView(title: DivoStrings.hairLength)
    private let hairColorDropdown = FilterRowView(title: DivoStrings.hairColor)
    private let eyeColorDropdown = FilterRowView(title: DivoStrings.eyeColor)
    private let skinColorDropdown = FilterRowView(title: DivoStrings.skinColor)
    
    // MARK: - Footer UI
    
    private let applyButton = DivoButton()

    private var applyButtonBottomConstraint: NSLayoutConstraint?
    
    var currentPhoto: UIImage? = nil {
        didSet {
            avatarImageView.image = currentPhoto
            avatarImageView.applyAvatarTopCropIfNeeded(image: currentPhoto)
            if initialSnapshot != nil {
                avatarChanged = true
                updateSaveButtonState()
            }
        }
    }
    
    private var appearanceEditItems: [AppearanceEditItem] = []
    
    private let bottomFadeOverlay: UIView = {
        let view = GradientView()
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
    private var lastContainerSize: CGSize = .zero
    private var keyboardHandler: DivoKeyboardHandler?


    // MARK: - Init
    
    init(context: AccountContext, presentationData: PresentationData, model: UserDetail?, selectedIndex: Int = 0) {
        self.context = context
        self.model = model
        self.selectedIndex = selectedIndex
        
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
                
        var name = ""
        var placeholder = ""
        var bioTitle = ""
        var bio = ""
        if model?.role == "agency_employee" {
            name = model?.agency?.title ?? DivoStrings.name
            placeholder = "\(DivoStrings.agencyProfile) *"
            bioTitle = DivoStrings.descriptionTitle
            bio = model?.agency?.description ?? DivoStrings.fillInInfoAboutAgency
        } else {
            name = model?.fullName ?? DivoStrings.name
            placeholder = "\(DivoStrings.fullName) *"
            bioTitle = DivoStrings.biographyTitle
            bio = model?.model?.description ?? DivoStrings.fillInInfoAboutYou
        }
        
        self.nameTextField = DivoTextField(title: name, prefix: "")
        self.nameTextField.textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        self.nameTextField.isUserInteractionEnabled = true
        
        self.aboutEventTextField = DivoTextView(title: bioTitle, initialText: bio)

        super.init()
        
        self.backgroundColor = DivoColorPalette.screenBackground

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
        
        navigationBar.makeNavigationBar(
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            onBackTapped: { [weak self] in self?.onBackTapped?() }
        )

        applyButton.makeDivoButton(title: DivoStrings.save, loading: DivoStrings.saving)
        
        setupAppearanceEditItems()
    }
    
    override func didLoad() {
        super.didLoad()
        setupUI()

        updateDropdownsUI()
        setupInteractions()

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        dismissTap.delegate = self
        self.view.addGestureRecognizer(dismissTap)

        scrollView.keyboardDismissMode = .interactive

        self.nameTextField.textField.returnKeyType = .next
        self.nameTextField.textField.autocapitalizationType = .words
        self.nameTextField.textField.delegate = self

        keyboardHandler = DivoKeyboardHandler(
            scrollView: scrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 80,
            scrollToActiveField: { [weak self] in
                guard let self, self.aboutEventTextField.textView.isFirstResponder else { return }
                let frame = self.aboutEventTextField.convert(self.aboutEventTextField.bounds, to: self.scrollView)
                self.scrollView.scrollRectToVisible(frame, animated: false)
            }
        )
        keyboardHandler?.subscribe()

        loadAvatarIfNeeded()

        initialSnapshot = makeSnapshot()
        applyButton.isEnabled = false

        self.view.layoutIfNeeded()
        self.updatePagerHeight(animated: false)

        self.updateApplyButtonUI() 
        
        if self.model?.role != "agency_employee" {
            self.segmentedControl.setSelectedIndex(self.selectedIndex, animated: false)
            self.segmentedControl.setIndicatorProgress(CGFloat(self.selectedIndex))
            
            let stepSize = UIScreen.main.bounds.width
            let targetOffsetX = CGFloat(self.selectedIndex) * stepSize
            self.horizontalPager.setContentOffset(CGPoint(x: targetOffsetX, y: 0), animated: false)
        }
        
        self.readyValue = true
        
        updateAppearanceValues()
    }

    private func setupInteractions() {
        segmentedControl.onTabSelected = { [weak self] index in
            self?.view.endEditing(true)
            self?.setSelectedIndex(index, animated: true)
        }

        applyButton.addTarget(self, action: #selector(self.mainActionButtonPressed), for: .touchUpInside)

        chancePhotoView.addTarget(self, action: #selector(self.avatarTapped), for: .touchUpInside)

        nameTextField.textField.addTarget(self, action: #selector(nameFieldDidChange), for: .editingChanged)
        aboutEventTextField.onTextChange = { [weak self] _ in
            self?.updateSaveButtonState()
        }

        chancePhotoView.addDivoPressState(.pill)
    }
        
    private func getAppearanceId(for title: String?, in list: [AppearanceOption]?) -> Int {
        guard let title = title, let list = list else { return 1 }
        return list.first(where: { $0.title == title })?.id ?? 1
    }
    
    private func getGenderId(for title: String?, in list: [GenderOption]?) -> String {
        guard let title = title, let list = list else { return "other" }
        return list.first(where: { $0.title == title })?.id ?? "other"
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
    
    private func setupUI() {
        view.addSubview(navigationBar)
        view.addSubview(scrollView)
        scrollView.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            mainStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            mainStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        if model?.role != "agency_employee" {
            let segmentedControlView = UIView()
            segmentedControlView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(segmentedControlView)
            segmentedControlView.addSubview(segmentedControl)
            view.addSubview(searchFadeOverlay)

            NSLayoutConstraint.activate([
                segmentedControlView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: DivoDesignTokens.Spacing.l),
                segmentedControlView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                segmentedControlView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

                segmentedControl.heightAnchor.constraint(equalToConstant: 32),
                segmentedControl.leadingAnchor.constraint(equalTo: segmentedControlView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                segmentedControl.trailingAnchor.constraint(equalTo: segmentedControlView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                segmentedControl.topAnchor.constraint(equalTo: segmentedControlView.topAnchor),
                segmentedControl.bottomAnchor.constraint(equalTo: segmentedControlView.bottomAnchor),

                searchFadeOverlay.topAnchor.constraint(equalTo: segmentedControlView.bottomAnchor),
                searchFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                searchFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                searchFadeOverlay.heightAnchor.constraint(equalToConstant: 60),

                scrollView.topAnchor.constraint(equalTo: segmentedControlView.bottomAnchor)
            ])
            setupPager()
        } else {
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor).isActive = true
            setupAgencyPager()
        }

        scrollView.delegate = self
    }
    
    private func setupPager() {
        mainStackView.addArrangedSubview(horizontalPager)
        
        pagerHeightConstraint = horizontalPager.heightAnchor.constraint(equalToConstant: 300)
        pagerHeightConstraint.isActive = true
        
        let contentWidthView = UIView()
        contentWidthView.translatesAutoresizingMaskIntoConstraints = false
        horizontalPager.addSubview(contentWidthView)
        
        contentWidthView.addSubview(bioStackView)
        contentWidthView.addSubview(appearanceStackView)
        contentWidthView.addSubview(experienceStackView)
        
        NSLayoutConstraint.activate([
            contentWidthView.topAnchor.constraint(equalTo: horizontalPager.topAnchor),
            contentWidthView.bottomAnchor.constraint(equalTo: horizontalPager.bottomAnchor),
            contentWidthView.leadingAnchor.constraint(equalTo: horizontalPager.leadingAnchor),
            contentWidthView.trailingAnchor.constraint(equalTo: horizontalPager.trailingAnchor),
            contentWidthView.heightAnchor.constraint(equalTo: horizontalPager.heightAnchor),
            
            bioStackView.leadingAnchor.constraint(equalTo: contentWidthView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bioStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            bioStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),
            
            appearanceStackView.leadingAnchor.constraint(equalTo: bioStackView.trailingAnchor, constant: DivoDesignTokens.Spacing.xl),
            appearanceStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            appearanceStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),
            appearanceStackView.trailingAnchor.constraint(equalTo: experienceStackView.leadingAnchor, constant: -DivoDesignTokens.Spacing.xl),
            
            experienceStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            experienceStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),
            experienceStackView.trailingAnchor.constraint(equalTo: contentWidthView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
        
        setupBioContent()
        setupAppearanceContent()
        setupExperienceContent()
    }
    
    private func setupAgencyPager() {
        mainStackView.addArrangedSubview(horizontalPager)
        
        pagerHeightConstraint = horizontalPager.heightAnchor.constraint(equalToConstant: 300)
        pagerHeightConstraint.isActive = true
        
        let contentWidthView = UIView()
        contentWidthView.translatesAutoresizingMaskIntoConstraints = false
        horizontalPager.addSubview(contentWidthView)
        
        contentWidthView.addSubview(bioStackView)
        NSLayoutConstraint.activate([
            contentWidthView.topAnchor.constraint(equalTo: horizontalPager.topAnchor),
            contentWidthView.bottomAnchor.constraint(equalTo: horizontalPager.bottomAnchor),
            contentWidthView.leadingAnchor.constraint(equalTo: horizontalPager.leadingAnchor),
            contentWidthView.trailingAnchor.constraint(equalTo: horizontalPager.trailingAnchor),
            contentWidthView.heightAnchor.constraint(equalTo: horizontalPager.heightAnchor),

            bioStackView.leadingAnchor.constraint(equalTo: contentWidthView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bioStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            bioStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),
            bioStackView.trailingAnchor.constraint(equalTo: contentWidthView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m)
        ])
        
        setupBioContent()
    }
    
    private func setupBioContent() {
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(avatarImageSpinnerView)
        avatarContainer.addSubview(chancePhotoView)
        avatarSpinner.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarSpinner)
        avatarSpinner.isHidden = true

        
        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 120),
            
            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            avatarImageSpinnerView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageSpinnerView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageSpinnerView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageSpinnerView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            chancePhotoView.trailingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: DivoDesignTokens.Spacing.xs),
            chancePhotoView.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor),
            chancePhotoView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            chancePhotoView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            avatarSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            avatarSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
        ])
        
        bioStackView.addArrangedSubview(avatarContainer)
        avatarContainer.widthAnchor.constraint(equalTo: bioStackView.widthAnchor).isActive = true
        
        nameTextField.view.translatesAutoresizingMaskIntoConstraints = false
        aboutEventTextField.translatesAutoresizingMaskIntoConstraints = false
        
        bioStackView.addArrangedSubview(nameTextField.view)
        bioStackView.addArrangedSubview(aboutEventTextField)
        
        NSLayoutConstraint.activate([
            nameTextField.view.widthAnchor.constraint(equalTo: bioStackView.widthAnchor),
            nameTextField.view.heightAnchor.constraint(equalToConstant: 48),

            aboutEventTextField.widthAnchor.constraint(equalTo: bioStackView.widthAnchor),
            aboutEventTextField.heightAnchor.constraint(equalToConstant: 140)
        ])
        
        view.addSubview(bottomFadeOverlay)
        view.addSubview(applyButton)

        let buttonBottomCns = applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        self.applyButtonBottomConstraint = buttonBottomCns

        let bottomFadeOverlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.bottomFadeOverlayBottomConstraint = bottomFadeOverlayCns

        NSLayoutConstraint.activate([
            buttonBottomCns,
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            bottomFadeOverlayCns,
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: 160)
        ])
    }
    
    private func setupAppearanceContent() {
        genderDropdown.translatesAutoresizingMaskIntoConstraints = false
        appearanceStackView.addArrangedSubview(genderDropdown)

        appearanceStackView.addArrangedSubview(appearanceBackgroundView)
        appearanceBackgroundView.addSubview(appearanceContainerStack)

        NSLayoutConstraint.activate([
            appearanceBackgroundView.leadingAnchor.constraint(equalTo: appearanceStackView.leadingAnchor),
            appearanceBackgroundView.trailingAnchor.constraint(equalTo: appearanceStackView.trailingAnchor),
            
            appearanceContainerStack.topAnchor.constraint(equalTo: appearanceBackgroundView.topAnchor),
            appearanceContainerStack.leadingAnchor.constraint(equalTo: appearanceBackgroundView.leadingAnchor),
            appearanceContainerStack.trailingAnchor.constraint(equalTo: appearanceBackgroundView.trailingAnchor),
            appearanceContainerStack.bottomAnchor.constraint(equalTo: appearanceBackgroundView.bottomAnchor)
        ])
        
        appearanceStackView.addArrangedSubview(hairLengthDropdown)
        appearanceStackView.addArrangedSubview(hairColorDropdown)
        appearanceStackView.addArrangedSubview(eyeColorDropdown)
        appearanceStackView.addArrangedSubview(skinColorDropdown)

        genderDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(genderTapped)))
        hairLengthDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hairLengthTapped)))
        hairColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hairColorTapped)))
        eyeColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(eyeColorTapped)))
        skinColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skinColorTapped)))

        reloadAppearanceOptions()
    }
    
    private func setupExperienceContent() {
        let emptyContentStack = UIStackView(arrangedSubviews:[
            UIImageView(image: DivoImage.badgeBaseWork),
            workEmptyTitleLabel,
            workEmptySubTitleLabel
        ])
        emptyContentStack.axis = .vertical
        emptyContentStack.spacing = DivoDesignTokens.Spacing.m
        emptyContentStack.alignment = .center
        emptyContentStack.translatesAutoresizingMaskIntoConstraints = false
        
        workEmptyStateContainer.addSubview(emptyContentStack)
        
        experienceStackView.addArrangedSubview(workListBackgroundContainer)
        experienceStackView.addArrangedSubview(workEmptyStateContainer)
        
        workListBackgroundContainer.addSubview(workListStackView)
        
        workEmptyStateHeightConstraint = workEmptyStateContainer.heightAnchor.constraint(equalToConstant: 400)
        workEmptyStateHeightConstraint?.isActive = true
        
        NSLayoutConstraint.activate([
            workListBackgroundContainer.leadingAnchor.constraint(equalTo: experienceStackView.leadingAnchor),
            workListBackgroundContainer.trailingAnchor.constraint(equalTo: experienceStackView.trailingAnchor),
            workListBackgroundContainer.widthAnchor.constraint(equalTo: experienceStackView.widthAnchor),
            
            workListStackView.topAnchor.constraint(equalTo: workListBackgroundContainer.topAnchor),
            workListStackView.leadingAnchor.constraint(equalTo: workListBackgroundContainer.leadingAnchor),
            workListStackView.trailingAnchor.constraint(equalTo: workListBackgroundContainer.trailingAnchor),
            workListStackView.bottomAnchor.constraint(equalTo: workListBackgroundContainer.bottomAnchor),

            workEmptyStateContainer.leadingAnchor.constraint(equalTo: experienceStackView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            workEmptyStateContainer.trailingAnchor.constraint(equalTo: experienceStackView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            emptyContentStack.centerXAnchor.constraint(equalTo: workEmptyStateContainer.centerXAnchor),
            emptyContentStack.centerYAnchor.constraint(equalTo: workEmptyStateContainer.centerYAnchor),
            emptyContentStack.leadingAnchor.constraint(equalTo: workEmptyStateContainer.leadingAnchor, constant: 40),
            emptyContentStack.trailingAnchor.constraint(equalTo: workEmptyStateContainer.trailingAnchor, constant: -40)
        ])
        
        updateWorkEmptyState()
        renderWorkList()
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
    
    private func updateAppearanceValues() {
        for (index, item) in appearanceEditItems.enumerated() {
            if let cell = appearanceContainerStack.arrangedSubviews[safe: index] as? AppearanceFilterRowView {
                cell.setItems(item.getValues(), emptyTitle: DivoStrings.notSet)
            }
        }
    }
    
    private func calculateBirthdayString(from age: Int) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let birthYear = currentYear - age
        return "\(birthYear)-01-01"
    }

    private func loadAvatarIfNeeded() {
        guard let avatarURL = CDNURLHelper.convertToCDNURL(model?.avatar?.fullUrl) else { return }
        avatarSpinner.startAnimating()
        avatarSpinner.isHidden = false
        avatarImageView.alpha = 0.0
        avatarImageSpinnerView.isHidden = false
        ImageLoader.shared.load(url: avatarURL) { [weak self] image in
            guard let self else { return }
            self.avatarSpinner.stopAnimating()
            avatarSpinner.isHidden = true
            self.avatarImageView.alpha = 1.0
            if let image {
                self.avatarImageView.image = image
                avatarImageSpinnerView.isHidden = true
                self.avatarImageView.applyAvatarTopCropIfNeeded(image: image)
            }
        }
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
    
    private func updateDropdownsUI() {
        genderDropdown.setItems([selectedGenderTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
        hairLengthDropdown.setItems([selectedHairLengthTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
        hairColorDropdown.setItems([selectedHairColorTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
        eyeColorDropdown.setItems([selectedEyeColorTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
        skinColorDropdown.setItems([selectedSkinColorTitle ?? DivoStrings.notSet], emptyTitle: DivoStrings.notSet)
    }

    private func makeSnapshot() -> ProfileSnapshot {
        ProfileSnapshot(
            name: nameTextField.textField.text ?? "",
            bio: aboutEventTextField.text,
            genderId: selectedGenderId,
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

    private func updateSaveButtonState() {
        if selectedIndex == 2 {
            applyButton.makeDivoButton(title: DivoStrings.addWorkExperience)
            applyButton.isEnabled = true
        } else {
            applyButton.makeDivoButton(title: DivoStrings.save, loading: DivoStrings.saving)
            let hasChanges = makeSnapshot() != initialSnapshot || avatarChanged
            let trimmedName = (nameTextField.textField.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            applyButton.isEnabled = hasChanges && !trimmedName.isEmpty
        }
    }

    private func updateApplyButtonUI() {
        if selectedIndex == 2 {
            applyButton.setTitle(DivoStrings.addWorkExperience, for: .normal)
        } else {
            applyButton.setTitle(DivoStrings.save, for: .normal)
        }
        updateSaveButtonState()
    }

    private func renderWorkList() {
        workListStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        workExperienceCells.removeAll()
        
        if workIsLoading && workRawItems.isEmpty {
            for _ in 0..<workShimmerCount {
                let cell = ExperienceView()
                cell.configureAsShimmer()
                workListStackView.addArrangedSubview(cell)
            }
        } else {
            for (_, item) in workRawItems.enumerated() {
                let logoURL = item.agencyAvatarLink.flatMap { URL(string: $0) }

                let wItem = WorkExperienceItem(
                    id: item.id,
                    companyName: item.agencyDisplayName ?? item.agencyName ?? DivoStrings.unknownAgency,
                    period: item.formattedPeriod,
                    logoURL: logoURL
                )

                let cell = ExperienceView()

                let shouldLoadImmediately = logoURL != nil || item.agencyId == nil
                cell.configure(with: wItem, showOptions: true, loadImage: shouldLoadImmediately)
                
                cell.onEditTapped = { [weak self] in
                    self?.onEditWorkExperience?(item)
                }
                    
                cell.onDeleteTapped = { [weak self] in
                    self?.onDeleteWorkExperience?(item.id)
                }
                
                workExperienceCells[item.id] = cell
                
                workListStackView.addArrangedSubview(cell)
            }
        }
        
        workListBackgroundContainer.isHidden = (workIsLoading && workRawItems.isEmpty) ? false : workRawItems.isEmpty
    }

    private func updateWorkEmptyState() {
        experienceStackView.isHidden = false
        
        if workIsLoading {
            workEmptyStateContainer.isHidden = true
            workListBackgroundContainer.isHidden = false
        } else if workRawItems.isEmpty {
            workEmptyStateContainer.isHidden = false
            workListBackgroundContainer.isHidden = true
        } else {
            workEmptyStateContainer.isHidden = true
            workListBackgroundContainer.isHidden = false
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updatePagerHeight()
        }
    }
    
    func setAvatarLoading(_ loading: Bool) {
        if loading {
            avatarSpinner.startAnimating()
            avatarSpinner.isHidden = false
            avatarImageView.alpha = 0.0
            avatarImageSpinnerView.isHidden = false
        } else {
            avatarSpinner.stopAnimating()
            avatarSpinner.isHidden = true
            avatarImageView.alpha = 1.0
            avatarImageSpinnerView.isHidden = true
        }
    }

    func toggleSpinner(active: Bool) {
        applyButton.isUserInteractionEnabled = !active
    }

    func toggleSaving(active: Bool) {
        applyButton.setSaving(active, in: self.view)
    }
    
    func updateTitle(_ title: String) {
        navigationBar.setTitle(title)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let newSize = layout.size
        guard newSize != lastContainerSize else { return }
        lastContainerSize = newSize

        let usedHeight: CGFloat = 350
        let availableHeight = newSize.height - navigationBarHeight - usedHeight
        let dynamicHeight = max(availableHeight, 300)
        
        if workEmptyStateHeightConstraint?.constant != dynamicHeight {
            workEmptyStateHeightConstraint?.constant = dynamicHeight
        }

        self.view.layoutIfNeeded()
        self.updatePagerHeight(animated: false)
        
        if self.model?.role != "agency_employee" {
            self.segmentedControl.setIndicatorProgress(CGFloat(self.selectedIndex))
                
            let stepSize = newSize.width 
            let targetOffsetX = CGFloat(self.selectedIndex) * stepSize
                
            if self.horizontalPager.contentOffset.x != targetOffsetX {
                self.horizontalPager.setContentOffset(CGPoint(x: targetOffsetX, y: 0), animated: false)
            }
        }
    }

    func configureAppearanceDictionaries(_ dict: AppearanceDictionaryData) {
        self.appearanceDictionaries = dict

    }
    
    func configureGenderDictionaries(_ dict: GenderResponse) {
        self.genderDictionaries = dict
        
    }

    func setLoadingWorkExperience(_ loading: Bool) {
        self.workIsLoading = loading
        updateWorkEmptyState()
        renderWorkList()
    }
    
    func reloadWorkHistory(items: [WorkHistoryItem]) {
        self.workIsLoading = false
        self.workRawItems = items
        self.workHasStructuredData = true
        
        updateWorkEmptyState()
        renderWorkList()
    }
    
    func reloadLegacyWorkHistory(model: UserDetail) {
        self.workIsLoading = false
        self.workRawItems = []
        self.workHasStructuredData = false
        
        let experienceString = model.model?.workExperience ?? ""
        let experienceNames = experienceString
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        self.workRawItems = experienceNames.map { name in
            WorkHistoryItem(
                id: 0,
                agencyId: nil,
                agencyName: name,
                agencyDisplayName: name,
                agencyAvatarLink: nil,
                startDate: nil,
                endDate: nil,
                isCurrent: false
            )
        }
        
        updateWorkEmptyState()
        renderWorkList()
    }

    @objc private func appearanceCellTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < appearanceEditItems.count else { return }
        appearanceEditItems[view.tag].onTap()
    }
    
    @objc private func nameFieldDidChange() {
        updateSaveButtonState()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func avatarTapped() {
        divoLog("[EDIT PROFILE] Change photo tapped")
        self.view.endEditing(true)
        onAvatarTap?()
    }
    
    @objc private func updateAccountPeerName() {
        divoLog("[EDIT PROFILE] Save button tapped")
    }
    
    @objc private func saveButtonPressed() {
        self.view.endEditing(true)

        let trimmedName = (self.nameTextField.textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let data = UpdateBiographyPageRequest(
            fullName: trimmedName,
            gender: self.selectedGenderId,
            model: UpdateBiographyPageRequest.ModelData(
                description: self.aboutEventTextField.text,
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

    @objc private func mainActionButtonPressed() {
        self.view.endEditing(true)
        
        if selectedIndex == 2 {
            workAddExperienceButtonTapped()
        } else {
            if model?.role == "agency_employee" {
                saveAgencyButtonPressed()
            } else {
                saveButtonPressed()
            }
        }
    }

    @objc private func saveAgencyButtonPressed() {
        self.view.endEditing(true)

        let trimmedTitle = (self.nameTextField.textField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let data = UpdateDescriptionAgencyRequest(
            agencyId: model?.agency?.id,
            title: trimmedTitle,
            description: self.aboutEventTextField.text
        )

        self.toggleSaving(active: true)
        self.saveAgencyProfile?(data)
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
    
    @objc private func workAddExperienceButtonTapped() {
        onAddWorkExperience?()
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


// UITextFieldDelegate
extension EditProfileNode: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderWidth = 1.0
        textField.layer.borderColor = DivoColorPalette.accent.cgColor
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderWidth = 0.0
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === nameTextField.textField {
            aboutEventTextField.textView.becomeFirstResponder()
        }
        return false
    }

    private func setSelectedIndex(_ index: Int, animated: Bool) {
        guard selectedIndex != index else { return }
        selectedIndex = index
        updateApplyButtonUI() 
        self.updatePagerHeight(animated: animated)
        segmentedControl.setSelectedIndex(index, animated: animated)

        let offsetX = CGFloat(index) * horizontalPager.bounds.width

        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options:[.curveEaseInOut, .allowUserInteraction], animations: {
                self.horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
            })
        } else {
            horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
        }
    }
        
    private func updatePagerHeight(animated: Bool = true) {
        bioStackView.layoutIfNeeded()
        appearanceStackView.layoutIfNeeded()
        experienceStackView.layoutIfNeeded()

        let bioHeight = bioStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        let appHeight = appearanceStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        let experienceHeight = experienceStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height

        var targetHeight = 0.0
        if selectedIndex == 0 {
            targetHeight = bioHeight
        } else if selectedIndex == 1 {
            targetHeight = appHeight
        } else if selectedIndex == 2 {
            targetHeight = experienceHeight
        }

        guard pagerHeightConstraint.constant != targetHeight else { return }
        pagerHeightConstraint.constant = targetHeight
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.view.layoutIfNeeded()
            }
        } else {
            self.view.layoutIfNeeded()
        }
    }
    
}

// UIScrollViewDelegate
extension EditProfileNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager, scrollView.bounds.width > 0 else { return }

        let progress = scrollView.contentOffset.x / scrollView.bounds.width
        segmentedControl.setIndicatorProgress(progress)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager else { return }

        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        if selectedIndex != page {
            selectedIndex = page
            self.updatePagerHeight(animated: true)
            segmentedControl.setSelectedIndex(page, animated: false)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension EditProfileNode: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        return true
    }
}

// MARK: - GradientView

private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}
