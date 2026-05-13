import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramBaseController
import TelegramCore
import AppBundle
import DivoCore
import DivoUIKit

struct MeasuringOption {
    let id: String
    let title: String
}

// MARK: - Screen Load Phase
enum ScreenLoadPhase: Equatable {
    case loading
    case ready
    case failed
}

final class DivoSettingsNode: ASDisplayNode {
    
    private let context: AccountContext
    
    // Стейт экрана
    private var screenPhase: ScreenLoadPhase = .loading {
        didSet { if oldValue != screenPhase { applyState() } }
    }
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()
    
    private let contentViewStack: UIStackView = {
        let contentViewStack = UIStackView()
        contentViewStack.translatesAutoresizingMaskIntoConstraints = false
        contentViewStack.axis = .vertical
        contentViewStack.spacing = DivoDesignTokens.Spacing.m
        return contentViewStack
    }()
    
    private let navigationBar = DivoNavigationBar()

    // Profile section
    private let profileContainer = UIView()
    private let profileHeader = HeaderSettingsView()
    
    // Shimmer для Profile section
    private let profileShimmerView = HeaderSettingsShimmerView()

    // Set Username section
    private let usernameContainer = SettingsRowView(icon: DivoImage.settingsSetUsername, title: DivoStrings.settingsSetUsername, isLast: false)
    private let parametersContainer = SettingsRowView(icon: DivoImage.settingsParameters, title: DivoStrings.fillYourParameters, isLast: true)
    
    private let parametersUsernameStackContainer = UIView() // Контейнер для секции Username+Parameters

    // Promo banner
    private let bannerOuterContainer: UIView = {
        let bannerOuterContainer = UIView()
        bannerOuterContainer.translatesAutoresizingMaskIntoConstraints = false
        return bannerOuterContainer
    }()
    
    private let bannerView: BannerView = {
        let bannerView = BannerView()
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        return bannerView
    }()
    
    private let savedMessagesStackContainer = UIView()
    private let savedMessagesContainer = SettingsRowView(icon: DivoImage.settingsSavedMessages.withRenderingMode(.alwaysTemplate), title: DivoStrings.savedMessages, isLast: true)
    
    private let mainSettingsStackContainer = UIView()
    private let notificationsSoundsContainer = SettingsRowView(icon: DivoImage.settingsNotifications.withRenderingMode(.alwaysTemplate), title: DivoStrings.notificationsSounds, isLast: false)
    private let privacySecurityContainer = SettingsRowView(icon: DivoImage.settingsPrivacy.withRenderingMode(.alwaysTemplate), title: DivoStrings.privacySecurity, isLast: false)
    private let dataStorageContainer = SettingsRowView(icon: DivoImage.settingsData.withRenderingMode(.alwaysTemplate), title: DivoStrings.dataStorage, isLast: false)
    private let languageContainer = SettingsRowView(icon: DivoImage.settingsLanguage.withRenderingMode(.alwaysTemplate), title: DivoStrings.language, isLast: false)
    private let measuringSystemContainer = SettingsRowView(icon: UIImage(systemName: "scalemass.fill")!.withRenderingMode(.alwaysTemplate), title: DivoStrings.measuringSystem, isLast: true)

    private let logOutStackContainer = UIView()
    private let logOutContainer = SettingsRowView(icon: DivoImage.settingsLogOut.withRenderingMode(.alwaysTemplate), title: DivoStrings.logOut, isLast: true)

    var onProfileTapped: (() -> Void)?
    var onSetUsernameTapped: (() -> Void)?
    var onFillParametersTapped: (() -> Void)?
    var onLearnMoreTapped: (() -> Void)?
    var presentController: ((UIViewController) -> Void)?

    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var selectedMeasuringSystemId: String?
    private var selectedMeasuringSystemTitle: String?
    private let measuringSystem: [MeasuringOption] = [
        MeasuringOption(id: "metric", title: "Metric"),
        MeasuringOption(id: "imperial", title: "Imperial"),
    ]

    init(context: AccountContext) {
        self.context = context
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
        
        navigationBar.makeNavigationBar(
            title: DivoStrings.settings,
            font: Font.helveticaNeue(20),
            backButtonConfiguration: .circle(DivoImage.qrCode),
            rightButtonConfiguration: .text(DivoStrings.settingsEdit),
            onBackTapped: {  },
            onCircleTextTapped: { [weak self] in self?.onProfileTapped?() }
        )
        
        measuringSystemContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(measuringSystemTapped)))
        
        setupCustomNavBar()
        setupUI()
        
        // Начальное состояние
        applyState()
    }

    override func layout() {
        super.layout()
        if screenPhase == .loading {
            profileShimmerView.startAnimation() // Предполагается, что у вас есть расширение startShimmering()
        }
    }

    // MARK: - State Management
    
    private func applyState() {
        switch screenPhase {
        case .loading, .failed:
            // Блокируем взаимодействие
            scrollView.isScrollEnabled = false
            
            // Показываем шиммер профиля, прячем реальный контент профиля
            profileShimmerView.isHidden = false
            profileHeader.isHidden = true
            
            // Настройки можно оставить видимыми, но некликабельными, либо тоже спрятать
            // Я делаю их полупрозрачными и неактивными, как скелетон
            parametersUsernameStackContainer.alpha = 0.5
            parametersUsernameStackContainer.isUserInteractionEnabled = false
            
            bannerOuterContainer.alpha = 0.5
            bannerOuterContainer.isUserInteractionEnabled = false
            
            savedMessagesStackContainer.alpha = 0.5
            savedMessagesStackContainer.isUserInteractionEnabled = false
            
            mainSettingsStackContainer.alpha = 0.5
            mainSettingsStackContainer.isUserInteractionEnabled = false
            
            logOutStackContainer.alpha = 0.5
            logOutStackContainer.isUserInteractionEnabled = false
            
            if screenPhase == .loading {
                profileShimmerView.startAnimation()
            }
            
        case .ready:
            UIView.animate(withDuration: 0.3) {
                // Разблокируем взаимодействие
                self.scrollView.isScrollEnabled = true
                
                // Прячем шиммер, показываем контент
                self.profileShimmerView.isHidden = true
                self.profileShimmerView.stopAnimation()
                self.profileHeader.isHidden = false
                
                // Возвращаем нормальный вид настройкам
                self.parametersUsernameStackContainer.alpha = 1.0
                self.parametersUsernameStackContainer.isUserInteractionEnabled = true
                
                self.bannerOuterContainer.alpha = 1.0
                self.bannerOuterContainer.isUserInteractionEnabled = true
                
                self.savedMessagesStackContainer.alpha = 1.0
                self.savedMessagesStackContainer.isUserInteractionEnabled = true
                
                self.mainSettingsStackContainer.alpha = 1.0
                self.mainSettingsStackContainer.isUserInteractionEnabled = true
                
                self.logOutStackContainer.alpha = 1.0
                self.logOutStackContainer.isUserInteractionEnabled = true
            }
        }
    }
    

    // MARK: - Setup
    
    private func setupCustomNavBar() {
        view.addSubview(navigationBar)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 62),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentViewStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentViewStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentViewStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentViewStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentViewStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentViewStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        setupProfileSection()
        setupUsernameParametersSection()
        // Добавление баннера пока убрано
        // setupBannerSection()
        setupSavedMessagesSection()
        setupMainSection()
        setupLogOutSection()

        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        bottomSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        contentViewStack.addArrangedSubview(bottomSpacer)
    }

    private func setupProfileSection() {
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        profileContainer.backgroundColor = DivoColorPalette.screenBackground
        let profileTap = UITapGestureRecognizer(target: self, action: #selector(profileTapped))
        profileContainer.addGestureRecognizer(profileTap)

        profileContainer.addSubview(profileHeader)
        profileHeader.translatesAutoresizingMaskIntoConstraints = false
        
        profileContainer.addSubview(profileShimmerView)
        profileShimmerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            profileContainer.heightAnchor.constraint(equalToConstant: 152),

            profileHeader.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor),
            profileHeader.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor),
            profileHeader.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            profileHeader.topAnchor.constraint(equalTo: profileContainer.topAnchor),
            
            profileShimmerView.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            profileShimmerView.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            profileShimmerView.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            profileShimmerView.topAnchor.constraint(equalTo: profileContainer.topAnchor, constant: 12),
            profileShimmerView.heightAnchor.constraint(equalToConstant: 152),
        ])

        contentViewStack.addArrangedSubview(profileContainer)
        contentViewStack.setCustomSpacing(24, after: profileContainer)
    }

    private func setupUsernameParametersSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(usernameContainer)
        stackContainer.addArrangedSubview(parametersContainer)
        parametersContainer.isHidden = true
        usernameContainer.setSeparator(true)
        
        let whiteContainer = UIView()
        whiteContainer.translatesAutoresizingMaskIntoConstraints = false
        whiteContainer.layer.cornerRadius = DivoDesignTokens.Radius.pill
        whiteContainer.backgroundColor = DivoColorPalette.cardBackground
        whiteContainer.addSubview(stackContainer)
        
        parametersUsernameStackContainer.translatesAutoresizingMaskIntoConstraints = false
        parametersUsernameStackContainer.addSubview(whiteContainer)
        
        NSLayoutConstraint.activate([
            whiteContainer.leadingAnchor.constraint(equalTo: parametersUsernameStackContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            whiteContainer.trailingAnchor.constraint(equalTo: parametersUsernameStackContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            whiteContainer.bottomAnchor.constraint(equalTo: parametersUsernameStackContainer.bottomAnchor),
            whiteContainer.topAnchor.constraint(equalTo: parametersUsernameStackContainer.topAnchor),
            
            stackContainer.leadingAnchor.constraint(equalTo: whiteContainer.leadingAnchor),
            stackContainer.trailingAnchor.constraint(equalTo: whiteContainer.trailingAnchor),
            stackContainer.bottomAnchor.constraint(equalTo: whiteContainer.bottomAnchor, constant: -12),
            stackContainer.topAnchor.constraint(equalTo: whiteContainer.topAnchor, constant: 12),
            
            usernameContainer.heightAnchor.constraint(equalToConstant: 46),
            parametersContainer.heightAnchor.constraint(equalToConstant: 46),
        ])
        
        let profileTap = UITapGestureRecognizer(target: self, action: #selector(parametersTapped))
        parametersContainer.addGestureRecognizer(profileTap)
        
        contentViewStack.addArrangedSubview(parametersUsernameStackContainer)
    }

    private func setupBannerSection() {
        bannerView.onLearnMoreTapped = { [weak self] in
            self?.onLearnMoreTapped?()
        }
        
        bannerOuterContainer.addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: bannerOuterContainer.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: bannerOuterContainer.bottomAnchor),
            bannerView.leadingAnchor.constraint(equalTo: bannerOuterContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bannerView.trailingAnchor.constraint(equalTo: bannerOuterContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])

        contentViewStack.addArrangedSubview(bannerOuterContainer)
    }
    
    private func setupSavedMessagesSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(savedMessagesContainer)
        
        let whiteContainer = UIView()
        whiteContainer.translatesAutoresizingMaskIntoConstraints = false
        whiteContainer.layer.cornerRadius = DivoDesignTokens.Radius.pill
        whiteContainer.backgroundColor = DivoColorPalette.cardBackground
        whiteContainer.addSubview(stackContainer)
        
        savedMessagesStackContainer.translatesAutoresizingMaskIntoConstraints = false
        savedMessagesStackContainer.addSubview(whiteContainer)
        
        NSLayoutConstraint.activate([
            whiteContainer.leadingAnchor.constraint(equalTo: savedMessagesStackContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            whiteContainer.trailingAnchor.constraint(equalTo: savedMessagesStackContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            whiteContainer.bottomAnchor.constraint(equalTo: savedMessagesStackContainer.bottomAnchor),
            whiteContainer.topAnchor.constraint(equalTo: savedMessagesStackContainer.topAnchor),
            
            stackContainer.leadingAnchor.constraint(equalTo: whiteContainer.leadingAnchor),
            stackContainer.trailingAnchor.constraint(equalTo: whiteContainer.trailingAnchor),
            stackContainer.bottomAnchor.constraint(equalTo: whiteContainer.bottomAnchor, constant: -12),
            stackContainer.topAnchor.constraint(equalTo: whiteContainer.topAnchor, constant: 12),
            
            savedMessagesContainer.heightAnchor.constraint(equalToConstant: 46),
        ])
        
        contentViewStack.addArrangedSubview(savedMessagesStackContainer)
    }
    
    private func setupMainSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(notificationsSoundsContainer)
        stackContainer.addArrangedSubview(privacySecurityContainer)
        stackContainer.addArrangedSubview(dataStorageContainer)
        stackContainer.addArrangedSubview(languageContainer)
        stackContainer.addArrangedSubview(measuringSystemContainer)
        measuringSystemContainer.isHidden = true
        languageContainer.setSeparator(true)
        
        let whiteContainer = UIView()
        whiteContainer.translatesAutoresizingMaskIntoConstraints = false
        whiteContainer.layer.cornerRadius = DivoDesignTokens.Radius.pill
        whiteContainer.backgroundColor = DivoColorPalette.cardBackground
        whiteContainer.addSubview(stackContainer)
        
        mainSettingsStackContainer.translatesAutoresizingMaskIntoConstraints = false
        mainSettingsStackContainer.addSubview(whiteContainer)
        
        NSLayoutConstraint.activate([
            whiteContainer.leadingAnchor.constraint(equalTo: mainSettingsStackContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            whiteContainer.trailingAnchor.constraint(equalTo: mainSettingsStackContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            whiteContainer.bottomAnchor.constraint(equalTo: mainSettingsStackContainer.bottomAnchor),
            whiteContainer.topAnchor.constraint(equalTo: mainSettingsStackContainer.topAnchor),
            
            stackContainer.leadingAnchor.constraint(equalTo: whiteContainer.leadingAnchor),
            stackContainer.trailingAnchor.constraint(equalTo: whiteContainer.trailingAnchor),
            stackContainer.bottomAnchor.constraint(equalTo: whiteContainer.bottomAnchor, constant: -12),
            stackContainer.topAnchor.constraint(equalTo: whiteContainer.topAnchor, constant: 12),
            
            notificationsSoundsContainer.heightAnchor.constraint(equalToConstant: 46),
            privacySecurityContainer.heightAnchor.constraint(equalToConstant: 46),
            dataStorageContainer.heightAnchor.constraint(equalToConstant: 46),
            languageContainer.heightAnchor.constraint(equalToConstant: 46),
            measuringSystemContainer.heightAnchor.constraint(equalToConstant: 46),
        ])
        
        contentViewStack.addArrangedSubview(mainSettingsStackContainer)
    }
    
    private func setupLogOutSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(logOutContainer)
        
        let whiteContainer = UIView()
        whiteContainer.translatesAutoresizingMaskIntoConstraints = false
        whiteContainer.layer.cornerRadius = DivoDesignTokens.Radius.pill
        whiteContainer.backgroundColor = DivoColorPalette.cardBackground
        whiteContainer.addSubview(stackContainer)
        
        logOutStackContainer.translatesAutoresizingMaskIntoConstraints = false
        logOutStackContainer.addSubview(whiteContainer)
        
        NSLayoutConstraint.activate([
            whiteContainer.leadingAnchor.constraint(equalTo: logOutStackContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            whiteContainer.trailingAnchor.constraint(equalTo: logOutStackContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            whiteContainer.bottomAnchor.constraint(equalTo: logOutStackContainer.bottomAnchor),
            whiteContainer.topAnchor.constraint(equalTo: logOutStackContainer.topAnchor),
            
            stackContainer.leadingAnchor.constraint(equalTo: whiteContainer.leadingAnchor),
            stackContainer.trailingAnchor.constraint(equalTo: whiteContainer.trailingAnchor),
            stackContainer.bottomAnchor.constraint(equalTo: whiteContainer.bottomAnchor, constant: -12),
            stackContainer.topAnchor.constraint(equalTo: whiteContainer.topAnchor, constant: 12),
            
            logOutContainer.heightAnchor.constraint(equalToConstant: 46),
        ])
        
        contentViewStack.addArrangedSubview(logOutStackContainer)
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
        measuringSystemContainer.setItems(selectedMeasuringSystemTitle ?? "")
    }
    
    // MARK: - Internal

    func markLoading() {
        self.screenPhase = .loading
    }
    
    func markFailed() {
        self.screenPhase = .failed
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        self.containerLayout = (layout, navigationBarHeight)

        scrollView.contentInset = UIEdgeInsets(
            top: 0,
            left: layout.safeInsets.left,
            bottom: layout.intrinsicInsets.bottom + 20,
            right: layout.safeInsets.right
        )
        scrollView.scrollIndicatorInsets = scrollView.contentInset
        snackbar.updateBottomInset(layout.intrinsicInsets.bottom + 16)
    }


    // MARK: - Data loading

    func updateWithProfile(_ user: UserDetail) {
        profileHeader.configure(fullUrl: user.avatar?.fullUrl, fullName: user.fullName, phone: user.phone)
        selectedMeasuringSystemId = user.measuringSystem
        for option in measuringSystem where option.id == user.measuringSystem {
            selectedMeasuringSystemTitle = option.title
        }
        updateDropdownsUI()
        parametersContainer.isHidden = Role(apiRole: user.role) == .agency
        usernameContainer.setSeparator(Role(apiRole: user.role) == .agency)

        measuringSystemContainer.isHidden = Role(apiRole: user.role) == .agency
        languageContainer.setSeparator(Role(apiRole: user.role) == .agency)

        self.screenPhase = .ready // Переключаем стейт в готовый
    }


    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        let bottomInset = (containerLayout?.0.intrinsicInsets.bottom ?? 0) + 16
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: bottomInset,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }

    // MARK: - Actions
    
    @objc private func measuringSystemTapped() {
        guard screenPhase == .ready else { return } // Защита от кликов во время загрузки
        
        let options = measuringSystem.map { FilterOptionItem(id: String($0.id), title: $0.title) }
        let selectedIds = selectedMeasuringSystemId != nil ? [String(selectedMeasuringSystemId!)] :[]
        
        let vc = FilterOptionsController(
            title: DivoStrings.measuringSystem,
            options: options,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: false,
            isOpenPresent: true,
            isResetButton: false
        )
        
        vc.onSave = { [weak self] selectedItems in
            if let selected = selectedItems.first {
                self?.selectedMeasuringSystemId = selected.id
                self?.selectedMeasuringSystemTitle = selected.title
            } else {
                self?.selectedMeasuringSystemId = nil
                self?.selectedMeasuringSystemTitle = nil
            }
            self?.updateDropdownsUI()
        }
        presentSheet(vc)
    }

    @objc private func profileTapped() {
        guard screenPhase == .ready else { return }
        onProfileTapped?()
    }

    @objc private func usernameTapped() {
        guard screenPhase == .ready else { return }
        onSetUsernameTapped?()
    }

    @objc private func parametersTapped() {
        guard screenPhase == .ready else { return }
        onFillParametersTapped?()
    }
}

extension UIView {
    func startShimmering() {
        let gradient = CAGradientLayer()
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        
        let baseColor = DivoColorPalette.shimmerBase.cgColor
        let highlightColor = DivoColorPalette.shimmerHighlight.cgColor
        
        gradient.colors = [baseColor, highlightColor, baseColor]
        gradient.locations = [0.0, 0.5, 1.0]
        
        gradient.frame = CGRect(x: -self.bounds.width, y: 0, width: self.bounds.width * 3, height: self.bounds.height)
        
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0.0, 0.1, 0.2]
        animation.toValue = [0.8, 0.9, 1.0]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        
        gradient.add(animation, forKey: "shimmer")
        
        self.layer.mask = self.layer.cornerRadius > 0 ? nil : nil
        self.layer.addSublayer(gradient)
        self.layer.masksToBounds = true
    }
    
    func stopShimmering() {
        self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }
}
