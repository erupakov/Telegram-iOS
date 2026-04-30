import Display
import UIKit
import AsyncDisplayKit
import UIKit
import TelegramCore
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
import Postbox
import ChatScheduleTimeController
import DivoUIKit

enum EventParameter: String, CaseIterable {
    case gender = "gender"
    case age = "age"
    case height = "height"
    case weight = "weight"
    case breast = "breast"
    case waist = "waist"
    case hips = "hips"
    case shoeSize = "shoeSize"
    case hairLength = "hairLength"
    case hairColor = "hairColor"
    case eyeColor = "eyeColor"
    case skinColor = "skinColor"

    var localizedTitle: String {
        switch self {
        case .gender: return DivoStrings.paramGender
        case .age: return DivoStrings.paramAge
        case .height: return DivoStrings.paramHeight
        case .weight: return DivoStrings.paramWeight
        case .breast: return DivoStrings.paramBreast
        case .waist: return DivoStrings.paramWaist
        case .hips: return DivoStrings.paramHips
        case .shoeSize: return DivoStrings.paramShoeSize
        case .hairLength: return DivoStrings.paramHairLength
        case .hairColor: return DivoStrings.paramHairColor
        case .eyeColor: return DivoStrings.paramEyeColor
        case .skinColor: return DivoStrings.paramSkinColor
        }
    }
}

private struct AppearanceEditItem {
    let title: String
    let getValues: () -> [String]
    let emptyTitle: String
    let onTap: () -> Void
}

// MARK: - CreateEventNode
final class CreateEventNode: ASDisplayNode {

    // MARK: - Core & Context
    private(set) var eventDateInt: Int32 = 0
    private(set) var eventTimeInt: Int32 = 0
    
    private(set) var deadlineDateInt: Int32 = 0
    private(set) var deadlineTimeInt: Int32 = 0
    
    // MARK: - Step Management
    private var currentStep: Int = 1
    
    // MARK: - Navigation Bar (Header)
    private let navigationBar = DivoNavigationBar()

    // MARK: - Layout Views (Paging)
    private let horizontalPager: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.isScrollEnabled = false
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let pagerContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let step1ScrollView = UIScrollView()
    private let step2ScrollView = UIScrollView()
    private let step3ScrollView = UIScrollView()
    
    private let step1StackView = UIStackView()
    private let step2StackView = UIStackView()
    private let step3StackView = UIStackView()

    // MARK: - Global Action Button
    private let applyButton = DivoButton()
    private var applyButtonBottomConstraint: NSLayoutConstraint!
    
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
    private var keyboardScroll1Handler: DivoKeyboardHandler?
    private var keyboardScroll2Handler: DivoKeyboardHandler?

    // MARK: - Step 1 UI
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.layer.borderColor = DivoColorPalette.accent.cgColor
        iv.layer.borderWidth = 1.0
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let avatarImageSpinnerView: UIView = {
        let iv = UIView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.backgroundColor = .clear
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
        button.isHidden = true
        return button
    }()
    
    private let chanceCenterPhotoView: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = DivoImage.addMediaProfile
        button.setImage(image, for: .normal)
        button.setImage(image, for: .highlighted)
        button.tintColor = DivoColorPalette.accent
        button.layer.masksToBounds = true
        let padding: CGFloat = 4
        button.imageEdgeInsets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private let avatarSpinner = DivoSegmentedSpinner()
    
    private var eventTypeDropdown = FilterRowView(title: DivoStrings.eventType)
    private var eventTypeItems: [AgencyItem] = []
    private var eventTypeId: String?
    private var eventTypeTitle: String?

    private let nameEventTextField: DivoTextField
    private let aboutEventTextField: DivoTextView
    
    private let eventDate: DateSelectionControl
    private let eventTime: DateSelectionControl

    private let countryRow = FilterRowView(title: DivoStrings.debugCountry)
    lazy var countryOptions: [FilterOptionItem] = {
        var options: [FilterOptionItem] = []
        options.append(contentsOf: CountryHelper.getAllCountries())
        return options
    }()

    // MARK: - Step 2 UI
    private let whoCanApplyDropdown = FilterRowView(title: DivoStrings.whoCanApply)
    private var whoCanApplyIds: [String]?
    private var whoCanApplyTitles: [String]?
    var roleOptions: [FilterOptionItem] = [
        FilterOptionItem(id: "all", title: DivoStrings.feedSearchAllRoles),
        FilterOptionItem(id: "model", title: DivoStrings.debugModel),
        FilterOptionItem(id: "new_face", title: DivoStrings.debugNewTalent),
        FilterOptionItem(id: "agency_employee", title: DivoStrings.debugAgency)
    ]
    
    private let maxParticipantsDropdown = FilterRowView(title: DivoStrings.maxParticipants)
    private var maxParticipants: Int?
    
    private let requirementsTextField: DivoTextView
    
    private let parametersForApplying: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.font = Font.regular(14)
        label.text = DivoStrings.parametersForApplying
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
        
    }()
    private var addParamsWidthConstraint: NSLayoutConstraint?
    
    private let ndaSwitch: UISwitch = UISwitch()
    
    private let appearanceBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let dynamicParametersStack: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    private var appearanceEditItems: [AppearanceEditItem] = []
    
    private let eventGalleryLabel = UILabel()
    var galleryItems: [EventGalleryItem] = []
    
    private let galleryLabel: UILabel = {
        let label = UILabel()
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.font = Font.regular(14)
        label.text = DivoStrings.galleryCreateEvent
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
        
    }()
    
    private let galleryAddButton: DivoButton = {
        let button = DivoButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var galleryHeightConstraint: NSLayoutConstraint!
    
    private let galleryCollectionContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var galleryCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.isScrollEnabled = false
        collection.delaysContentTouches = false
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.register(EventGalleryCell.self, forCellWithReuseIdentifier: "EventGalleryCell")
        return collection
    }()

    // MARK: - Step 3 UI
    private let deadlineDate: DateSelectionControl
    private let deadlineTime: DateSelectionControl
    
    private let paidEventSwitch: UISwitch = UISwitch()
    
    private let rateFieldContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 23
        view.layer.masksToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let rateTextField: UITextField = {
        let field = UITextField()
        field.font = Font.regular(16)
        field.textColor = DivoColorPalette.primaryText
        field.tintColor = DivoColorPalette.accent
        field.placeholder = "100"
        field.clearButtonMode = .never
        field.autocorrectionType = .no
        field.keyboardType = .numberPad
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private let rateIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = DivoImage.paid
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var rateTime = FilterRowView()
    private var rateTimeId: String?
    private var rateTimeTitle: String = "per hour"
    var rateTimeOptions: [FilterOptionItem] = [
        FilterOptionItem(id: "1", title: "per hour"),
        FilterOptionItem(id: "2", title: "per day"),
        FilterOptionItem(id: "3", title: "per month"),
        FilterOptionItem(id: "4", title: "per project")
    ]
    
    private let publicEventSwitch: UISwitch = UISwitch()

    // MARK: - Parameters Data
    private var selectedParameters: Set<EventParameter> = []
    private var deleteButtons: [EventParameter: ASButtonNode] = [:]
    
    private var genderDropdown = FilterRowView(title: DivoStrings.paramGender)
    private var genderDropdownIds: [String]?
    private var genderDropdownTitles: [String]?
    var genderOptions: [FilterOptionItem] = []
    
    private var selectedAge: ClosedRange<Int>?
    private var selectedHeight: ClosedRange<Double>?
    private var selectedWeight: ClosedRange<Double>?
    private var selectedWaist: ClosedRange<Double>?
    private var selectedHips: ClosedRange<Double>?
    private var selectedShoeSize: ClosedRange<Double>?
    
    private var hairLengthDropdown = FilterRowView(title: DivoStrings.paramHairLength)
    private var hairLengthDropdownIds: [String]?
    private var hairLengthDropdownTitles: [String]?
    var hairLengthOptions: [FilterOptionItem] = []
    
    private var hairColorDropdown = FilterRowView(title: DivoStrings.paramHairColor)
    private var hairColorDropdownIds: [String]?
    private var hairColorDropdownTitles: [String]?
    var hairColorOptions: [FilterOptionItem] = []
    
    private var eyeColorDropdown = FilterRowView(title: DivoStrings.paramEyeColor)
    private var eyeColorDropdownIds: [String]?
    private var eyeColorDropdownTitles: [String]?
    var eyeColorOptions: [FilterOptionItem] = []
    
    private var skinColorDropdown = FilterRowView(title: DivoStrings.paramSkinColor)
    private var skinColorDropdownIds: [String]?
    private var skinColorDropdownTitles: [String]?
    var skinColorOptions: [FilterOptionItem] = []
    
    private var appearanceDictionaries: AppearanceDictionaryData?
    private var genderDictionaries: GenderResponse?

    // MARK: - Callbacks
    var onCreateEventTapped: (() -> Void)?
    private let addPhoto: () -> Void
    var selectCountryCode: (() -> Void)?
    var scheduleTimeController: ((TimeControllerMode) -> Void)?
    var scheduleDeadlineTimeController: ((TimeControllerMode) -> Void)?
    var showAlert: ((String) -> Void)?
    var onAddGalleryPhotoTapped: (() -> Void)?
    var loadEventTypesList: ((Int, Int) -> Void)?
    var onBackTapped: (() -> Void)?
    var onAvatarTap: (() -> Void)?
    var presentController: ((UIViewController) -> Void)?

    private var countryId: String?
    private var countryTitle: String?

    private var selectedEventTypeId: Int?
    private var eventTypeOffset: Int = 0
    private var eventTypeLimit: Int = 20
    private var isLoadingEventTypes: Bool = false
    private var hasMoreEventTypes: Bool = true
    
    var avatarFileUuid: String? = nil
    var isAvatarUploading: Bool = false
    
    var currentPhoto: UIImage? = nil {
        didSet {
            avatarImageView.layer.borderColor = DivoColorPalette.cardBackground.cgColor
            avatarImageView.image = currentPhoto
            avatarImageView.applyAvatarTopCropIfNeeded(image: currentPhoto)
            chanceCenterPhotoView.isHidden = currentPhoto != nil
            chancePhotoView.isHidden = currentPhoto == nil
        }
    }

    private var currentLayoutData: (ContainerViewLayout, CGFloat, CGFloat)?

    private let loadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private let loadingSpinner = DivoSegmentedSpinner()
    

    // MARK: - Init

    init(addPhoto: @escaping () -> Void) {
        self.addPhoto = addPhoto
        
        self.nameEventTextField = DivoTextField(title: "", prefix: "")
        self.nameEventTextField.textField.attributedPlaceholder = NSAttributedString(
            string: DivoStrings.eventName,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        self.nameEventTextField.isUserInteractionEnabled = true

        self.aboutEventTextField = DivoTextView(title: DivoStrings.descriptionCreateEvent, initialText: "", placeholder: DivoStrings.placeholderDescriptionCreateEvent)
        self.aboutEventTextField.textView.text = DivoStrings.placeholderDescriptionCreateEvent
        self.aboutEventTextField.textView.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.4)
                
        eventDate = DateSelectionControl(placeholder: Int32(Date().timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier, isTime: false)

        eventTime = DateSelectionControl(placeholder: Int32(Date().timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier, isTime: true)
 
        self.requirementsTextField = DivoTextView(title: DivoStrings.requirementsCreateEvent, initialText: "", placeholder: DivoStrings.placeholderRequirementsCreateEvent)
        self.requirementsTextField.textView.text = DivoStrings.placeholderRequirementsCreateEvent
        self.requirementsTextField.textView.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.4)

        deadlineDate = DateSelectionControl(placeholder: Int32(Date().timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier, isTime: false)

        deadlineTime = DateSelectionControl(placeholder: Int32(Date().timeIntervalSince1970), localeIdentifier: DivoStrings.current.localeIdentifier, isTime: true)
        
        super.init()
        
        navigationBar.makeNavigationBar(
            title: DivoStrings.createEvent.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            rightButtonConfiguration: .onlyText(DivoStrings.stepCreateEvent(currentStep)),
            onBackTapped: { [weak self] in self?.backButtonTapped() }
        )

        self.nameEventTextField.textField.delegate = self
        self.rateTextField.delegate = self
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didLoad() {
        super.didLoad()

        self.backgroundColor = DivoColorPalette.screenBackground

        applyButton.makeDivoButton(title: DivoStrings.continueButton)
        applyButton.addTarget(self, action: #selector(mainActionButtonTapped), for: .touchUpInside)
        
        chancePhotoView.addTarget(self, action: #selector(self.avatarTapped), for: .touchUpInside)
        chancePhotoView.addDivoPressState(.pill)
        chanceCenterPhotoView.addTarget(self, action: #selector(self.avatarTapped), for: .touchUpInside)
        chanceCenterPhotoView.addDivoPressState(.pill)
        
        eventDate.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleTimeController?(.date)
        }
                
        eventTime.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleTimeController?(.time)
        }
        
        deadlineDate.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleDeadlineTimeController?(.date)
        }
                
        deadlineTime.onTap = { [weak self] in
            self?.view.endEditing(true)
            self?.scheduleDeadlineTimeController?(.time)
        }
        
        galleryAddButton.makeDivoButton(title: DivoStrings.addPhotoEvent, buttonFont: Font.helveticaNeue(16), radius: 20)
        
        galleryAddButton.setImage(DivoImage.addPhotoIcon.withRenderingMode(.alwaysTemplate), for: .normal)
        galleryAddButton.setImage(DivoImage.addPhotoIcon.withRenderingMode(.alwaysTemplate), for: .highlighted)
        galleryAddButton.tintColor = DivoColorPalette.primaryTextOnDark
        galleryAddButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -DivoDesignTokens.Spacing.xs, bottom: 0, right: DivoDesignTokens.Spacing.xs)
        
        galleryAddButton.addTarget(self, action: #selector(dashedUploadTapped), for: .touchUpInside)
        
        galleryCollectionView.delegate = self
        galleryCollectionView.dataSource = self

        setupAppearanceEditItems()
        setupLayout()
        updateHeaderAndButton()
        
        self.nameEventTextField.textField.returnKeyType = .next
        self.nameEventTextField.textField.delegate = self
        
        keyboardScroll1Handler = DivoKeyboardHandler(
            scrollView: step1ScrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 80,
            scrollToActiveField: { [weak self] in
                guard let self, self.aboutEventTextField.textView.isFirstResponder else { return }
                let frame = self.aboutEventTextField.convert(self.aboutEventTextField.bounds, to: self.step1ScrollView)
                self.step1ScrollView.scrollRectToVisible(frame, animated: false)
            }
        )
        keyboardScroll1Handler?.subscribe()
        
        keyboardScroll2Handler = DivoKeyboardHandler(
            scrollView: step2ScrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 80,
            scrollToActiveField: { [weak self] in
                guard let self, self.requirementsTextField.textView.isFirstResponder else { return }
                let frame = self.requirementsTextField.convert(self.requirementsTextField.bounds, to: self.step2ScrollView)
                self.step2ScrollView.scrollRectToVisible(frame, animated: false)
            }
        )
        keyboardScroll2Handler?.subscribe()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGesture)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        self.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                
        updateDropdownsUI()
        
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }

    // MARK: - Auto Layout Configurations
    
    private func setupLayout() {
        // 1. Header Navigation
        view.addSubview(navigationBar)
        
        // 2. Horizontal Pager
        view.addSubview(horizontalPager)
        horizontalPager.addSubview(pagerContentView)
        
        // 3. Global Button
        view.addSubview(bottomFadeOverlay)
        let bottomFadeOverlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        bottomFadeOverlayBottomConstraint = bottomFadeOverlayCns
        
        view.addSubview(applyButton)
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButtonBottomConstraint = applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            horizontalPager.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            horizontalPager.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            horizontalPager.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            horizontalPager.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            pagerContentView.topAnchor.constraint(equalTo: horizontalPager.contentLayoutGuide.topAnchor),
            pagerContentView.bottomAnchor.constraint(equalTo: horizontalPager.contentLayoutGuide.bottomAnchor),
            pagerContentView.leadingAnchor.constraint(equalTo: horizontalPager.contentLayoutGuide.leadingAnchor),
            pagerContentView.trailingAnchor.constraint(equalTo: horizontalPager.contentLayoutGuide.trailingAnchor),
            pagerContentView.heightAnchor.constraint(equalTo: horizontalPager.frameLayoutGuide.heightAnchor),
            
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            applyButton.heightAnchor.constraint(equalToConstant: 56),
            applyButtonBottomConstraint,
            
            bottomFadeOverlayCns,
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: 140)
        ])
        
        setupSteps()

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
    
    private func setupSteps() {
        let scrolls = [step1ScrollView, step2ScrollView, step3ScrollView]
        let stacks = [step1StackView, step2StackView, step3StackView]
        
        for (index, scrollView) in scrolls.enumerated() {
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.keyboardDismissMode = .onDrag
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
            
            let stack = stacks[index]
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.axis = .vertical
            stack.spacing = DivoDesignTokens.Spacing.m
            stack.layoutMargins = UIEdgeInsets(top: 20, left: DivoDesignTokens.Spacing.m, bottom: 0, right: DivoDesignTokens.Spacing.m)
            stack.isLayoutMarginsRelativeArrangement = true
            
            pagerContentView.addSubview(scrollView)
            scrollView.addSubview(stack)
            
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: pagerContentView.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: pagerContentView.bottomAnchor),
                scrollView.widthAnchor.constraint(equalTo: self.view.widthAnchor),
                
                stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
            ])
            
            if index == 0 {
                scrollView.leadingAnchor.constraint(equalTo: pagerContentView.leadingAnchor).isActive = true
            } else {
                scrollView.leadingAnchor.constraint(equalTo: scrolls[index - 1].trailingAnchor).isActive = true
            }
            if index == scrolls.count - 1 {
                scrollView.trailingAnchor.constraint(equalTo: pagerContentView.trailingAnchor).isActive = true
            }
        }
        
        buildStep1()
        buildStep2()
        buildStep3()
    }
    
    private func buildStep1() {
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(avatarImageSpinnerView)
        avatarContainer.addSubview(chancePhotoView)
        avatarContainer.addSubview(chanceCenterPhotoView)
        avatarSpinner.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarSpinner)
        avatarSpinner.isHidden = true

        
        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 120),
            
            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),

            avatarImageSpinnerView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageSpinnerView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageSpinnerView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageSpinnerView.heightAnchor.constraint(equalToConstant: 100),

            chancePhotoView.trailingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: DivoDesignTokens.Spacing.xs),
            chancePhotoView.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor),
            chancePhotoView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            chancePhotoView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            chanceCenterPhotoView.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            chanceCenterPhotoView.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            chanceCenterPhotoView.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            chanceCenterPhotoView.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            avatarSpinner.widthAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
            avatarSpinner.heightAnchor.constraint(equalToConstant: DivoDesignTokens.Spacing.xl),
        ])
        
        step1StackView.addArrangedSubview(avatarContainer)
        step1StackView.addArrangedSubview(eventTypeDropdown)
        eventTypeDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(eventTypeTapped)))

        step1StackView.addArrangedSubview(nameEventTextField.view)
        nameEventTextField.view.heightAnchor.constraint(equalToConstant: 48).isActive = true
        step1StackView.addArrangedSubview(aboutEventTextField)
        aboutEventTextField.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        let dateTimeRow = UIStackView()
        dateTimeRow.axis = .horizontal
        dateTimeRow.spacing = 12
        dateTimeRow.distribution = .fillEqually
        
        dateTimeRow.addArrangedSubview(makeInputStack(title: DivoStrings.eventDate, inputView: eventDate))
        dateTimeRow.addArrangedSubview(makeInputStack(title: DivoStrings.eventTime, inputView: eventTime))
        step1StackView.addArrangedSubview(dateTimeRow)
        dateTimeRow.heightAnchor.constraint(equalToConstant: 68).isActive = true
        
        step1StackView.addArrangedSubview(countryRow)
        countryRow.heightAnchor.constraint(equalToConstant: 48).isActive = true
        countryRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(countryTapped)))
    }
    
    private func buildStep2() {

        step2StackView.addArrangedSubview(whoCanApplyDropdown)
        whoCanApplyDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(roleTapped)))
                
        step2StackView.addArrangedSubview(maxParticipantsDropdown)
        maxParticipantsDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(maxParticipantsTapped)))
        
        step2StackView.addArrangedSubview(requirementsTextField)
        requirementsTextField.heightAnchor.constraint(equalToConstant: 140).isActive = true
        
        step2StackView.addArrangedSubview(parametersForApplying)
        step2StackView.addArrangedSubview(genderDropdown)
        genderDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(genderDropdownTapped)))
                
        step2StackView.addArrangedSubview(appearanceBackgroundView)
        appearanceBackgroundView.addSubview(dynamicParametersStack)
        
        NSLayoutConstraint.activate([
            dynamicParametersStack.topAnchor.constraint(equalTo: appearanceBackgroundView.topAnchor),
            dynamicParametersStack.leadingAnchor.constraint(equalTo: appearanceBackgroundView.leadingAnchor),
            dynamicParametersStack.trailingAnchor.constraint(equalTo: appearanceBackgroundView.trailingAnchor),
            dynamicParametersStack.bottomAnchor.constraint(equalTo: appearanceBackgroundView.bottomAnchor)
        ])
        
        reloadAppearanceOptions()
        
        step2StackView.addArrangedSubview(hairLengthDropdown)
        hairLengthDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hairLengthDropdownTapped)))
        step2StackView.addArrangedSubview(hairColorDropdown)
        hairColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hairColorDropdownTapped)))
        step2StackView.addArrangedSubview(eyeColorDropdown)
        eyeColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(eyeColorDropdownTapped)))
        step2StackView.addArrangedSubview(skinColorDropdown)
        skinColorDropdown.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skinColorDropdownTapped)))
        
        step2StackView.addArrangedSubview(makeSwitchRow(title: DivoStrings.ndaRequiredCreateEvent, uiSwitch: ndaSwitch))
                
        eventGalleryLabel.translatesAutoresizingMaskIntoConstraints = false
        step2StackView.addArrangedSubview(eventGalleryLabel)
        
        let stackGallery = UIStackView()
        stackGallery.axis = .horizontal
        stackGallery.translatesAutoresizingMaskIntoConstraints = false
        
        stackGallery.addArrangedSubview(galleryLabel)
        stackGallery.addArrangedSubview(UIView())
        stackGallery.addArrangedSubview(galleryAddButton)
        stackGallery.heightAnchor.constraint(equalToConstant: 40).isActive = true

        step2StackView.addArrangedSubview(stackGallery)

        galleryCollectionContainerView.addSubview(galleryCollectionView)
        
        NSLayoutConstraint.activate([
            galleryCollectionView.topAnchor.constraint(equalTo: galleryCollectionContainerView.topAnchor),
            galleryCollectionView.leadingAnchor.constraint(equalTo: galleryCollectionContainerView.leadingAnchor),
            galleryCollectionView.trailingAnchor.constraint(equalTo: galleryCollectionContainerView.trailingAnchor),
            galleryCollectionView.bottomAnchor.constraint(equalTo: galleryCollectionContainerView.bottomAnchor)
        ])
        
        step2StackView.addArrangedSubview(galleryCollectionContainerView)
        galleryHeightConstraint = galleryCollectionContainerView.heightAnchor.constraint(equalToConstant: 0)
        galleryHeightConstraint.isActive = true
    }
    
    private func buildStep3() {
        let dateTimeRow = UIStackView()
        dateTimeRow.axis = .horizontal
        dateTimeRow.spacing = 12
        dateTimeRow.distribution = .fillEqually
        
        dateTimeRow.addArrangedSubview(makeInputStack(title: DivoStrings.deadlineDate, inputView: deadlineDate))
        dateTimeRow.addArrangedSubview(makeInputStack(title: DivoStrings.deadlineTime, inputView: deadlineTime))
        step3StackView.addArrangedSubview(dateTimeRow)
        dateTimeRow.heightAnchor.constraint(equalToConstant: 68).isActive = true
        
        step3StackView.addArrangedSubview(makeSwitchRow(title: DivoStrings.paidEvent, uiSwitch: paidEventSwitch))
        
        let rateTimeRow = UIStackView()
        rateTimeRow.axis = .horizontal
        rateTimeRow.spacing = 12
        rateTimeRow.distribution = .fillEqually
        
        rateFieldContainer.addSubview(rateTextField)
        rateFieldContainer.addSubview(rateIcon)
        
        NSLayoutConstraint.activate([
            rateFieldContainer.heightAnchor.constraint(equalToConstant: 46),
            
            rateTextField.leadingAnchor.constraint(equalTo: rateFieldContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            rateTextField.topAnchor.constraint(equalTo: rateFieldContainer.topAnchor),
            rateTextField.bottomAnchor.constraint(equalTo: rateFieldContainer.bottomAnchor),
            
            rateIcon.leadingAnchor.constraint(equalTo: rateTextField.trailingAnchor, constant: DivoDesignTokens.Spacing.xs),
            rateIcon.trailingAnchor.constraint(equalTo: rateFieldContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            rateIcon.centerYAnchor.constraint(equalTo: rateTextField.centerYAnchor),
            rateIcon.widthAnchor.constraint(equalToConstant: 20),
            rateIcon.heightAnchor.constraint(equalToConstant: 20),
        ])
        
        rateTime.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rateTimeTapped)))
        
        rateTimeRow.addArrangedSubview(rateFieldContainer)
        rateTimeRow.addArrangedSubview(rateTime)
        rateTimeRow.heightAnchor.constraint(equalToConstant: 46).isActive = true
        
        step3StackView.addArrangedSubview(makeInputStack(title: DivoStrings.rate, inputView: rateTimeRow))
        
        step3StackView.addArrangedSubview(makeSwitchRow(title: DivoStrings.publicEvent, subtitle: DivoStrings.visibleAllUsers, uiSwitch: publicEventSwitch))
    }
    
    private func reloadAppearanceOptions() {
        dynamicParametersStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (index, item) in appearanceEditItems.enumerated() {
            let isLast = index == appearanceEditItems.count - 1
            let cell = AppearanceFilterRowView(title: item.title, isLast: isLast)
            cell.setItems(item.getValues(), emptyTitle: DivoStrings.notSet)
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(appearanceCellTapped(_:)))
            cell.addGestureRecognizer(tap)
            cell.tag = index
            dynamicParametersStack.addArrangedSubview(cell)
        }
    }
    
    private func setupAppearanceEditItems() {
        appearanceEditItems = [
            AppearanceEditItem(
                title: DivoStrings.ageYo,
                getValues: { [weak self] in
                    guard let range = self?.selectedAge else { return [] }
                    return["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.ageYo,
                        currentRange: self?.selectedAge,
                        min: 16,
                        max: 70,
                        onUpdate: { newRange in
                            self?.selectedAge = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.heightCm,
                getValues: { [weak self] in
                    guard let range = self?.selectedHeight else { return [] }
                    return["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.heightCm,
                        currentRange: self?.selectedHeight,
                        min: 100,
                        max: 250,
                        onUpdate: { newRange in
                            self?.selectedHeight = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.weightKg,
                getValues: { [weak self] in
                    guard let range = self?.selectedWeight else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.weightKg,
                        currentRange: self?.selectedWeight,
                        min: 40,
                        max: 120,
                        onUpdate: { newRange in
                            self?.selectedWeight = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.waistCm,
                getValues: { [weak self] in
                    guard let range = self?.selectedWaist else { return [] }
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.waistCm,
                        currentRange: self?.selectedWaist,
                        min: 50,
                        max: 120,
                        onUpdate: { newRange in
                            self?.selectedWaist = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.hipsCm,
                getValues: { [weak self] in
                    guard let range = self?.selectedHips else { return []}
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.hipsCm,
                        currentRange: self?.selectedHips,
                        min: 70,
                        max: 130,
                        onUpdate: { newRange in
                            self?.selectedHips = newRange
                        }
                    )
                }
            ),
            AppearanceEditItem(
                title: DivoStrings.shoeSizeEU,
                getValues: { [weak self] in
                    guard let range = self?.selectedShoeSize else { return []}
                    return ["\(Int(range.lowerBound))-\(Int(range.upperBound))"]
                },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showRangeFilter(
                        title: DivoStrings.shoeSizeEU,
                        currentRange: self?.selectedShoeSize,
                        min: 25,
                        max: 38,
                        onUpdate: { newRange in
                            self?.selectedShoeSize = newRange
                        }
                    )
                }
            ),
        ]
    }
    
    private func showRangeFilter<T>(
        title: String,
        currentRange: ClosedRange<T>?,
        min: T,
        max: T,
        onUpdate: @escaping (ClosedRange<T>?) -> Void
    ) where T: RangeFilterable {

        self.view.endEditing(true)

        var currentMin: Double? = nil
        var currentMax: Double? = nil

        if let currentRange = currentRange {
            currentMin = currentRange.lowerBound.doubleValue
            currentMax = currentRange.upperBound.doubleValue
        }

        let vc = RangeFilterController(
            title: title,
            min: min.doubleValue,
            max: max.doubleValue,
            currentLower: currentMin,
            currentUpper: currentMax,
            isOpenPresent: true,
            isResetButton: false
        )

        vc.onSave = { [weak self] firstValue, secondValue in
            guard let self = self else { return }
            
            if let firstValue = firstValue, let secondValue = secondValue {
                let newClosedRange = T(firstValue)...T(secondValue)
                onUpdate(newClosedRange)
            } else {
                onUpdate(nil)
            }
            
            self.updateAppearanceValues()
        }
        
        presentSheet(vc)
    }
    
    private func updateAppearanceValues() {
        for (index, item) in appearanceEditItems.enumerated() {
            if index < dynamicParametersStack.arrangedSubviews.count,
               let cell = dynamicParametersStack.arrangedSubviews[index] as? AppearanceFilterRowView {
                cell.setItems(item.getValues(), emptyTitle: DivoStrings.notSet)
            }
        }
    }
    
    private func scrollToCurrentStep() {
        updateHeaderAndButton()
        let offsetX = CGFloat(currentStep - 1) * self.view.bounds.width
        horizontalPager.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
    }
    
    private func updateHeaderAndButton() {
        navigationBar.setRightTitle(DivoStrings.stepCreateEvent(currentStep))
        if currentStep == 3 {
            applyButton.makeDivoButton(title: DivoStrings.previewEvent)
        } else {
            applyButton.makeDivoButton(title: DivoStrings.continueButton)
        }
    }
    
    private func updateDropdownsUI() {
        eventTypeDropdown.setItems([eventTypeTitle ?? ""], emptyTitle: DivoStrings.notSet)
        countryRow.setItems([countryTitle ?? ""], emptyTitle: DivoStrings.notSet)
        whoCanApplyDropdown.setItems(whoCanApplyTitles ?? [], emptyTitle: DivoStrings.debugAll)
        maxParticipantsDropdown.setItems(maxParticipants.map {["\($0)"] } ?? [], emptyTitle: DivoStrings.notSet)
        genderDropdown.setItems(genderDropdownTitles ?? [], emptyTitle: DivoStrings.debugAll)
        hairLengthDropdown.setItems(hairLengthDropdownTitles ?? [], emptyTitle: DivoStrings.debugAll)
        hairColorDropdown.setItems(hairColorDropdownTitles ?? [], emptyTitle: DivoStrings.debugAll)
        eyeColorDropdown.setItems(eyeColorDropdownTitles ?? [], emptyTitle: DivoStrings.debugAll)
        skinColorDropdown.setItems(skinColorDropdownTitles ?? [], emptyTitle: DivoStrings.debugAll)
        rateTime.setTitle(rateTimeTitle)
    }
    
    private func updateGalleryHeight() {
        if galleryItems.isEmpty {
            galleryHeightConstraint.constant = 0
            galleryCollectionView.isHidden = true
        } else {
            galleryCollectionView.isHidden = false
            let fullWidth = UIScreen.main.bounds.width
            let itemWidth = floor(fullWidth / 3.0)
            let rows = ceil(CGFloat(galleryItems.count) / 3.0)
            let newHeight = (rows * itemWidth) + ((rows - 1) * 4.0)
            galleryHeightConstraint.constant = newHeight
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    func startPhotoUpload(image: UIImage) -> EventGalleryItem {
        let item = EventGalleryItem(image: image, isUploading: true)
        galleryItems.append(item)
        galleryCollectionView.reloadData()
        updateGalleryHeight()
        return item
    }
    
    func finishPhotoUpload(item: EventGalleryItem, fileUuid: String) {
        guard let index = galleryItems.firstIndex(of: item) else { return }
        galleryItems[index].isUploading = false
        galleryItems[index].fileUuid = fileUuid
        galleryCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }
    
    func cancelPhotoUpload(item: EventGalleryItem) {
        removePhoto(item: item)
    }
    
    func removePhoto(item: EventGalleryItem) {
        guard let index = galleryItems.firstIndex(of: item) else { return }
        galleryItems.remove(at: index)
        
        galleryCollectionView.performBatchUpdates({
            galleryCollectionView.deleteItems(at:[IndexPath(item: index, section: 0)])
        }, completion: { [weak self] _ in
            self?.updateGalleryHeight()
        })
    }
    
    private func loadExistingFiles(_ files: [EventFile]) {
        setAvatarLoading(true)
        self.galleryItems.removeAll()
        self.avatarFileUuid = nil
        let sortedFiles = files.sorted { ($0.order ?? 99) < ($1.order ?? 99) }
        
        for file in sortedFiles {
            guard let urlString = file.fullUrl, let url = URL(string: urlString), let fileUuid = file.fileUuid else { continue }
            if file.order == 0 {
                self.avatarFileUuid = fileUuid
                Task { @MainActor in
                    if let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) {
                        self.currentPhoto = image
                        self.setAvatarLoading(false)
                    }
                }
            } else {
                Task { @MainActor in
                    if let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) {
                        let item = EventGalleryItem(image: image, isUploading: false, fileUuid: fileUuid)
                        self.galleryItems.append(item)
                        self.galleryCollectionView.reloadData()
                        self.updateGalleryHeight()
                    }
                }
            }
        }
    }
    
    private func loadMoreEventTypesIfNeeded() {
        guard !self.isLoadingEventTypes && self.hasMoreEventTypes else { return }
        let threshold = max(0, self.eventTypeItems.count - 2)
        let selectedIndex = self.eventTypeItems.firstIndex(where: { $0.id == self.selectedEventTypeId }) ?? -1
        if selectedIndex >= threshold { self.loadMoreEventTypes() }
    }
    
    private func loadMoreEventTypes() {
        guard !self.isLoadingEventTypes && self.hasMoreEventTypes else { return }
        self.isLoadingEventTypes = true
        self.loadEventTypesList?(self.eventTypeItems.count, self.eventTypeLimit)
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
    
    private func makeInputStack(title: String, inputView: UIView) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        let stack = UIStackView(arrangedSubviews: [label, inputView])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }
    
    private func makeSwitchRow(title: String, subtitle: String? = nil, uiSwitch: UISwitch) -> UIStackView {
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = DivoColorPalette.cardBackground
        container.layer.cornerRadius = 23
        
        let switchStack = UIStackView()
        switchStack.axis = .horizontal
        switchStack.alignment = .center
        switchStack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(switchStack)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 46),
            
            switchStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            switchStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            switchStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        
        let row = UIStackView()
        row.axis = .vertical
        row.spacing = 4
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Font.regular(16)
        titleLabel.textColor = DivoColorPalette.primaryText
        switchStack.addArrangedSubview(titleLabel)
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        switchStack.addArrangedSubview(spacer)
        
        uiSwitch.onTintColor = DivoColorPalette.accent
        switchStack.addArrangedSubview(uiSwitch)
        
        row.addArrangedSubview(container)
        
        if let sub = subtitle {
            
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            
            let subLabel = UILabel()
            subLabel.text = sub
            subLabel.font = Font.regular(12)
            subLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
            subLabel.translatesAutoresizingMaskIntoConstraints = false
            
            container.addSubview(subLabel)
            
            NSLayoutConstraint.activate([
                container.heightAnchor.constraint(equalToConstant: 18),
                
                subLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
                subLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                subLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            row.addArrangedSubview(container)
        }
        
        return row
    }


    // MARK: - Internal
    
    func showScreenLoading() {
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
    
    func loadEventTypesComplete(_ items: [AgencyItem], totalCount: Int, offset: Int) {
        self.isLoadingEventTypes = false
        if offset == 0 {
            self.eventTypeItems = items
        } else {
            let existingIds = Set(self.eventTypeItems.map { $0.id })
            let newItems = items.filter { !existingIds.contains($0.id) }
            self.eventTypeItems.append(contentsOf: newItems)
        }
        self.hasMoreEventTypes = self.eventTypeItems.count < totalCount
        if self.hasMoreEventTypes {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.loadMoreEventTypes() }
        }
    }
    
    func configureEventTypeList(_ items: [AgencyItem], totalCount: Int) {
        self.eventTypeItems = items
        self.hasMoreEventTypes = self.eventTypeOffset + self.eventTypeLimit < totalCount
    }
    
    func appendEventTypeItems(_ items: [AgencyItem]) {
        self.eventTypeItems.append(contentsOf: items)
    }
    
    func configureAppearanceDictionaries(_ dict: AppearanceDictionaryData) {
        self.appearanceDictionaries = dict

        self.hairLengthOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for hairLength in dict.hairLength {
            self.hairLengthOptions.append(
                FilterOptionItem(id: String(hairLength.id), title: hairLength.title)
            )
        }
        
        self.hairColorOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for hairColor in dict.hairColor {
            self.hairColorOptions.append(
                FilterOptionItem(id: String(hairColor.id), title: hairColor.title)
            )
        }
        
        self.eyeColorOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for eyeColor in dict.eyeColor {
            self.eyeColorOptions.append(
                FilterOptionItem(id: String(eyeColor.id), title: eyeColor.title)
            )
        }
        
        self.skinColorOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for skinColor in dict.skinColor {
            self.skinColorOptions.append(
                FilterOptionItem(id: String(skinColor.id), title: skinColor.title)
            )
        }
    }
    
    func configureGenderDictionaries(_ dict: GenderResponse) {
        self.genderDictionaries = dict
        self.genderOptions.append(FilterOptionItem(id: "all", title: DivoStrings.debugAll))
        for gender in dict.data {
            self.genderOptions.append(
                FilterOptionItem(id: gender.id, title: gender.title)
            )
        }
    }

    // MARK: - Populate & Collect Data
    
    func updateTime(_ timestamp: Int32, _ mode: TimeControllerMode) {
        switch mode {
        case .time:
            eventTimeInt = timestamp
            eventTime.setDate(timestamp: timestamp)
        case .date:
            eventDateInt = timestamp
            eventDate.setDate(timestamp: timestamp)
        }
    }
    
    func updateDeadlineTime(_ timestamp: Int32, _ mode: TimeControllerMode) {
        switch mode {
        case .time:
            deadlineTimeInt = timestamp
            deadlineTime.setDate(timestamp: timestamp)
        case .date:
            deadlineDateInt = timestamp
            deadlineDate.setDate(timestamp: timestamp)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.currentLayoutData = (layout, navigationBarHeight, actualNavigationBarHeight)
        
        let scrolls = [step1ScrollView, step2ScrollView, step3ScrollView]
        for scroll in scrolls {
            var insets = scroll.contentInset
            insets.top = navigationBarHeight
            scroll.contentInset = insets
            scroll.scrollIndicatorInsets = insets
        }
    }
    
    func setAvatarLoading(_ loading: Bool) {
        if loading {
            avatarSpinner.startAnimating()
            avatarSpinner.isHidden = false
            avatarImageView.alpha = 0.0
            avatarImageSpinnerView.backgroundColor = DivoColorPalette.cardBackground
            avatarImageSpinnerView.isHidden = false
            chanceCenterPhotoView.isHidden = true
        } else {
            avatarSpinner.stopAnimating()
            avatarSpinner.isHidden = true
            avatarImageView.alpha = 1.0
            avatarImageSpinnerView.backgroundColor = .clear
            avatarImageSpinnerView.isHidden = true
        }
    }
 
    func collectEventData() throws -> CreateEventRequest {
        
        let title = nameEventTextField.textField.text ?? ""
        let description = aboutEventTextField.text
        let eventTypeId = Int(eventTypeId ?? "0") ?? 0

        let dateObj = Date(timeIntervalSince1970: TimeInterval(eventDateInt))
        let timeObj = Date(timeIntervalSince1970: TimeInterval(eventTimeInt))
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeObj)
        let finalDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: dateObj) ?? dateObj
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: finalDate)
        
        let dateToObj = calendar.date(byAdding: .hour, value: 2, to: finalDate) ?? finalDate
        let dateToString = formatter.string(from: dateToObj)
        
        // TODO: DIVO — city picker not implemented, using 1 as hardcoded stub
        let cityId = Int(self.countryId ?? "1") ?? 1
        let address = EventAddressRequest(
            street: nil,
            house: nil,
            apartment: nil,
            formatted: nil,
            latitude: nil,
            longitude: nil,
            cityId: cityId
        )
        
        var eventFiles: [EventFileRequest] = []
        var currentOrder = 0
                
        if let avatarUuid = avatarFileUuid {
            eventFiles.append(EventFileRequest(order: currentOrder, fileUuid: avatarUuid))
            currentOrder += 1
        }
        
        for item in galleryItems {
            if let uuid = item.fileUuid {
                eventFiles.append(EventFileRequest(order: currentOrder, fileUuid: uuid))
                currentOrder += 1
            }
        }
        
        let roles: [String]? = whoCanApplyIds
        var ageRange: EventRangeRequest?
        var heightRange: EventRangeRequest?
        var weightRange: EventRangeRequest?
        var waistRange: EventRangeRequest?
        var hipsRange: EventRangeRequest?
        var shoesRange: EventRangeRequest?
        let genders: [String]? = genderDropdownIds
        let hairColors: [Int] = hairColorDropdownIds?.map { Int($0) ?? 0 } ?? []
        let hairLengths: [Int] = hairLengthDropdownIds?.map { Int($0) ?? 0 } ?? []
        let eyeColors: [Int] = eyeColorDropdownIds?.map { Int($0) ?? 0 } ?? []
        let skinColors: [Int] = skinColorDropdownIds?.map { Int($0) ?? 0 } ?? []
        
        ageRange = EventRangeRequest(from: Float(selectedAge?.lowerBound ?? 0), to: Float(selectedAge?.upperBound ?? 0))
        heightRange = EventRangeRequest(from: Float(selectedHeight?.lowerBound ?? 0), to: Float(selectedHeight?.upperBound ?? 0))
        weightRange = EventRangeRequest(from: Float(selectedWeight?.lowerBound ?? 0), to: Float(selectedWeight?.upperBound ?? 0))
        waistRange = EventRangeRequest(from: Float(selectedWaist?.lowerBound ?? 0), to: Float(selectedWaist?.upperBound ?? 0))
        hipsRange = EventRangeRequest(from: Float(selectedHips?.lowerBound ?? 0), to: Float(selectedHips?.upperBound ?? 0))
        shoesRange = EventRangeRequest(from: Float(selectedShoeSize?.lowerBound ?? 0), to: Float(selectedShoeSize?.upperBound ?? 0))
        
        let paymentType = paidEventSwitch.isOn ? 1 : 2
        
        return CreateEventRequest(
            title: title,
            description: description,
            typeId: eventTypeId,
            date: dateString,
            dateTo: dateToString,
            address: address,
            files: eventFiles,
            paymentType: paymentType,
            paymentFrequency: Int(rateTimeId ?? "1"),
            cost: rateTextField.text,
            role: roles,
            gender: genders,
            age: ageRange,
            height: heightRange,
            weight: weightRange,
            breastSize: nil,
            waist: waistRange,
            hips: hipsRange,
            shoesSize: shoesRange,
            hairColor: hairColors,
            hairLength: hairLengths,
            eyeColor: eyeColors,
            skinColor: skinColors,
            measuringSystem: "metric"
        )
    }
    
    func populate(with detail: EventFullDetailData) {
        
        eventTypeId = "\(detail.type?.id ?? 1)"
        eventTypeTitle = detail.type?.title
        eventTypeDropdown.setItems([eventTypeTitle ?? ""], emptyTitle: "")
        
        nameEventTextField.textField.text = detail.title
        
        aboutEventTextField.textView.text = detail.description ?? ""
        aboutEventTextField.textView.textColor = DivoColorPalette.primaryText
        
        if let dateString = detail.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let dateObj = formatter.date(from: dateString) {
                let timestamp = Int32(dateObj.timeIntervalSince1970)
                self.updateTime(timestamp, .date)
                self.updateTime(timestamp, .time)
            }
        }
        
        // НИЧЕГО НЕ ПРО СТРАНУ И НЕПОНЯТНО КАК ЗАПОЛНЯТЬ АДРЕС
        
        whoCanApplyIds = detail.modelAttributes?.role
        whoCanApplyTitles = whoCanApplyIds?.compactMap { id in
            roleOptions.first(where: { $0.id == id })?.title
        }
        whoCanApplyDropdown.setItems(whoCanApplyTitles ?? [], emptyTitle: "")
        
        // НИЧЕГО НЕТ ПРО МАКСИМАЛЬНОЕ КОЛИЧЕСТВО УЧАСТНИКОВ
        // НИЧЕГО НЕТ ПРО ОПИСАНИЕ ОБЯЗАНОСТЕЙ
        
        genderDropdownIds = detail.modelAttributes?.gender?.map(\.id!)
        genderDropdownTitles = detail.modelAttributes?.gender?.map(\.title!)
        
        hairLengthDropdownIds = detail.modelAttributes?.hairLength?.compactMap { String($0.id!) }
        hairLengthDropdownTitles = detail.modelAttributes?.hairLength?.map(\.title!)
        
        hairColorDropdownIds = detail.modelAttributes?.hairColor?.compactMap { String($0.id!) }
        hairColorDropdownTitles = detail.modelAttributes?.hairColor?.map(\.title!)
        
        eyeColorDropdownIds = detail.modelAttributes?.eyeColor?.compactMap { String($0.id!) }
        eyeColorDropdownTitles = detail.modelAttributes?.eyeColor?.map(\.title!)
        
        skinColorDropdownIds = detail.modelAttributes?.skinColor?.compactMap { String($0.id!) }
        skinColorDropdownTitles = detail.modelAttributes?.skinColor?.map(\.title!)
        
        
        selectedAge = Int(detail.modelAttributes?.age?.from ?? 0)...Int(detail.modelAttributes?.age?.to ?? 0)
        selectedHeight = Double(detail.modelAttributes?.height?.from ?? 0)...Double(detail.modelAttributes?.height?.to ?? 0)
        selectedWeight = Double(detail.modelAttributes?.weight?.from ?? 0)...Double(detail.modelAttributes?.weight?.to ?? 0)
        selectedWaist = Double(detail.modelAttributes?.waist?.from ?? 0)...Double(detail.modelAttributes?.waist?.to ?? 0)
        selectedHips = Double(detail.modelAttributes?.hips?.from ?? 0)...Double(detail.modelAttributes?.hips?.to ?? 0)
        selectedShoeSize = Double(detail.modelAttributes?.shoesSize?.from ?? 0)...Double(detail.modelAttributes?.shoesSize?.to ?? 0)
        
        // НИЧЕГО НЕТ ДЛЯ НДА
        // НИЧЕГО НЕТ ДЛЯ ВЫСТАВЛЕНИЯ ВРЕМЕНИ ДЕДЛАЙНА
        
        paidEventSwitch.isOn = detail.paymentType?.id == 1
        rateTextField.text = detail.cost
        rateTimeId = String(detail.paymentFrequency?.id ?? 0)
        rateTimeTitle = detail.paymentFrequency?.title ?? ""
        
        // НИЧЕГО НЕТ ДЛЯ ПУБЛИЧНОГО ЭВЕНТА
        updateDropdownsUI()
        updateAppearanceValues()
        
        if let files = detail.files {
            loadExistingFiles(files)
        }
    }
    
    
    // MARK: - Handlers & Navigations
    
    @objc private func appearanceCellTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < appearanceEditItems.count else { return }
        appearanceEditItems[view.tag].onTap()
    }
    
    @objc private func mainActionButtonTapped() {
        self.view.endEditing(true)
        if currentStep < 3 {
            currentStep += 1
            scrollToCurrentStep()
        } else {
            onCreateEventTapped?()
        }
    }
    
    @objc private func backButtonTapped() {
        self.view.endEditing(true)
        if currentStep > 1 {
            currentStep -= 1
            scrollToCurrentStep()
        } else {
            onBackTapped?()
        }
    }
    
    @objc private func avatarTapped() {
        self.view.endEditing(true)
        onAvatarTap?()
    }
    
    @objc private func eventTypeTapped() {
        self.view.endEditing(true)
        
        let options = eventTypeItems.map { FilterOptionItem(id: String($0.id), title: $0.title) }
        let selectedIds = eventTypeId != nil ? [String(eventTypeId!)] : []
        
        let vc = FilterOptionsController(
            title: DivoStrings.eventType,
            options: options,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: false,
            isOpenPresent: true,
            isResetButton: false,
        )
        
        vc.onSave = { [weak self] selectedItems in
            if let selected = selectedItems.first {
                self?.eventTypeId = selected.id
                self?.eventTypeTitle = selected.title
            } else {
                self?.eventTypeId = nil
                self?.eventTypeTitle = nil
            }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    @objc private func countryTapped() {
        self.view.endEditing(true)
        let selectedIds = countryId != nil ? [String(countryId!)] : []
        
        let vc = FilterOptionsController(
            title: DivoStrings.debugCountry,
            options: countryOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: true,
            isOpenPresent: true,
            isResetButton: false,
        )

        vc.onSave = { [weak self] selectedItems in
            if let selected = selectedItems.first {
                self?.countryId = selected.id
                self?.countryTitle = selected.title
            } else {
                self?.countryId = nil
                self?.countryTitle = nil
            }
            self?.updateDropdownsUI()
        }
        
        presentSheet(vc)
    }
    
    @objc private func roleTapped() {
        self.view.endEditing(true)
        let selectedIds = whoCanApplyIds ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.whoCanApply,
            options: roleOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            isOpenPresent: true,
            isResetButton: false,
        )
        
        vc.onSave = {[weak self] selectedItems in
            self?.whoCanApplyIds = selectedItems.map { $0.id }
            self?.whoCanApplyTitles = selectedItems.map { $0.title }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    @objc private func genderDropdownTapped() {
        self.view.endEditing(true)
        let selectedIds = genderDropdownIds ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.gender,
            options: genderOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            isOpenPresent: true,
            isResetButton: false,
        )
        
        vc.onSave = {[weak self] selectedItems in
            self?.genderDropdownIds = selectedItems.map { $0.id }
            self?.genderDropdownTitles = selectedItems.map { $0.title }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    @objc private func rateTimeTapped() {
        self.view.endEditing(true)
        let selectedIds = rateTimeId != nil ? [String(rateTimeId!)] : []
        
        let vc = FilterOptionsController(
            title: DivoStrings.rateTime,
            options: rateTimeOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: false,
            isOpenPresent: true,
            isResetButton: false,
        )

        vc.onSave = { [weak self] selectedItems in
            if let selected = selectedItems.first {
                self?.rateTimeId = selected.id
                self?.rateTimeTitle = selected.title
            } else {
                self?.rateTimeId = nil
                self?.rateTimeTitle = "per hour"
            }
            self?.updateDropdownsUI()
        }
        
        presentSheet(vc)
    }
    
    @objc private func hairLengthDropdownTapped() {
        self.view.endEditing(true)
        let selectedIds = hairLengthDropdownIds ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.gender,
            options: hairLengthOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            isOpenPresent: true,
            isResetButton: false,
        )
        
        vc.onSave = {[weak self] selectedItems in
            self?.hairLengthDropdownIds = selectedItems.map { $0.id }
            self?.hairLengthDropdownTitles = selectedItems.map { $0.title }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    @objc private func hairColorDropdownTapped() {
        self.view.endEditing(true)
        let selectedIds = hairColorDropdownIds ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.gender,
            options: hairColorOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            isOpenPresent: true,
            isResetButton: false,
        )
        
        vc.onSave = {[weak self] selectedItems in
            self?.hairColorDropdownIds = selectedItems.map { $0.id }
            self?.hairColorDropdownTitles = selectedItems.map { $0.title }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    @objc private func eyeColorDropdownTapped() {
        self.view.endEditing(true)
        let selectedIds = eyeColorDropdownIds ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.gender,
            options: eyeColorOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            isOpenPresent: true,
            isResetButton: false,
        )
        
        vc.onSave = {[weak self] selectedItems in
            self?.eyeColorDropdownIds = selectedItems.map { $0.id }
            self?.eyeColorDropdownTitles = selectedItems.map { $0.title }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    @objc private func skinColorDropdownTapped() {
        self.view.endEditing(true)
        let selectedIds = skinColorDropdownIds ?? []
        let vc = FilterOptionsController(
            title: DivoStrings.gender,
            options: skinColorOptions,
            selectedOptionIds: selectedIds,
            isMultiSelect: true,
            isOpenPresent: true,
            isResetButton: false,
        )
        
        vc.onSave = {[weak self] selectedItems in
            self?.skinColorDropdownIds = selectedItems.map { $0.id }
            self?.skinColorDropdownTitles = selectedItems.map { $0.title }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    @objc private func maxParticipantsTapped() {
        self.view.endEditing(true)
        let vc = RangeFilterController(
            title: DivoStrings.maxParticipants,
            min: 10,
            max: 100,
            currentLower: nil,
            currentUpper: maxParticipants.map{Double($0)},
            isSingleValue: true,
            isOpenPresent: true,
            isResetButton: false
        )
        
        vc.onSave = {[weak self] _, upperVal in
            self?.maxParticipants = upperVal.map { Int($0) }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardHeight = keyboardFrame.cgRectValue.height
        applyButtonBottomConstraint.constant = -keyboardHeight - 16
        
        let scrolls = [step1ScrollView, step2ScrollView, step3ScrollView]
        let activeScroll = scrolls[currentStep - 1]
        activeScroll.contentInset.bottom = keyboardHeight
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        applyButtonBottomConstraint.constant = -40
        let scrolls = [step1ScrollView, step2ScrollView, step3ScrollView]
        let activeScroll = scrolls[currentStep - 1]
        activeScroll.contentInset.bottom = 100
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }

    func updateCountry(countryId: String, countryName: String) {

    }

    @objc private func dashedUploadTapped() { onAddGalleryPhotoTapped?() }
    @objc private func deleteParameterTapped(_ button: ASButtonNode) {
        guard let param = deleteButtons.first(where: { $0.value === button })?.key else { return }
        self.selectedParameters.remove(param)
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

// MARK: - UICollectionViewDataSource & Delegate
extension CreateEventNode: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return galleryItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EventGalleryCell", for: indexPath) as! EventGalleryCell
        let item = galleryItems[indexPath.row]
        cell.configure(with: item)
        cell.onDelete = { [weak self, item] in
            self?.removePhoto(item: item)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = floor((UIScreen.main.bounds.width - 32) / 3.0)
        return CGSize(width: width, height: width)
    }
}

extension CreateEventNode: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == rateTextField {
            rateFieldContainer.layer.borderWidth = 1.0
            rateFieldContainer.layer.borderColor = DivoColorPalette.accent.cgColor
        } else {
            textField.layer.borderWidth = 1.0
            textField.layer.borderColor = DivoColorPalette.accent.cgColor
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == rateTextField {
            rateFieldContainer.layer.borderWidth = 0.0
        } else {
            textField.layer.borderWidth = 0.0
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == nameEventTextField.textField {
            aboutEventTextField.textView.becomeFirstResponder()
        }
        
        return false
    }
}