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

final class DivoSettingsNode: ASDisplayNode {
    
    private let context: AccountContext
    
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
    private let profileHeader = HeaderSettings()

    // Set Username section
    private let usernameContainer = SettingsRowView(icon: DivoImage.settingsSetUsername, title: DivoStrings.settingsSetUsername, isLast: false)
    
    private let parametersContainer = SettingsRowView(icon: DivoImage.settingsParameters, title: DivoStrings.fillYourParameters, isLast: true)

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
    
    private let savedMessagesContainer = SettingsRowView(icon: DivoImage.settingsSavedMessages, title: DivoStrings.savedMessages, isLast: true)
    
    private let notificationsSoundsContainer = SettingsRowView(icon: DivoImage.settingsNotifications, title: DivoStrings.notificationsSounds, isLast: false)
    private let privacySecurityContainer = SettingsRowView(icon: DivoImage.settingsPrivacy, title: DivoStrings.privacySecurity, isLast: false)
    private let dataStorageContainer = SettingsRowView(icon: DivoImage.settingsData, title: DivoStrings.dataStorage, isLast: false)
    private let languageContainer = SettingsRowView(icon: DivoImage.settingsLanguage, title: DivoStrings.language, isLast: true)
    
    private let logOutContainer = SettingsRowView(icon: DivoImage.settingsLogOut, title: DivoStrings.logOut, isLast: true)

    var onProfileTapped: (() -> Void)?
    var onSetUsernameTapped: (() -> Void)?
    var onFillParametersTapped: (() -> Void)?
    var onLearnMoreTapped: (() -> Void)?

    private var containerLayout: (ContainerViewLayout, CGFloat)?

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
        
        setupCustomNavBar()
        setupUI()
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
        setupBannerSection()
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

        NSLayoutConstraint.activate([
            profileContainer.heightAnchor.constraint(equalToConstant: 152),

            profileHeader.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor),
            profileHeader.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor),
            profileHeader.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            profileHeader.topAnchor.constraint(equalTo: profileContainer.topAnchor),
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
        
        let whiteContainer = UIView()
        whiteContainer.translatesAutoresizingMaskIntoConstraints = false
        whiteContainer.layer.cornerRadius = DivoDesignTokens.Radius.pill
        whiteContainer.backgroundColor = DivoColorPalette.cardBackground
        whiteContainer.addSubview(stackContainer)
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(whiteContainer)
        
        NSLayoutConstraint.activate([
            whiteContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            whiteContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            whiteContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            whiteContainer.topAnchor.constraint(equalTo: container.topAnchor),
            
            stackContainer.leadingAnchor.constraint(equalTo: whiteContainer.leadingAnchor),
            stackContainer.trailingAnchor.constraint(equalTo: whiteContainer.trailingAnchor),
            stackContainer.bottomAnchor.constraint(equalTo: whiteContainer.bottomAnchor, constant: -12),
            stackContainer.topAnchor.constraint(equalTo: whiteContainer.topAnchor, constant: 12),
            
            usernameContainer.heightAnchor.constraint(equalToConstant: 46),
            parametersContainer.heightAnchor.constraint(equalToConstant: 46),
        ])
        
        let profileTap = UITapGestureRecognizer(target: self, action: #selector(parametersTapped))
        parametersContainer.addGestureRecognizer(profileTap)
        
        contentViewStack.addArrangedSubview(container)
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
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(whiteContainer)
        
        NSLayoutConstraint.activate([
            whiteContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            whiteContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            whiteContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            whiteContainer.topAnchor.constraint(equalTo: container.topAnchor),
            
            stackContainer.leadingAnchor.constraint(equalTo: whiteContainer.leadingAnchor),
            stackContainer.trailingAnchor.constraint(equalTo: whiteContainer.trailingAnchor),
            stackContainer.bottomAnchor.constraint(equalTo: whiteContainer.bottomAnchor, constant: -12),
            stackContainer.topAnchor.constraint(equalTo: whiteContainer.topAnchor, constant: 12),
            
            savedMessagesContainer.heightAnchor.constraint(equalToConstant: 46),
        ])
        
        contentViewStack.addArrangedSubview(container)
    }
    
    private func setupMainSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(notificationsSoundsContainer)
        stackContainer.addArrangedSubview(privacySecurityContainer)
        stackContainer.addArrangedSubview(dataStorageContainer)
        stackContainer.addArrangedSubview(languageContainer)
        
        let whiteContainer = UIView()
        whiteContainer.translatesAutoresizingMaskIntoConstraints = false
        whiteContainer.layer.cornerRadius = DivoDesignTokens.Radius.pill
        whiteContainer.backgroundColor = DivoColorPalette.cardBackground
        whiteContainer.addSubview(stackContainer)
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(whiteContainer)
        
        NSLayoutConstraint.activate([
            whiteContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            whiteContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            whiteContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            whiteContainer.topAnchor.constraint(equalTo: container.topAnchor),
            
            stackContainer.leadingAnchor.constraint(equalTo: whiteContainer.leadingAnchor),
            stackContainer.trailingAnchor.constraint(equalTo: whiteContainer.trailingAnchor),
            stackContainer.bottomAnchor.constraint(equalTo: whiteContainer.bottomAnchor, constant: -12),
            stackContainer.topAnchor.constraint(equalTo: whiteContainer.topAnchor, constant: 12),
            
            notificationsSoundsContainer.heightAnchor.constraint(equalToConstant: 46),
            privacySecurityContainer.heightAnchor.constraint(equalToConstant: 46),
            dataStorageContainer.heightAnchor.constraint(equalToConstant: 46),
            languageContainer.heightAnchor.constraint(equalToConstant: 46),
        ])
        
        contentViewStack.addArrangedSubview(container)
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
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(whiteContainer)
        
        NSLayoutConstraint.activate([
            whiteContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            whiteContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            whiteContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            whiteContainer.topAnchor.constraint(equalTo: container.topAnchor),
            
            stackContainer.leadingAnchor.constraint(equalTo: whiteContainer.leadingAnchor),
            stackContainer.trailingAnchor.constraint(equalTo: whiteContainer.trailingAnchor),
            stackContainer.bottomAnchor.constraint(equalTo: whiteContainer.bottomAnchor, constant: -12),
            stackContainer.topAnchor.constraint(equalTo: whiteContainer.topAnchor, constant: 12),
            
            logOutContainer.heightAnchor.constraint(equalToConstant: 46),
        ])
        
        contentViewStack.addArrangedSubview(container)
    }
    
    // MARK: - Layout

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

    @objc private func profileTapped() {
        onProfileTapped?()
    }

    @objc private func usernameTapped() {
        onSetUsernameTapped?()
    }

    @objc private func parametersTapped() {
        onFillParametersTapped?()
    }
}
