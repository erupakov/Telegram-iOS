import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI

final class EditProfileNode: ASDisplayNode {
    
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let model: UserDetail?
    var showAlert: ((String) -> Void)?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var navigationBarTitleHeightConstraint: NSLayoutConstraint!
    
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
    
    
    // MARK: - ScrollView
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.translatesAutoresizingMaskIntoConstraints = false
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
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let biographyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(DivoStrings.biography, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(12)
        button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let appearanceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(DivoStrings.appearance, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(12)
        button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 2
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var indicatorCenterXConstraint: NSLayoutConstraint!
    private var indicatorWidthConstraint: NSLayoutConstraint!
    
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
    
    
    // MARK: - Biography UI
    
    private let avatarImageContainerView: UIView = {
        let iv = UIView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.layer.borderWidth = 1
        iv.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 47
        iv.backgroundColor = .systemGray
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let chancePhotoView: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(hexString: "#BF7A54")
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(bundleImageName: "Profile/AddPhotoIcon")
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 16
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
    
    private let nameEventTextField: TextFieldNode
    private let aboutEventTextField: DivoTextView
    
    
    // MARK: - Appearance UI
    
    private let genderDropdown: DropdownNode
    private var ageSlider: AgeSliderNode<Int>
    private let heightSlider: AgeSliderNode<Double>
    private let weightSlider: AgeSliderNode<Double>
    private let waistSlider: AgeSliderNode<Double>
    private let hipsSlider: AgeSliderNode<Double>
    private let shoeSizeSlider: AgeSliderNode<Double>
    private let hairLengthDropdown: DropdownNode
    private let hairColorDropdown: DropdownNode
    private let eyeColorDropdown: DropdownNode
    private let skinColorDropdown: DropdownNode
    
    
    // MARK: - Footer UI
    
    private let applyButton: ASControlNode
    private let applyButtonSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        return spinner
    }()
    private let applyButtonAppearance: ASControlNode
    private let applyButtonAppearanceSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        return spinner
    }()
    
    var currentPhoto: UIImage? = nil {
        didSet {
            avatarImageView.image = currentPhoto
            avatarImageView.applyAvatarTopCropIfNeeded(image: currentPhoto)
        }
    }
    
    
    // MARK: - Init
    
    init(context: AccountContext, presentationData: PresentationData, model: UserDetail?) {
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
            placeholder = DivoStrings.agencyName
            bioTitle = DivoStrings.descriptionTitle
            bio = model?.agency?.description ?? DivoStrings.fillInInfoAboutAgency
            self.biographyButton.setTitle(DivoStrings.description_, for: .normal)
            self.biographyButton.isUserInteractionEnabled = false
        } else {
            name = model?.fullName ?? DivoStrings.name
            placeholder = DivoStrings.fullName
            bioTitle = DivoStrings.biographyTitle
            bio = model?.model?.description ?? DivoStrings.fillInInfoAboutYou
            self.biographyButton.setTitle(DivoStrings.biography, for: .normal)
            self.biographyButton.isUserInteractionEnabled = true
        }
        
        self.nameEventTextField = getTextFiel(title: placeholder)
        self.nameEventTextField.textField.text = name
        // Пока непонятно как обновлять название агенства
        self.nameEventTextField.isUserInteractionEnabled = (model?.role == "agency_employee") ? false : true
        
        self.aboutEventTextField = DivoTextView(title: bioTitle, initialText: bio)

        let currentGender = model?.gender?.title ?? DivoStrings.loading
        self.genderDropdown = DropdownNode(title: DivoStrings.gender, placeholder: DivoStrings.selectGender, options: [currentGender])
        self.genderDropdown.selectedValue = self.model?.gender?.title
        
        self.ageSlider = AgeSliderNode<Int>(
            title: DivoStrings.ageYo,
            type: "y.o",
            mode: .single(value: 17),
            minimumValue: 14,
            maximumValue: 45,
            configuration: .default
        )

        self.heightSlider = AgeSliderNode<Double>(
            title: DivoStrings.heightCm,
            type: "cm",
            mode: .single(value: Float(model?.model?.appearance?.height ?? 1.68)),
            minimumValue: 1.68,
            maximumValue: 2.50,
            configuration: .default
        )

        self.weightSlider = AgeSliderNode<Double>(
            title: DivoStrings.weightKg,
            type: "kg",
            mode: .single(value: Float(model?.model?.appearance?.weight ?? 50)),
            minimumValue: 48,
            maximumValue: 90,
            configuration: .default
        )

        self.waistSlider = AgeSliderNode<Double>(
            title: DivoStrings.waistCm,
            type: "cm",
            mode: .single(value: Float(model?.model?.appearance?.waist ?? 60)),
            minimumValue: 48,
            maximumValue: 90,
            configuration: .default
        )

        self.hipsSlider = AgeSliderNode<Double>(
            title: DivoStrings.hipsCm,
            type: "cm",
            mode: .single(value: Float(model?.model?.appearance?.hips ?? 91)),
            minimumValue: 80,
            maximumValue: 110,
            configuration: .default
        )

        self.shoeSizeSlider = AgeSliderNode<Double>(
            title: DivoStrings.shoeSizeEU,
            type: "",
            mode: .single(value: Float(model?.model?.appearance?.shoesSize ?? 37)),
            minimumValue: 36,
            maximumValue: 42,
            configuration: .default
        )

        let currentHairLength = model?.model?.appearance?.hairLength?.title ?? DivoStrings.loading
        let currentHairColor = model?.model?.appearance?.hairColor?.title ?? DivoStrings.loading
        let currentEyeColor = model?.model?.appearance?.eyeColor?.title ?? DivoStrings.loading
        let currentSkinColor = model?.model?.appearance?.skinColor?.title ?? DivoStrings.loading

        self.hairLengthDropdown = DropdownNode(title: DivoStrings.hairLength, placeholder: DivoStrings.chooseHairLength, options: [currentHairLength])
        self.hairColorDropdown = DropdownNode(title: DivoStrings.hairColor, placeholder: DivoStrings.chooseHairColor, options: [currentHairColor])
        self.eyeColorDropdown = DropdownNode(title: DivoStrings.eyeColor, placeholder: DivoStrings.chooseEyeColor, options: [currentEyeColor])
        self.skinColorDropdown = DropdownNode(title: DivoStrings.skinColor, placeholder: DivoStrings.chooseSkinColor, options: [currentSkinColor])
        
        self.hairLengthDropdown.selectedValue = model?.model?.appearance?.hairLength?.title
        self.hairColorDropdown.selectedValue = model?.model?.appearance?.hairColor?.title
        self.eyeColorDropdown.selectedValue = model?.model?.appearance?.eyeColor?.title
        self.skinColorDropdown.selectedValue = model?.model?.appearance?.skinColor?.title
        
        self.applyButton = ButtonWithIconNode(title: DivoStrings.save, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        self.applyButtonAppearance = ButtonWithIconNode(title: DivoStrings.save, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButtonAppearance.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        
        self.ageSlider = AgeSliderNode<Int>(
            title: "Age (y.o)",
            type: "y.o",
            mode: .single(value: Float(calculateAge(from: model?.birthday ?? ""))),
            minimumValue: 14,
            maximumValue: 45,
            configuration: .default
        )
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
    }
    
    override func didLoad() {
        super.didLoad()
        setupUI()
        
        let avatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.avatarTapped))
        self.avatarImageView.addGestureRecognizer(avatarTapGesture)
        
        self.biographyButton.addTarget(self, action: #selector(biographyTapped), for: .touchUpInside)
        self.appearanceButton.addTarget(self, action: #selector(appearanceTapped), for: .touchUpInside)

        if model?.role == "agency_employee" {
            self.applyButton.addTarget(self, action: #selector(self.saveAgencyButtonPressed), forControlEvents: .touchUpInside)
        } else {
            self.applyButton.addTarget(self, action: #selector(self.saveButtonPressed), forControlEvents: .touchUpInside)
        }

        self.applyButtonAppearance.addTarget(self, action: #selector(self.saveButtonPressed), forControlEvents: .touchUpInside)
        self.chancePhotoView.addTarget(self, action: #selector(self.avatarTapped), for: .touchUpInside)
        
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(dismissTap)

        scrollView.keyboardDismissMode = .interactive

        self.nameEventTextField.textField.returnKeyType = .next
        self.nameEventTextField.textField.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        updateTabsTextColor()
        loadAvatarIfNeeded()

        DispatchQueue.main.async {
            self.updatePagerHeight()
            self.updateIndicatorPosition(progress: 0, animated: false)
            self.readyValue = true
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        navigationBarTitleHeightConstraint.isActive = false
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: navigationBarHeight)
        navigationBarTitleHeightConstraint.isActive = true
        
        DispatchQueue.main.async {
            self.updatePagerHeight()
            self.updateIndicatorPosition(progress: CGFloat(self.selectedIndex), animated: false)
        }
//        self.layoutIfNeeded()
    }

    func configureAppearanceDictionaries(_ dict: AppearanceDictionaryData) {
        self.appearanceDictionaries = dict
        
        self.hairLengthDropdown.options = dict.hairLength.map { $0.title }
        self.hairColorDropdown.options = dict.hairColor.map { $0.title }
        self.eyeColorDropdown.options = dict.eyeColor.map { $0.title }
        self.skinColorDropdown.options = dict.skinColor.map { $0.title }
        
        self.hairLengthDropdown.selectedValue = self.model?.model?.appearance?.hairLength?.title
        self.hairColorDropdown.selectedValue = self.model?.model?.appearance?.hairColor?.title
        self.eyeColorDropdown.selectedValue = self.model?.model?.appearance?.eyeColor?.title
        self.skinColorDropdown.selectedValue = self.model?.model?.appearance?.skinColor?.title
    }
    
    
    func configureGenderDictionaries(_ dict: GenderResponse) {
        self.genderDictionaries = dict
        
        self.genderDropdown.options = dict.data.map { $0.title }
        
        self.genderDropdown.selectedValue = self.model?.gender?.title
    }
    
    private func getAppearanceId(for title: String?, in list: [AppearanceOption]?) -> Int {
        guard let title = title, let list = list else { return 1 }
        return list.first(where: { $0.title == title })?.id ?? 1
    }
    
    private func getGenderId(for title: String?, in list: [GenderOption]?) -> String {
        guard let title = title, let list = list else { return "other" }
        return list.first(where: { $0.title == title })?.id ?? "other"
    }
    
    
    // MARK: - Setup UI (Auto Layout)
    
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
        self.view.addSubview(scrollView)
        scrollView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            // надо тут подмать, как обновлять отступ у scrollView
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 96),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            mainStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            mainStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor)
        navigationBarTitleHeightConstraint.isActive = true
        
        setupTabs()
        setupPager()
    }
    
    private func setupTabs() {
        mainStackView.addArrangedSubview(tabsContainer)
        tabsContainer.heightAnchor.constraint(equalToConstant: 26).isActive = true
        
        if model?.role == "agency_employee" {
            tabsContainer.addSubview(biographyButton)
            tabsContainer.addSubview(indicatorView)
            
            NSLayoutConstraint.activate([
                biographyButton.leadingAnchor.constraint(equalTo: tabsContainer.leadingAnchor),
                biographyButton.topAnchor.constraint(equalTo: tabsContainer.topAnchor),
                biographyButton.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor),
                biographyButton.widthAnchor.constraint(equalTo: tabsContainer.widthAnchor, multiplier: 1.0),
                
                indicatorView.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor),
                indicatorView.heightAnchor.constraint(equalToConstant: 2)
            ])
        } else {
            tabsContainer.addSubview(biographyButton)
            tabsContainer.addSubview(appearanceButton)
            tabsContainer.addSubview(indicatorView)
            
            NSLayoutConstraint.activate([
                biographyButton.leadingAnchor.constraint(equalTo: tabsContainer.leadingAnchor),
                biographyButton.topAnchor.constraint(equalTo: tabsContainer.topAnchor),
                biographyButton.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor),
                biographyButton.widthAnchor.constraint(equalTo: tabsContainer.widthAnchor, multiplier: 0.5),
                
                appearanceButton.trailingAnchor.constraint(equalTo: tabsContainer.trailingAnchor),
                appearanceButton.topAnchor.constraint(equalTo: tabsContainer.topAnchor),
                appearanceButton.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor),
                appearanceButton.widthAnchor.constraint(equalTo: tabsContainer.widthAnchor, multiplier: 0.5),
                
                indicatorView.bottomAnchor.constraint(equalTo: tabsContainer.bottomAnchor),
                indicatorView.heightAnchor.constraint(equalToConstant: 2)
            ])
        }
        
        indicatorCenterXConstraint = indicatorView.centerXAnchor.constraint(equalTo: biographyButton.centerXAnchor)
        indicatorWidthConstraint = indicatorView.widthAnchor.constraint(equalToConstant: 60)
        
        indicatorCenterXConstraint.isActive = true
        indicatorWidthConstraint.isActive = true
    }
    
    private func setupPager() {
        mainStackView.addArrangedSubview(horizontalPager)
        
        pagerHeightConstraint = horizontalPager.heightAnchor.constraint(equalToConstant: 300) // Временная стартовая высота
        pagerHeightConstraint.isActive = true
        
        let contentWidthView = UIView()
        contentWidthView.translatesAutoresizingMaskIntoConstraints = false
        horizontalPager.addSubview(contentWidthView)
        
        contentWidthView.addSubview(bioStackView)
        contentWidthView.addSubview(appearanceStackView)
        
        NSLayoutConstraint.activate([
            contentWidthView.topAnchor.constraint(equalTo: horizontalPager.topAnchor),
            contentWidthView.bottomAnchor.constraint(equalTo: horizontalPager.bottomAnchor),
            contentWidthView.leadingAnchor.constraint(equalTo: horizontalPager.leadingAnchor),
            contentWidthView.trailingAnchor.constraint(equalTo: horizontalPager.trailingAnchor),
            contentWidthView.heightAnchor.constraint(equalTo: horizontalPager.heightAnchor),
            
            bioStackView.leadingAnchor.constraint(equalTo: contentWidthView.leadingAnchor, constant: 16),
            bioStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            bioStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -32),
            
            appearanceStackView.leadingAnchor.constraint(equalTo: bioStackView.trailingAnchor, constant: 32),
            appearanceStackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            appearanceStackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -32),
            appearanceStackView.trailingAnchor.constraint(equalTo: contentWidthView.trailingAnchor, constant: -16)
        ])
        
        setupBioContent()
        setupAppearanceContent()
    }
    
    private func setupBioContent() {
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarContainer.addSubview(avatarImageContainerView)
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(chancePhotoView)
        avatarContainer.addSubview(avatarSpinner)
        
        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 120),
            
            avatarImageContainerView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageContainerView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageContainerView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageContainerView.heightAnchor.constraint(equalToConstant: 100),
            
            avatarImageView.centerXAnchor.constraint(equalTo: avatarImageContainerView.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarImageContainerView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 94),
            avatarImageView.heightAnchor.constraint(equalToConstant: 94),
            
            chancePhotoView.trailingAnchor.constraint(equalTo: avatarImageContainerView.trailingAnchor, constant: 4),
            chancePhotoView.bottomAnchor.constraint(equalTo: avatarImageContainerView.bottomAnchor),
            chancePhotoView.widthAnchor.constraint(equalToConstant: 32),
            chancePhotoView.heightAnchor.constraint(equalToConstant: 32),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor)
        ])
        
        bioStackView.addArrangedSubview(avatarContainer)
        avatarContainer.widthAnchor.constraint(equalTo: bioStackView.widthAnchor).isActive = true
        
        nameEventTextField.view.translatesAutoresizingMaskIntoConstraints = false
        aboutEventTextField.view.translatesAutoresizingMaskIntoConstraints = false
        
        bioStackView.addArrangedSubview(nameEventTextField.view)
        bioStackView.addArrangedSubview(aboutEventTextField.view)
        
        NSLayoutConstraint.activate([
            nameEventTextField.view.widthAnchor.constraint(equalTo: bioStackView.widthAnchor),
            nameEventTextField.view.heightAnchor.constraint(equalToConstant: 48),

            aboutEventTextField.view.widthAnchor.constraint(equalTo: bioStackView.widthAnchor),
            aboutEventTextField.view.heightAnchor.constraint(equalToConstant: 140)
        ])

        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        applyButton.view.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(applyButton.view)
        applyButtonSpinner.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(applyButtonSpinner)

        NSLayoutConstraint.activate([
            applyButton.view.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            applyButton.view.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            applyButton.view.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            applyButton.view.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            applyButton.view.heightAnchor.constraint(equalToConstant: 50),

            applyButtonSpinner.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
            applyButtonSpinner.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
        ])

        bioStackView.addArrangedSubview(buttonContainer)
        buttonContainer.widthAnchor.constraint(equalTo: bioStackView.widthAnchor).isActive = true
    }
    
    private func setupAppearanceContent() {
        let nodes: [ASDisplayNode] = [genderDropdown, ageSlider, heightSlider, weightSlider, waistSlider, hipsSlider, shoeSizeSlider, hairLengthDropdown, hairColorDropdown, eyeColorDropdown, skinColorDropdown]

        for node in nodes {
            node.view.translatesAutoresizingMaskIntoConstraints = false
            appearanceStackView.addArrangedSubview(node.view)
            
            node.view.widthAnchor.constraint(equalTo: appearanceStackView.widthAnchor).isActive = true
            
            if node is DropdownNode {
                node.view.heightAnchor.constraint(equalToConstant: 80).isActive = true
            } else {
                node.view.heightAnchor.constraint(equalToConstant: 80).isActive = true
            }
        }
        
        appearanceStackView.setCustomSpacing(24, after: genderDropdown.view)

        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        applyButtonAppearance.view.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(applyButtonAppearance.view)
        applyButtonAppearanceSpinner.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(applyButtonAppearanceSpinner)

        NSLayoutConstraint.activate([
            applyButtonAppearance.view.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            applyButtonAppearance.view.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            applyButtonAppearance.view.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            applyButtonAppearance.view.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            applyButtonAppearance.view.heightAnchor.constraint(equalToConstant: 50),

            applyButtonAppearanceSpinner.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
            applyButtonAppearanceSpinner.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
        ])

        appearanceStackView.addArrangedSubview(buttonContainer)
        buttonContainer.widthAnchor.constraint(equalTo: appearanceStackView.widthAnchor).isActive = true
    }
    
    
    // MARK: - Keyboard

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let keyboardHeight = keyboardFrame.height
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight

        UIView.animate(withDuration: duration) {
            if self.aboutEventTextField.textView.isFirstResponder {
                let fieldFrame = self.aboutEventTextField.view.convert(self.aboutEventTextField.bounds, to: self.scrollView)
                self.scrollView.scrollRectToVisible(fieldFrame, animated: false)
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = 0
            self.scrollView.verticalScrollIndicatorInsets.bottom = 0
        }
    }

    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }

    // MARK: - Actions

    @objc private func avatarTapped() {
        print("Change photo")
        onAvatarTap?()
    }
    
    @objc private func biographyTapped() {
        setSelectedIndex(0, animated: true)
    }
    
    @objc private func appearanceTapped() {
        setSelectedIndex(1, animated: true)
    }
    
    @objc private func updateAccountPeerName() {
        print("Save button tapped")
    }
    
    @objc private func saveButtonPressed() {
        let genderId = getGenderId(for: self.genderDropdown.selectedValue, in: genderDictionaries?.data)
        
        let hairLengthId = getAppearanceId(for: self.hairLengthDropdown.selectedValue, in: appearanceDictionaries?.hairLength)
        let hairColorId = getAppearanceId(for: self.hairColorDropdown.selectedValue, in: appearanceDictionaries?.hairColor)
        let eyeColorId = getAppearanceId(for: self.eyeColorDropdown.selectedValue, in: appearanceDictionaries?.eyeColor)
        let skinColorId = getAppearanceId(for: self.skinColorDropdown.selectedValue, in: appearanceDictionaries?.skinColor)
        
        let data = UpdateBiographyPageRequest(
            fullName: self.nameEventTextField.textField.text ?? "",
            gender: genderId,
            model: UpdateBiographyPageRequest.ModelData(
                description: self.aboutEventTextField.text,
                appearance: Appearance(
                    measuringSystem: "metric",
                    height: self.heightSlider.currentValue,
                    weight: self.weightSlider.currentValue,
                    breastSize: "",
                    waist: self.waistSlider.currentValue,
                    hips: self.hipsSlider.currentValue,
                    shoesSize: self.shoeSizeSlider.currentValue,
                    hairColor: hairColorId,
                    hairLength: hairLengthId,
                    eyeColor: eyeColorId,
                    skinColor: skinColorId
                )
            )
        )
        
        self.toggleSpinner(active: true)
        self.saveProfile?(data)
    }

    @objc private func saveAgencyButtonPressed() {
        let data = UpdateDescriptionAgencyRequest(
            agencyId: model?.agency?.id,
            description: self.aboutEventTextField.text
        )
            
        self.toggleSpinner(active: true)
        self.saveAgencyProfile?(data)
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
        if active {
            self.applyButtonSpinner.startAnimating()
            self.applyButton.alpha = 0.0
            self.applyButtonAppearanceSpinner.startAnimating()
            self.applyButtonAppearance.alpha = 0.0
        } else {
            self.applyButtonSpinner.stopAnimating()
            self.applyButton.alpha = 1.0
            self.applyButtonAppearanceSpinner.stopAnimating()
            self.applyButtonAppearance.alpha = 1.0
        }
    }
}


// UITextFieldDelegate
extension EditProfileNode: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === nameEventTextField.textField {
            aboutEventTextField.textView.becomeFirstResponder()
        }
        return false
    }

    private func setSelectedIndex(_ index: Int, animated: Bool) {
        guard selectedIndex != index else { return }
        selectedIndex = index
        updateTabsTextColor()
        updatePagerHeight()

        let offsetX = CGFloat(index) * horizontalPager.bounds.width

        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
            })
        } else {
            horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
        }
    }
    
    private func updateTabsTextColor() {
        let selectedColor: UIColor = .white
        let unselectedColor: UIColor = .white.withAlphaComponent(0.6)
        
        biographyButton.setTitleColor(selectedIndex == 0 ? selectedColor : unselectedColor, for: .normal)
        appearanceButton.setTitleColor(selectedIndex == 1 ? selectedColor : unselectedColor, for: .normal)
    }
    
    private func updatePagerHeight() {
        bioStackView.layoutIfNeeded()
        appearanceStackView.layoutIfNeeded()

        let bioHeight = bioStackView.frame.height
        let appHeight = appearanceStackView.frame.height

        let targetHeight = selectedIndex == 0 ? bioHeight : appHeight

        pagerHeightConstraint.constant = targetHeight
        self.view.layoutIfNeeded()
    }
    
    private func updateIndicatorPosition(progress: CGFloat, animated: Bool = false) {
        guard let bioTitle = biographyButton.titleLabel?.text, let appTitle = appearanceButton.titleLabel?.text else { return }
        
        let font = Font.helveticaNeue(12)
        let bioWidth = (bioTitle as NSString).size(withAttributes: [.font: font]).width
        let appWidth = (appTitle as NSString).size(withAttributes: [.font: font]).width
        
        let currentWidth = bioWidth + (appWidth - bioWidth) * progress
        indicatorWidthConstraint.constant = currentWidth
        
        let halfWidth = tabsContainer.bounds.width / 2.0
        let center0 = halfWidth / 2.0
        let center1 = halfWidth + (halfWidth / 2.0)
        
        indicatorCenterXConstraint.constant = (center1 - center0) * progress
        
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.tabsContainer.layoutIfNeeded()
            }
        } else {
            self.tabsContainer.layoutIfNeeded()
        }
    }
}

// UIScrollViewDelegate
extension EditProfileNode: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager, scrollView.bounds.width > 0 else { return }
        
        let progress = scrollView.contentOffset.x / scrollView.bounds.width
        updateIndicatorPosition(progress: progress)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == horizontalPager else { return }

        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        if selectedIndex != page {
            selectedIndex = page
            updateTabsTextColor()
            updatePagerHeight()
        }
    }
}


// MARK: - Helpers

private func getTextFiel(title: String, isMultiline: Bool = false) -> TextFieldNode {
    let field = TextFieldNode()
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = .white
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    field.borderWidth = 1.0
    field.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
    field.cornerRadius = 11.0
    field.clipsToBounds = true
    if isMultiline {
        field.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    } else {
        field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    return field
}
