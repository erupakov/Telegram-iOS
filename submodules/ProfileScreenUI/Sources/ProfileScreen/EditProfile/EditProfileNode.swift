import Display
import UIKit
import AsyncDisplayKit
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
import DivoUIKit

private struct AppearanceFilterItem {
    let title: String
    let getValues: () -> [String]
    let emptyTitle: String
    let onTap: () -> Void
}

final class EditProfileNode: ASDisplayNode {
    
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let model: UserDetail?
    var showAlert: ((String) -> Void)?
    
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
    
    var currentFilters: FilterState
    
    private let topBarContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(20)
        label.textColor = UIColor(hexString: "#222222")
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = UIImage(systemName: "chevron.left", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = UIColor(hexString: "#222222")

        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
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
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    
    // MARK: - Tab
    
    private let tabsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.05
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private static func createTabButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title.uppercased(), for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(10)
        button.setTitleColor(UIColor(hexString: "#222222"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private let biographyButton = createTabButton(title: DivoStrings.biographyTitle)
    private let appearanceButton = createTabButton(title: DivoStrings.appearanceTitle)
    private let experienceButton = createTabButton(title: DivoStrings.experienceTitle)
    
    private let tabButtonsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hexString: "#F0F0F0")
        view.layer.cornerRadius = 14
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var indicatorCenterXConstraint: NSLayoutConstraint!
    private var selectedIndex: Int = 0
    
    
    // MARK: - Swipe Pager

    private lazy var horizontalPager: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.delegate = self
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.clipsToBounds = false
        sv.isScrollEnabled = false
        return sv
    }()
    
    private var pagerHeightConstraint: NSLayoutConstraint!
    
    private let bioStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let appearanceStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let experienceStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    
    // MARK: - Biography UI
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.layer.borderColor = UIColor.white.cgColor
        iv.layer.borderWidth = 1.0
        iv.backgroundColor = .systemGray
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let chancePhotoView: UIButton = {
        let button = UIButton(type: .custom)
// <<<<<<< HEAD
//         button.backgroundColor = .white
// =======
        button.backgroundColor = DivoColorPalette.accentSecondary
// >>>>>>> dev
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(bundleImageName: "Components/AddPhotoIcon")
        button.setImage(image, for: .normal)
        button.tintColor = UIColor(hexString: "#FF772D")
        button.layer.cornerRadius = 16
        button.layer.borderColor = UIColor(hexString: "#FF772D")?.cgColor
        button.layer.borderWidth = 1
        button.layer.masksToBounds = true
        let padding: CGFloat = 4
        button.imageEdgeInsets = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private let avatarSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private let nameEventTextField: DivoTextField
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
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
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
    
    private let hairLengthDropdown = FilterRowView(title: DivoStrings.hairLength)
    private let hairColorDropdown = FilterRowView(title: DivoStrings.hairColor)
    private let eyeColorDropdown = FilterRowView(title: DivoStrings.eyeColor)
    private let skinColorDropdown = FilterRowView(title: DivoStrings.skinColor)
    
    // MARK: - Footer UI
    
    private let applyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(DivoStrings.save, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitleColor(UIColor(hexString: "#AFAFB1"), for: .disabled)
        btn.titleLabel?.font = Font.helveticaNeue(20)
        btn.backgroundColor = UIColor(hexString: "#FF772D")
        btn.layer.cornerRadius = 28
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private var applyButtonBottomConstraint: NSLayoutConstraint?
    
    private let applyButtonSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    var currentPhoto: UIImage? = nil {
        didSet {
            avatarImageView.image = currentPhoto
            avatarImageView.applyAvatarTopCropIfNeeded(image: currentPhoto)
        }
    }
    
    private var appearanceFilterItems: [AppearanceFilterItem] = []
    
    private let bottomBlurOverlay: GradientBlurView = {
        let view = GradientBlurView(isTop: false)
        view.isHidden = false
        return view
    }()
    
    private var bottomBlurOverlayBottomConstraint: NSLayoutConstraint?
    
    
    // MARK: - Init
    
    init(context: AccountContext, presentationData: PresentationData, model: UserDetail?, currentFilters: FilterState) {
        self.currentFilters = currentFilters
        self.context = context
        self.model = model
        
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
                
        var name = ""
        var placeholder = ""
        var bioTitle = ""
        var bio = ""
        if model?.role == "agency_employee" {
            name = model?.agency?.title ?? DivoStrings.name
            placeholder = DivoStrings.agencyProfile
            bioTitle = DivoStrings.descriptionTitle
            bio = model?.agency?.description ?? DivoStrings.fillInInfoAboutAgency
        } else {
            name = model?.fullName ?? DivoStrings.name
            placeholder = DivoStrings.fullName
            bioTitle = DivoStrings.biographyTitle
            bio = model?.model?.description ?? DivoStrings.fillInInfoAboutYou
        }
        
        self.nameEventTextField = DivoTextField(title: name, prefix: "")
        self.nameEventTextField.textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            font: Font.regular(16),
            textColor: UIColor(hexString: "#222222")?.withAlphaComponent(0.4) ?? .black.withAlphaComponent(0.4)
        )
        self.nameEventTextField.isUserInteractionEnabled = (model?.role == "agency_employee") ? false : true
        
        self.aboutEventTextField = DivoTextView(title: bioTitle, initialText: bio)

// <<<<<<< HEAD
// =======
//         let currentGender = model?.gender?.title ?? DivoStrings.loading
//         self.genderDropdown = DropdownNode(title: DivoStrings.gender, placeholder: DivoStrings.selectGender, options: [currentGender])
//         self.genderDropdown.selectedValue = self.model?.gender?.title
        
//         self.ageSlider = AgeSliderNode<Int>(
//             title: DivoStrings.ageYo,
//             type: "y.o",
//             mode: .single(value: 17),
//             minimumValue: 14,
//             maximumValue: 45,
//             configuration: .default
//         )

//         self.heightSlider = AgeSliderNode<Double>(
//             title: DivoStrings.heightCm,
//             type: "cm",
//             mode: .single(value: Float(model?.model?.appearance?.height ?? 1.68)),
//             minimumValue: 1.68,
//             maximumValue: 2.50,
//             configuration: .default
//         )

//         self.weightSlider = AgeSliderNode<Double>(
//             title: DivoStrings.weightKg,
//             type: "kg",
//             mode: .single(value: Float(model?.model?.appearance?.weight ?? 50)),
//             minimumValue: 48,
//             maximumValue: 90,
//             configuration: .default
//         )

//         self.waistSlider = AgeSliderNode<Double>(
//             title: DivoStrings.waistCm,
//             type: "cm",
//             mode: .single(value: Float(model?.model?.appearance?.waist ?? 60)),
//             minimumValue: 48,
//             maximumValue: 90,
//             configuration: .default
//         )

//         self.hipsSlider = AgeSliderNode<Double>(
//             title: DivoStrings.hipsCm,
//             type: "cm",
//             mode: .single(value: Float(model?.model?.appearance?.hips ?? 91)),
//             minimumValue: 80,
//             maximumValue: 110,
//             configuration: .default
//         )

//         self.shoeSizeSlider = AgeSliderNode<Double>(
//             title: DivoStrings.shoeSizeEU,
//             type: "",
//             mode: .single(value: Float(model?.model?.appearance?.shoesSize ?? 37)),
//             minimumValue: 36,
//             maximumValue: 42,
//             configuration: .default
//         )

//         let currentHairLength = model?.model?.appearance?.hairLength?.title ?? DivoStrings.loading
//         let currentHairColor = model?.model?.appearance?.hairColor?.title ?? DivoStrings.loading
//         let currentEyeColor = model?.model?.appearance?.eyeColor?.title ?? DivoStrings.loading
//         let currentSkinColor = model?.model?.appearance?.skinColor?.title ?? DivoStrings.loading

//         self.hairLengthDropdown = DropdownNode(title: DivoStrings.hairLength, placeholder: DivoStrings.chooseHairLength, options: [currentHairLength])
//         self.hairColorDropdown = DropdownNode(title: DivoStrings.hairColor, placeholder: DivoStrings.chooseHairColor, options: [currentHairColor])
//         self.eyeColorDropdown = DropdownNode(title: DivoStrings.eyeColor, placeholder: DivoStrings.chooseEyeColor, options: [currentEyeColor])
//         self.skinColorDropdown = DropdownNode(title: DivoStrings.skinColor, placeholder: DivoStrings.chooseSkinColor, options: [currentSkinColor])
        
//         self.hairLengthDropdown.selectedValue = model?.model?.appearance?.hairLength?.title
//         self.hairColorDropdown.selectedValue = model?.model?.appearance?.hairColor?.title
//         self.eyeColorDropdown.selectedValue = model?.model?.appearance?.eyeColor?.title
//         self.skinColorDropdown.selectedValue = model?.model?.appearance?.skinColor?.title
        
//         self.applyButton = ButtonWithIconNode(title: DivoStrings.save, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
//         self.applyButton.backgroundColor = DivoColorPalette.accentCopperWarm
//         self.applyButtonAppearance = ButtonWithIconNode(title: DivoStrings.save, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
//         self.applyButtonAppearance.backgroundColor = DivoColorPalette.accentCopperWarm
        
// >>>>>>> dev
        super.init()
        
        self.backgroundColor = UIColor(hexString: "#F0F0F0")

        if let app = model?.model?.appearance {
            self.selectedHeight = Double(app.height ?? 1)
            self.selectedWeight = Double(app.weight ?? 0)
            self.selectedWaist = Double(app.waist ?? 0)
            self.selectedHips = Double(app.hips ?? 0)
            self.selectedShoeSize = Double(app.shoesSize ?? 0)
            
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
        
// <<<<<<< HEAD
        setupAppearanceFilterItems()
// =======
        self.backgroundColor = DivoColorPalette.darkBackground
// >>>>>>> dev
    }
    
    override func didLoad() {
        super.didLoad()
        setupUI()
        
        updateDropdownsUI()
        
        backButton.addTarget(self, action: #selector(backPressed), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        backButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        let avatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.avatarTapped))
        self.avatarImageView.addGestureRecognizer(avatarTapGesture)
        
        self.biographyButton.addTarget(self, action: #selector(biographyTapped), for: .touchUpInside)
        self.appearanceButton.addTarget(self, action: #selector(appearanceTapped), for: .touchUpInside)
        self.experienceButton.addTarget(self, action: #selector(experienceTapped), for: .touchUpInside)

        if model?.role == "agency_employee" {
            self.applyButton.addTarget(self, action: #selector(self.saveAgencyButtonPressed), for: .touchUpInside)
        } else {
            self.applyButton.addTarget(self, action: #selector(self.saveButtonPressed), for: .touchUpInside)
        }

        self.chancePhotoView.addTarget(self, action: #selector(self.avatarTapped), for: .touchUpInside)
        
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        dismissTap.delegate = self
        self.view.addGestureRecognizer(dismissTap)

        scrollView.keyboardDismissMode = .interactive

        self.nameEventTextField.textField.returnKeyType = .next
        self.nameEventTextField.textField.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        loadAvatarIfNeeded()

        DispatchQueue.main.async {
            self.updatePagerHeight()
            if self.model?.role != "agency_employee" {
                self.updateIndicatorPosition(progress: 0, animated: false)
            }
            self.readyValue = true
        }
        
        updateAppearanceValues()
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
        view.addSubview(topBarContainer)
        topBarContainer.addSubview(backButton)
        topBarContainer.addSubview(titleLabel)
        
        view.addSubview(scrollView)
        scrollView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            topBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarContainer.heightAnchor.constraint(equalToConstant: 50),
            
            backButton.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBarContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: topBarContainer.bottomAnchor),
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
            setupTabs()
            setupPager()
        } else {
            setupAgencyPager()
        }
    }
    
    private func setupTabs() {
        mainStackView.addArrangedSubview(tabsContainer)
        
        tabsContainer.heightAnchor.constraint(equalToConstant: 32).isActive = true
        tabsContainer.widthAnchor.constraint(equalTo: mainStackView.widthAnchor, constant: -32).isActive = true
        
        tabsContainer.addSubview(indicatorView)
        
        tabButtonsStack.addArrangedSubview(biographyButton)
        tabButtonsStack.addArrangedSubview(appearanceButton)
        tabButtonsStack.addArrangedSubview(experienceButton)
        tabsContainer.addSubview(tabButtonsStack)
        
        NSLayoutConstraint.activate([
            
            tabsContainer.leadingAnchor.constraint(equalTo: mainStackView.leadingAnchor, constant: 16),
            tabsContainer.trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor, constant: -16),
            
            tabButtonsStack.topAnchor.constraint(equalTo: tabsContainer.topAnchor),
            tabButtonsStack.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor),
            tabButtonsStack.leadingAnchor.constraint(equalTo: tabsContainer.leadingAnchor),
            tabButtonsStack.trailingAnchor.constraint(equalTo: tabsContainer.trailingAnchor),
            
            indicatorView.topAnchor.constraint(equalTo: tabsContainer.topAnchor, constant: 2),
            indicatorView.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor, constant: -2),
            indicatorView.widthAnchor.constraint(equalTo: biographyButton.widthAnchor, constant: -4)
        ])
        
        indicatorCenterXConstraint = indicatorView.centerXAnchor.constraint(equalTo: tabsContainer.leadingAnchor)
        indicatorCenterXConstraint.isActive = true
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
            
            bioStackView.leadingAnchor.constraint(equalTo: contentWidthView.leadingAnchor),
            bioStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            bioStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor),
            
            appearanceStackView.leadingAnchor.constraint(equalTo: bioStackView.trailingAnchor, constant: 32),
            appearanceStackView.trailingAnchor.constraint(equalTo: experienceStackView.leadingAnchor, constant: 32),
            appearanceStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            appearanceStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor),
            
            experienceStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            experienceStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor),
            experienceStackView.trailingAnchor.constraint(equalTo: contentWidthView.trailingAnchor)
        ])
        
        setupBioContent()
        setupAppearanceContent()
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
            contentWidthView.leadingAnchor.constraint(equalTo: horizontalPager.leadingAnchor, constant: 16),
            contentWidthView.trailingAnchor.constraint(equalTo: horizontalPager.trailingAnchor, constant: -16),
            contentWidthView.heightAnchor.constraint(equalTo: horizontalPager.heightAnchor),
            
            bioStackView.leadingAnchor.constraint(equalTo: contentWidthView.leadingAnchor),
            bioStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            bioStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -32),
            bioStackView.trailingAnchor.constraint(equalTo: contentWidthView.trailingAnchor)
        ])
        
        setupBioContent()
    }
    
    private func setupBioContent() {
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(chancePhotoView)
        avatarContainer.addSubview(avatarSpinner)
        
        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 120),
            
            avatarImageView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),

            chancePhotoView.trailingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 4),
            chancePhotoView.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor),
            chancePhotoView.widthAnchor.constraint(equalToConstant: 32),
            chancePhotoView.heightAnchor.constraint(equalToConstant: 32),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor)
        ])
        
        bioStackView.addArrangedSubview(avatarContainer)
        avatarContainer.widthAnchor.constraint(equalTo: bioStackView.widthAnchor).isActive = true
        
        nameEventTextField.view.translatesAutoresizingMaskIntoConstraints = false
        aboutEventTextField.translatesAutoresizingMaskIntoConstraints = false
        
        bioStackView.addArrangedSubview(nameEventTextField.view)
        bioStackView.addArrangedSubview(aboutEventTextField)
        
        NSLayoutConstraint.activate([
            nameEventTextField.view.widthAnchor.constraint(equalTo: bioStackView.widthAnchor),
            nameEventTextField.view.heightAnchor.constraint(equalToConstant: 48),

            aboutEventTextField.widthAnchor.constraint(equalTo: bioStackView.widthAnchor),
            aboutEventTextField.heightAnchor.constraint(equalToConstant: 140)
        ])
        
        applyButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
        
        view.addSubview(bottomBlurOverlay)
        view.addSubview(applyButton)
        
        applyButton.addSubview(applyButtonSpinner)
        
        let buttonBottomCns = applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        self.applyButtonBottomConstraint = buttonBottomCns
        
        let bottomBlurOverlayCns = bottomBlurOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.bottomBlurOverlayBottomConstraint = bottomBlurOverlayCns

        NSLayoutConstraint.activate([
            buttonBottomCns,
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            applyButtonSpinner.centerXAnchor.constraint(equalTo: applyButton.centerXAnchor),
            applyButtonSpinner.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),
            
            bottomBlurOverlayCns,
            bottomBlurOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBlurOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBlurOverlay.heightAnchor.constraint(equalToConstant: 160)
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
    
    private func reloadAppearanceOptions() {
        appearanceContainerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (index, item) in appearanceFilterItems.enumerated() {
            let isLast = index == appearanceFilterItems.count - 1
            let cell = AppearanceFilterRowView(title: item.title, isLast: isLast)
            cell.setItems(item.getValues(), emptyTitle: "Not set")
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(appearanceCellTapped(_:)))
            cell.addGestureRecognizer(tap)
            cell.tag = index
            appearanceContainerStack.addArrangedSubview(cell)
        }
    }
    
    private func setupAppearanceFilterItems() {
        appearanceFilterItems = [
            AppearanceFilterItem(
                title: DivoStrings.ageYo,
                getValues: { [weak self] in self?.selectedAge.map {["\($0)"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.ageYo, unit: "y.o.", min: 14, max: 100, current: self?.selectedAge.map{Double($0)}) { val in
                        self?.selectedAge = val.map { Int($0) }
                    }
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.heightCm,
                getValues: { [weak self] in self?.selectedHeight.map { ["\(Int($0)) cm"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.heightCm, unit: "cm", min: 100, max: 300, current: self?.selectedHeight) { val in
                        self?.selectedHeight = val
                    }
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.weightKg,
                getValues: { [weak self] in self?.selectedWeight.map { ["\(Int($0)) kg"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: {[weak self] in
                    self?.showSingleInput(title: DivoStrings.weightKg, unit: "kg", min: 30, max: 150, current: self?.selectedWeight) { val in
                        self?.selectedWeight = val
                    }
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.waistCm,
                getValues: { [weak self] in self?.selectedWaist.map { ["\(Int($0)) cm"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.waistCm, unit: "cm", min: 40, max: 120, current: self?.selectedWaist) { val in
                        self?.selectedWaist = val
                    }
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.hipsCm,
                getValues: { [weak self] in self?.selectedHips.map { ["\(Int($0)) cm"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.hipsCm, unit: "cm", min: 60, max: 150, current: self?.selectedHips) { val in
                        self?.selectedHips = val
                    }
                }
            ),
            AppearanceFilterItem(
                title: DivoStrings.shoeSizeEU,
                getValues: {[weak self] in self?.selectedShoeSize.map { ["\(Int($0))"] } ?? [] },
                emptyTitle: DivoStrings.debugAny,
                onTap: { [weak self] in
                    self?.showSingleInput(title: DivoStrings.shoeSizeEU, unit: "", min: 30, max: 50, current: self?.selectedShoeSize) { val in
                        self?.selectedShoeSize = val
                    }
                }
            ),
        ]
    }
    
    private func updateAppearanceValues() {
        for (index, item) in appearanceFilterItems.enumerated() {
            if let cell = appearanceContainerStack.arrangedSubviews[safe: index] as? AppearanceFilterRowView {
                cell.setItems(item.getValues(), emptyTitle: "Not set")
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
        avatarImageView.alpha = 0.5
        ImageLoader.shared.load(url: avatarURL) { [weak self] image in
            guard let self else { return }
            self.avatarSpinner.stopAnimating()
            self.avatarImageView.alpha = 1.0
            if let image {
                self.avatarImageView.image = image
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
    
    private func showSingleInput(title: String, unit: String, min: Double, max: Double, current: Double?, completion: @escaping (Double?) -> Void) {
        let vc = RangeFilterController(
            title: title,
            min: min,
            max: max,
            unit: unit,
            currentLower: nil,
            currentUpper: current,
            isSingleValue: true,
            isOpenPresent: true,
            isResetButton: false
        )
        
        vc.onSave = {[weak self] _, upperVal in
            completion(upperVal)
            self?.updateAppearanceValues()
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
                sheet.preferredCornerRadius = 24
            }
        }
        presentController?(nav)
    }
    
    private func updateDropdownsUI() {
        genderDropdown.setItems([selectedGenderTitle ?? "Not set"], emptyTitle: "Not set")
        hairLengthDropdown.setItems([selectedHairLengthTitle ?? "Not set"], emptyTitle: "Not set")
        hairColorDropdown.setItems([selectedHairColorTitle ?? "Not set"], emptyTitle: "Not set")
        eyeColorDropdown.setItems([selectedEyeColorTitle ?? "Not set"], emptyTitle: "Not set")
        skinColorDropdown.setItems([selectedSkinColorTitle ?? "Not set"], emptyTitle: "Not set")
    }

    func setAvatarLoading(_ loading: Bool) {
        if loading {
            avatarSpinner.startAnimating()
            avatarImageView.alpha = 0.5
        } else {
            avatarSpinner.stopAnimating()
            avatarImageView.alpha = 1.0
        }
    }

    func toggleSpinner(active: Bool) {
        self.applyButton.isUserInteractionEnabled = !active
        
        if active {
            self.applyButtonSpinner.startAnimating()
            UIView.animate(withDuration: 0.2) {
                self.applyButton.setTitle("", for: .normal)
            }
        } else {
            self.applyButtonSpinner.stopAnimating()
            UIView.animate(withDuration: 0.2) {
                self.applyButton.setTitle(DivoStrings.save, for: .normal)
            }
        }
    }
    
    func updateTitle(_ title: String) {
        titleLabel.text = title.uppercased()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        DispatchQueue.main.async {
            self.updatePagerHeight()
            if self.model?.role != "agency_employee" {
                self.updateIndicatorPosition(progress: CGFloat(self.selectedIndex), animated: false)
            }
        }
    }

    func configureAppearanceDictionaries(_ dict: AppearanceDictionaryData) {
        self.appearanceDictionaries = dict

    }
    
    func configureGenderDictionaries(_ dict: GenderResponse) {
        self.genderDictionaries = dict
        
    }
    
    @objc private func appearanceCellTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < appearanceFilterItems.count else { return }
        appearanceFilterItems[view.tag].onTap()
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        let keyboardHeight = keyboardFrame.height
        
        scrollView.contentInset.bottom = keyboardHeight + 90
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight + 90
        
        applyButtonBottomConstraint?.constant = -(keyboardHeight + 16)
        bottomBlurOverlayBottomConstraint?.constant = -(keyboardHeight - 26)
        
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
            if self.aboutEventTextField.textView.isFirstResponder {
                let fieldFrame = self.aboutEventTextField.convert(self.aboutEventTextField.bounds, to: self.scrollView)
                self.scrollView.scrollRectToVisible(fieldFrame, animated: false)
            }
        }, completion: nil)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        applyButtonBottomConstraint?.constant = -40
        bottomBlurOverlayBottomConstraint?.constant = 0
        
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
            self.scrollView.contentInset.bottom = 80
            self.scrollView.verticalScrollIndicatorInsets.bottom = 0
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @objc private func avatarTapped() {
        print("Change photo")
        onAvatarTap?()
    }
    
    @objc private func biographyTapped() {
        self.view.endEditing(true)
        setSelectedIndex(0, animated: true)
    }
    
    @objc private func appearanceTapped() {
        self.view.endEditing(true)
        setSelectedIndex(1, animated: true)
    }
    
    @objc private func experienceTapped() {
        self.view.endEditing(true)
        setSelectedIndex(2, animated: true)
    }
    
    @objc private func updateAccountPeerName() {
        print("Save button tapped")
    }
    
    @objc private func saveButtonPressed() {
        self.view.endEditing(true)
        
        let data = UpdateBiographyPageRequest(
            fullName: self.nameEventTextField.textField.text ?? "",
            gender: self.selectedGenderId,
            model: UpdateBiographyPageRequest.ModelData(
                description: self.aboutEventTextField.text,
                appearance: Appearance(
                    measuringSystem: "metric",
                    height: self.selectedHeight,
                    weight: self.selectedWeight,
                    breastSize: "",
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
        
        self.toggleSpinner(active: true)
        self.saveProfile?(data)
    }

    @objc private func saveAgencyButtonPressed() {
        self.view.endEditing(true)
        let data = UpdateDescriptionAgencyRequest(
            agencyId: model?.agency?.id,
            description: self.aboutEventTextField.text
        )
            
        self.toggleSpinner(active: true)
        self.saveAgencyProfile?(data)
    }
    
    @objc private func backPressed() {
        onBackTapped?()
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
        }
        presentSheet(vc)
    }
    
    @objc private func hairLengthTapped() {
        self.view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.hairLength, dict: appearanceDictionaries?.hairLength, currentId: selectedHairLengthId) {[weak self] id, title in
            self?.selectedHairLengthId = id
            self?.selectedHairLengthTitle = title
            self?.updateDropdownsUI()
        }
    }
    
    @objc private func hairColorTapped() {
        self.view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.hairColor, dict: appearanceDictionaries?.hairColor, currentId: selectedHairColorId) { [weak self] id, title in
            self?.selectedHairColorId = id
            self?.selectedHairColorTitle = title
            self?.updateDropdownsUI()
        }
    }
    
    @objc private func eyeColorTapped() {
        self.view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.eyeColor, dict: appearanceDictionaries?.eyeColor, currentId: selectedEyeColorId) { [weak self] id, title in
            self?.selectedEyeColorId = id
            self?.selectedEyeColorTitle = title
            self?.updateDropdownsUI()
        }
    }
    
    @objc private func skinColorTapped() {
        self.view.endEditing(true)
        showDictionaryFilter(title: DivoStrings.skinColor, dict: appearanceDictionaries?.skinColor, currentId: selectedSkinColorId) { [weak self] id, title in
            self?.selectedSkinColorId = id
            self?.selectedSkinColorTitle = title
            self?.updateDropdownsUI()
        }
    }
}


// UITextFieldDelegate
extension EditProfileNode: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderWidth = 1.0
        textField.layer.borderColor = UIColor(hexString: "#FF772D")?.cgColor
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderWidth = 0.0
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === nameEventTextField.textField {
            aboutEventTextField.textView.becomeFirstResponder()
        }
        return false
    }

    private func setSelectedIndex(_ index: Int, animated: Bool) {
        guard selectedIndex != index else { return }
        selectedIndex = index
        updatePagerHeight()
        
        let offsetX = CGFloat(index) * (horizontalPager.bounds.width + 32)
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options:[.curveEaseInOut, .allowUserInteraction], animations: {
                self.horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
            })
        } else {
            horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
        }
    }
        
    private func updatePagerHeight() {
        bioStackView.layoutIfNeeded()
        appearanceStackView.layoutIfNeeded()
        experienceStackView.layoutIfNeeded()

        let bioHeight = bioStackView.frame.height
        let appHeight = appearanceStackView.frame.height
        let experienceHeight = experienceStackView.frame.height
        
        var targetHeight = 0.0
        if selectedIndex == 0 {
            targetHeight = bioHeight
        } else if selectedIndex == 1 {
            targetHeight = appHeight
        } else if selectedIndex == 2 {
            targetHeight = experienceHeight
        }

        pagerHeightConstraint.constant = targetHeight
        self.view.layoutIfNeeded()
    }
    
    private func updateIndicatorPosition(progress: CGFloat, animated: Bool = false) {
        guard tabsContainer.bounds.width > 0 else { return }
        
        let segmentWidth = tabsContainer.bounds.width / 3.0
        
        let centerX = (segmentWidth / 2.0) + (segmentWidth * progress)
        
        indicatorCenterXConstraint.constant = centerX
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
                self.tabsContainer.layoutIfNeeded()
            })
        } else {
            self.tabsContainer.layoutIfNeeded()
        }
    }
}

// UIScrollViewDelegate
extension EditProfileNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager, scrollView.bounds.width > 0 else { return }
        
        let progress = scrollView.contentOffset.x / (scrollView.bounds.width + 32)
        updateIndicatorPosition(progress: progress)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager else { return }

        let page = Int(round(scrollView.contentOffset.x / (scrollView.bounds.width + 32)))
        if selectedIndex != page {
            selectedIndex = page
            updatePagerHeight()
        }
    }
}

// <<<<<<< HEAD
// MARK: - UIGestureRecognizerDelegate
extension EditProfileNode: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        return true
// =======

// // MARK: - Helpers

// private func getTextFiel(title: String, isMultiline: Bool = false) -> TextFieldNode {
//     let field = TextFieldNode()
//     field.textField.font = Font.regular(16.0)
//     field.textField.textColor = .white
//     field.textField.textAlignment = .natural
//     field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: DivoColorPalette.overlayDarkFieldBorder)
//     field.textField.autocapitalizationType = .none
//     field.textField.autocorrectionType = .no
//     field.borderWidth = 1.0
//     field.borderColor = DivoColorPalette.overlayDarkFieldBorder.cgColor
//     field.cornerRadius = 11.0
//     field.clipsToBounds = true
//     if isMultiline {
//         field.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
//     } else {
//         field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
// >>>>>>> dev
    }
}
