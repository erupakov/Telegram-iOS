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

final class AddModelNode: ASDisplayNode {
    
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()

    var showAlert: ((String) -> Void)?
    var onExitTapped: (() -> Void)?
    
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
    var onAvatarTap: (() -> Void)?
    
    private var currentStep: Int = 1
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var horizontalPager: UIScrollView = {
        let sv = UIScrollView()
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.clipsToBounds = false
        sv.isScrollEnabled = false
        return sv
    }()
    
    private var pagerHeightConstraint: NSLayoutConstraint!
    
    private let stap1StackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let stap2StackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let headerTitleLabel: PaddedLabel = { 
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0) 
        label.font = Font.helveticaNeue(34)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let headerSubtitleLabel: PaddedLabel = { 
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0) 
        label.font = Font.helveticaNeue(16)
        label.textColor = .white.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let parametersSubtitleNode: PaddedLabel = { 
        let label = PaddedLabel()
        label.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0) 
        label.font = Font.helveticaNeue(20)
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let addAvatarIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .clear
        iv.isUserInteractionEnabled = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(bundleImageName: "Avatar/AddAvatarIconLarge")
        return iv
    }()

    private lazy var avatarImageContainerView: UIView = {
        let iv = UIView()
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 50
        iv.layer.borderWidth = 1
        iv.layer.borderColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0).cgColor
        iv.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        
        iv.addSubview(addAvatarIconView)
        
        NSLayoutConstraint.activate([
            addAvatarIconView.centerXAnchor.constraint(equalTo: iv.centerXAnchor),
            addAvatarIconView.centerYAnchor.constraint(equalTo: iv.centerYAnchor),
            addAvatarIconView.heightAnchor.constraint(equalToConstant: 54),
            addAvatarIconView.widthAnchor.constraint(equalToConstant: 54)
        ])
        
        return iv
    }()
    
    private let avatarImageView: UIImageView = {
        let image = UIImageView()
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.layer.cornerRadius = 50
        image.backgroundColor = .clear
        image.isUserInteractionEnabled = true
        image.translatesAutoresizingMaskIntoConstraints = false
        return image
    }()

    private let avatarSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private let fullNameModelTextField: TextFieldNode
    private let chooseCountryField: TextFieldNodeWithChevron
    private var countryId: String = ""
    private let linkModelTextField: TextFieldNode
        
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
    
    private let backNode: ButtonWithIconNode
    private let nextNode: ButtonWithIconNode
    private let saveNode: ButtonWithIconNode
    private let saveSpinner = UIActivityIndicatorView(style: .medium)
    
    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                avatarImageView.image = currentPhoto
                addAvatarIconView.isHidden = true
            } else {
                avatarImageView.image = nil
                addAvatarIconView.isHidden = false
            }
        }
    }
    
    var selectCountryCode: (() -> Void)?
    

    // MARK: - Init
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context

        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)

        self.fullNameModelTextField = getTextField(title: DivoStrings.fullName)
        
        self.linkModelTextField = getTextField(title: DivoStrings.linkModel)
        
        self.chooseCountryField = getChevronTextField(title: DivoStrings.chooseCountry)

        let currentGender = DivoStrings.loading
        self.genderDropdown = DropdownNode(title: DivoStrings.gender, placeholder:  DivoStrings.selectGender, options: [currentGender])

        self.ageSlider = AgeSliderNode(title: DivoStrings.ageYo, type: "y.o", defaultValue: 17, minimumValue: 14, maximumValue: 45)
        self.heightSlider = AgeSliderNode(title: DivoStrings.heightCm, type: "cm", defaultValue: 1.68, minimumValue: 1.68, maximumValue: 2.50)
        self.weightSlider = AgeSliderNode(title: DivoStrings.weightKg, type: "kg", defaultValue: 50, minimumValue: 48, maximumValue: 90)
        self.waistSlider = AgeSliderNode(title: DivoStrings.waistCm, type: "cm", defaultValue: 60, minimumValue: 48, maximumValue: 90)
        self.hipsSlider = AgeSliderNode(title: DivoStrings.hipsCm, type: "cm", defaultValue: 91, minimumValue: 80, maximumValue: 110)
        self.shoeSizeSlider = AgeSliderNode(title: DivoStrings.shoeSizeEU, type: "", defaultValue: 37, minimumValue: 36, maximumValue: 42)        

        self.hairLengthDropdown = DropdownNode(title:DivoStrings.hairLength, placeholder: DivoStrings.chooseHairLength, options: [])
        self.hairColorDropdown = DropdownNode(title: DivoStrings.hairColor, placeholder: DivoStrings.chooseHairColor, options: [])
        self.eyeColorDropdown = DropdownNode(title: DivoStrings.eyeColor, placeholder: DivoStrings.chooseEyeColor, options: [])
        self.skinColorDropdown = DropdownNode(title: DivoStrings.skinColor, placeholder: DivoStrings.chooseSkinColor, options:[])
        
        // Инициализация фиксированных кнопок
        let backIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: .white)
        let imageSize = CGSize(width: 16, height: 12)
        
        self.backNode = ButtonWithIconNode(title: DivoStrings.back, icon: backIcon, theme: presentationData.theme, spacing: 10, imageSize: imageSize)
        self.backNode.backgroundColor = UIColor(hexString: "#343434")
        
        self.nextNode = ButtonWithIconNode(title: DivoStrings.nextStep, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: imageSize)
        self.nextNode.backgroundColor = UIColor(hexString: "#BF7A54")
        
        self.saveNode = ButtonWithIconNode(title: DivoStrings.save, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: imageSize)
        self.saveNode.backgroundColor = UIColor(hexString: "#BF7A54")
        self.saveNode.isHidden = true
        
        super.init()
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)

        headerTitleLabel.text = DivoStrings.titleAddModel
        headerSubtitleLabel.text = DivoStrings.subTitleAddModel
        parametersSubtitleNode.text = DivoStrings.parametersAddModel.uppercased()
    }
    
    override func didLoad() {
        super.didLoad()
        setupUI()
        
        let avatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.avatarTapped))
        self.avatarImageView.addGestureRecognizer(avatarTapGesture)
        
        self.backNode.addTarget(self, action: #selector(backButtonPressed), forControlEvents: .touchUpInside)
        self.nextNode.addTarget(self, action: #selector(nextStepTapped), forControlEvents: .touchUpInside)
        
        self.saveNode.addTarget(self, action: #selector(self.saveButtonPressed), forControlEvents: .touchUpInside)
        
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(dismissTap)

        scrollView.keyboardDismissMode = .interactive

        self.fullNameModelTextField.textField.returnKeyType = .next
        self.fullNameModelTextField.textField.delegate = self
        
        self.linkModelTextField.textField.returnKeyType = .next
        self.linkModelTextField.textField.delegate = self
        
        self.chooseCountryField.textField.textField.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        loadAvatarIfNeeded()

        DispatchQueue.main.async {
            self.updatePagerHeight()
            self.readyValue = true
        }
    }


    // MARK: - Internal
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        navigationBarTitleHeightConstraint.isActive = false
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: navigationBarHeight)
        navigationBarTitleHeightConstraint.isActive = true
        
        DispatchQueue.main.async {
            self.updatePagerHeight()
        }
    }

    func configureAppearanceDictionaries(_ dict: AppearanceDictionaryData) {
        self.appearanceDictionaries = dict
        self.hairLengthDropdown.options = dict.hairLength.map { $0.title }
        self.hairColorDropdown.options = dict.hairColor.map { $0.title }
        self.eyeColorDropdown.options = dict.eyeColor.map { $0.title }
        self.skinColorDropdown.options = dict.skinColor.map { $0.title }
    }
    
    func configureGenderDictionaries(_ dict: GenderResponse) {
        self.genderDictionaries = dict
        self.genderDropdown.options = dict.data.map { $0.title }
    }
    
    func updateCountry(countryId: String, countryName: String) {
        chooseCountryField.textField.textField.text = countryName
        self.countryId = countryId
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
            self.saveSpinner.startAnimating()
            self.saveNode.alpha = 0.5
            self.saveNode.isUserInteractionEnabled = false
        } else {
            self.saveSpinner.stopAnimating()
            self.saveNode.alpha = 1.0
            self.saveNode.isUserInteractionEnabled = true
        }
    }

    func showStep1() {
        currentStep = 1
        nextNode.isHidden = false
        saveNode.isHidden = true
        updatePagerHeight()
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.horizontalPager.contentOffset = .zero
        })
    }
    
    func showStep2() {
        currentStep = 2
        nextNode.isHidden = true
        saveNode.isHidden = false
        updatePagerHeight()
        
        let offsetX = horizontalPager.bounds.width
        UIView.animate(withDuration: 0.3, delay: 0, options:[.curveEaseInOut, .allowUserInteraction], animations: {
            self.horizontalPager.contentOffset = CGPoint(x: offsetX, y: 0)
        })
    }


    // MARK: - Private
    
    private func getAppearanceId(for title: String?, in list: [AppearanceOption]?) -> Int {
        guard let title = title, let list = list else { return 1 }
        return list.first(where: { $0.title == title })?.id ?? 1
    }
    
    private func getGenderId(for title: String?, in list: [GenderOption]?) -> String {
        guard let title = title, let list = list else { return "other" }
        return list.first(where: { $0.title == title })?.id ?? "other"
    }
    
    private func setupUI() {
        self.view.addSubview(scrollView)
        scrollView.addSubview(mainStackView)
        
        self.addSubnode(backNode)
        self.addSubnode(nextNode)
        self.addSubnode(saveNode)
        
        backNode.view.translatesAutoresizingMaskIntoConstraints = false
        nextNode.view.translatesAutoresizingMaskIntoConstraints = false
        saveNode.view.translatesAutoresizingMaskIntoConstraints = false
        
        saveSpinner.translatesAutoresizingMaskIntoConstraints = false
        saveNode.view.addSubview(saveSpinner)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            mainStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            mainStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            backNode.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            backNode.view.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            backNode.view.heightAnchor.constraint(equalToConstant: 50),
            
            nextNode.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            nextNode.view.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            nextNode.view.heightAnchor.constraint(equalToConstant: 50),
            nextNode.view.leadingAnchor.constraint(equalTo: backNode.view.trailingAnchor, constant: 12),
            nextNode.view.widthAnchor.constraint(equalTo: backNode.view.widthAnchor),
            
            saveNode.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            saveNode.view.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: 0),
            saveNode.view.heightAnchor.constraint(equalToConstant: 50),
            saveNode.view.leadingAnchor.constraint(equalTo: backNode.view.trailingAnchor, constant: 12),
            saveNode.view.widthAnchor.constraint(equalTo: backNode.view.widthAnchor),
            
            saveSpinner.centerXAnchor.constraint(equalTo: saveNode.view.centerXAnchor),
            saveSpinner.centerYAnchor.constraint(equalTo: saveNode.view.centerYAnchor)
        ])
        
        scrollView.contentInset.top = 90
        scrollView.contentInset.bottom = 90
        scrollView.verticalScrollIndicatorInsets.bottom = 90
        
        navigationBarTitleHeightConstraint = scrollView.topAnchor.constraint(equalTo: self.view.topAnchor)
        navigationBarTitleHeightConstraint.isActive = true
        
        setupPager()
    }
    
    private func setupPager() {
        mainStackView.addArrangedSubview(horizontalPager)
        
        pagerHeightConstraint = horizontalPager.heightAnchor.constraint(equalToConstant: 500)
        pagerHeightConstraint.isActive = true
        
        let contentWidthView = UIView()
        contentWidthView.translatesAutoresizingMaskIntoConstraints = false
        horizontalPager.addSubview(contentWidthView)
        
        contentWidthView.addSubview(stap1StackView)
        contentWidthView.addSubview(stap2StackView)
        
        NSLayoutConstraint.activate([
            contentWidthView.topAnchor.constraint(equalTo: horizontalPager.topAnchor),
            contentWidthView.bottomAnchor.constraint(equalTo: horizontalPager.bottomAnchor),
            contentWidthView.leadingAnchor.constraint(equalTo: horizontalPager.leadingAnchor),
            contentWidthView.trailingAnchor.constraint(equalTo: horizontalPager.trailingAnchor),
            contentWidthView.heightAnchor.constraint(equalTo: horizontalPager.heightAnchor),
            
            stap1StackView.leadingAnchor.constraint(equalTo: contentWidthView.leadingAnchor, constant: 16),
            stap1StackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor, constant: 100),
            stap1StackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -32),
            
            stap2StackView.leadingAnchor.constraint(equalTo: stap1StackView.trailingAnchor, constant: 32),
            stap2StackView.topAnchor.constraint(equalTo: contentWidthView.topAnchor),
            stap2StackView.widthAnchor.constraint(equalTo: horizontalPager.widthAnchor, constant: -32),
            stap2StackView.trailingAnchor.constraint(equalTo: contentWidthView.trailingAnchor, constant: -16)
        ])
        
        setupStep1Content()
        setupStap2Content()
    }
    
    private func setupStep1Content() {
        let avatarContainer = UIView()
        avatarContainer.translatesAutoresizingMaskIntoConstraints = false
        
        avatarContainer.addSubview(avatarImageContainerView)
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(avatarSpinner)
        
        NSLayoutConstraint.activate([
            avatarContainer.heightAnchor.constraint(equalToConstant: 120),
            
            avatarImageContainerView.centerXAnchor.constraint(equalTo: avatarContainer.centerXAnchor),
            avatarImageContainerView.topAnchor.constraint(equalTo: avatarContainer.topAnchor),
            avatarImageContainerView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageContainerView.heightAnchor.constraint(equalToConstant: 100),
            
            avatarImageView.centerXAnchor.constraint(equalTo: avatarImageContainerView.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarImageContainerView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),
            
            avatarSpinner.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarSpinner.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor)
        ])

        stap1StackView.addArrangedSubview(headerTitleLabel)
        stap1StackView.addArrangedSubview(headerSubtitleLabel)
        
        stap1StackView.addArrangedSubview(avatarContainer)
        avatarContainer.widthAnchor.constraint(equalTo: stap1StackView.widthAnchor).isActive = true
        
        fullNameModelTextField.view.translatesAutoresizingMaskIntoConstraints = false
        chooseCountryField.view.translatesAutoresizingMaskIntoConstraints = false
        linkModelTextField.view.translatesAutoresizingMaskIntoConstraints = false
        
        stap1StackView.addArrangedSubview(fullNameModelTextField.view)
        stap1StackView.addArrangedSubview(chooseCountryField.view)
        stap1StackView.addArrangedSubview(linkModelTextField.view)
        
        NSLayoutConstraint.activate([
            fullNameModelTextField.view.widthAnchor.constraint(equalTo: stap1StackView.widthAnchor),
            fullNameModelTextField.view.heightAnchor.constraint(equalToConstant: 48),
            
            chooseCountryField.view.widthAnchor.constraint(equalTo: stap1StackView.widthAnchor),
            chooseCountryField.view.heightAnchor.constraint(equalToConstant: 48),
            
            linkModelTextField.view.widthAnchor.constraint(equalTo: stap1StackView.widthAnchor),
            linkModelTextField.view.heightAnchor.constraint(equalToConstant: 48),
        ])
    }
    
    private func setupStap2Content() {
        let nodes: [ASDisplayNode] = [genderDropdown, ageSlider, heightSlider, weightSlider, waistSlider, hipsSlider, shoeSizeSlider, hairLengthDropdown, hairColorDropdown, eyeColorDropdown, skinColorDropdown]

        stap2StackView.addArrangedSubview(parametersSubtitleNode)
        
        for node in nodes {
            node.view.translatesAutoresizingMaskIntoConstraints = false
            stap2StackView.addArrangedSubview(node.view)
            
            node.view.widthAnchor.constraint(equalTo: stap2StackView.widthAnchor).isActive = true
            
            if node is ASTextNode {
                node.view.heightAnchor.constraint(equalToConstant: 24).isActive = true
            } else {
                node.view.heightAnchor.constraint(equalToConstant: 80).isActive = true
            }
        }
        stap2StackView.setCustomSpacing(10, after: parametersSubtitleNode)
        stap2StackView.setCustomSpacing(24, after: genderDropdown.view)
    }
   
    private func loadAvatarIfNeeded() {

    }
    
    private func updatePagerHeight() {
        stap1StackView.layoutIfNeeded()
        stap2StackView.layoutIfNeeded()

        let step1Height = stap1StackView.frame.height + 100
        let step2Height = stap2StackView.frame.height

        let targetHeight = currentStep == 1 ? step1Height : step2Height

        pagerHeightConstraint.constant = targetHeight
        self.view.layoutIfNeeded()
    }
    
    
    // MARK: - objc

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let keyboardHeight = keyboardFrame.height
        scrollView.contentInset.bottom = keyboardHeight + 90
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight + 90

        UIView.animate(withDuration: duration) {
            if self.linkModelTextField.textField.isFirstResponder {
                let fieldFrame = self.linkModelTextField.view.convert(self.linkModelTextField.bounds, to: self.scrollView)
                self.scrollView.scrollRectToVisible(fieldFrame, animated: false)
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = 90
            self.scrollView.verticalScrollIndicatorInsets.bottom = 90
        }
    }

    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }

    
    // MARK: - Actions

    @objc private func avatarTapped() {
        onAvatarTap?()
    }
    
    @objc private func backButtonPressed() {
        if currentStep == 2 {
            showStep1()
        } else {
            onExitTapped?()
        }
    }
    
    @objc private func nextStepTapped() {
        showStep2()
    }
    
    @objc private func saveButtonPressed() {
        let genderId = getGenderId(for: self.genderDropdown.selectedValue, in: genderDictionaries?.data)
        
        let hairLengthId = getAppearanceId(for: self.hairLengthDropdown.selectedValue, in: appearanceDictionaries?.hairLength)
        let hairColorId = getAppearanceId(for: self.hairColorDropdown.selectedValue, in: appearanceDictionaries?.hairColor)
        let eyeColorId = getAppearanceId(for: self.eyeColorDropdown.selectedValue, in: appearanceDictionaries?.eyeColor)
        let skinColorId = getAppearanceId(for: self.skinColorDropdown.selectedValue, in: appearanceDictionaries?.skinColor)
        
        let data = UpdateBiographyPageRequest(
            fullName: self.fullNameModelTextField.textField.text ?? "",
            gender: genderId,
            model: UpdateBiographyPageRequest.ModelData(
                description: self.linkModelTextField.textField.text,
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

    }
}

// UITextFieldDelegate
extension AddModelNode: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === fullNameModelTextField.textField {
            fullNameModelTextField.textField.becomeFirstResponder()
        } else if textField === linkModelTextField.textField {
            linkModelTextField.textField.becomeFirstResponder()
        }
        return false
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == chooseCountryField.textField.textField {
            selectCountryCode?()
            return false
        } else {
            return true
        }
    }
}


// MARK: - Helpers

private func roundCorners(diameter: CGFloat) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}

private func getTextField(title: String) -> TextFieldNode {
    let field = TextFieldNode()
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = .white
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    field.borderWidth = 1.0
    field.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
    field.cornerRadius = 10.0
    field.clipsToBounds = true
    field.padding = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)

    return field
}

private func getChevronTextField(title: String) -> TextFieldNodeWithChevron {
    let field = TextFieldNodeWithChevron()
    field.textField.textField.font = Font.regular(16.0)
    field.textField.textField.textColor = .white
    field.textField.textField.textAlignment = .natural
    field.textField.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.textField.autocapitalizationType = .none
    field.textField.textField.autocorrectionType = .no
    field.borderWidth = 1.0
    field.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
    field.cornerRadius = 10.0
    field.clipsToBounds = true
    field.padding = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)

    return field
}

class TextFieldNodeWithChevron: ASDisplayNode {
    let textField: TextFieldNode
    private let chevronNode: ASImageNode

    override init() {
        self.textField = TextFieldNode()
        self.chevronNode = ASImageNode()
        self.chevronNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/InlineTextDownArrow"), color: UIColor.white)
        self.chevronNode.contentMode = .scaleAspectFit
        self.chevronNode.isUserInteractionEnabled = false

        super.init()

        self.addSubnode(self.textField)
        self.addSubnode(self.chevronNode)
    }

    var padding: UIEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) {
        didSet {
            self.textField.padding = self.padding
        }
    }

    override func layout() {
        super.layout()

        self.textField.frame = self.bounds

        let chevronSize = CGSize(width: 20, height: 20)
        let padding: CGFloat = 16.0
        self.chevronNode.frame = CGRect(
            x: self.bounds.width - padding - chevronSize.width,
            y: (self.bounds.height - chevronSize.height) / 2,
            width: chevronSize.width,
            height: chevronSize.height
        )
    }
}