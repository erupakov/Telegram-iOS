//
//  EventApplyConfirmationNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.05.2026.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import DivoUIKit
import DivoCore

public struct ParameterMatch: Equatable {
    public let title: String
    public let value: String
    public let isMatched: Bool
}

final class EventApplyConfirmationNode: ASDisplayNode {
    private let context: AccountContext
    private var containerLayout: (ContainerViewLayout, CGFloat)?

    // Callbacks
    var onBackTapped: (() -> Void)?
    var onCancelTapped: (() -> Void)?
    var onSubmitTapped: (() -> Void)?
    var onRetryTapped: (() -> Void)?

    // MARK: - Load phase
    enum ApplyPhase: Equatable {
        case loading
        case confirmation(matches: [ParameterMatch], hasMismatch: Bool)
        case success(deadlineText: String)
        case failed(networkError: Bool)
    }

    private var phase: ApplyPhase = .loading {
        didSet {
            if oldValue != phase { applyPhase() }
        }
    }

    // Вью ошибки загрузки
    private let errorView: ProfileTabErrorView = {
        let view = ProfileTabErrorView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: - UI Elements
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false
        return scrollView
    }()

    private let contentViewStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.l
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Background & Blur
    private let backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.backgroundColor = DivoColorPalette.imagePlaceholderMedium
        return iv
    }()

    private let blurredHeaderImageView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let whiteSheetBackground: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Navigation Bar
    private let customNavBar: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        let image = DivoImage.searchChevronLeft
        button.setImage(image, for: .normal)
        button.tintColor = DivoColorPalette.cardBackground
        button.backgroundColor = DivoColorPalette.statPillBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let navTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(20)
        label.textColor = DivoColorPalette.cardBackground
        label.textAlignment = .center
        label.text = DivoStrings.submitApplication.uppercased()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    // Event Info (Header)
    private let profileContainer: UIView = {
        let profileContainer = UIView()
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        return profileContainer
    }()
    
    private let profileHeader: HeaderApplyView = {
        let profileHeader = HeaderApplyView()
        profileHeader.translatesAutoresizingMaskIntoConstraints = false
        profileHeader.isHidden = true
        return profileHeader
    }()
    
    private let profileShimmerView: HeaderApplyShimmerView = {
        let profileShimmerView = HeaderApplyShimmerView()
        profileShimmerView.translatesAutoresizingMaskIntoConstraints = false
        return profileShimmerView
    }()
    
    // User Profile Card
    private let userProfileContainer: UIView = {
        let userProfileContainer = UIView()
        userProfileContainer.translatesAutoresizingMaskIntoConstraints = false
        return userProfileContainer
    }()
    
    private let userProfile: ProfileApplyView = {
        let userProfile = ProfileApplyView()
        userProfile.translatesAutoresizingMaskIntoConstraints = false
        userProfile.isHidden = true
        return userProfile
    }()
    
    private let userProfileShimmer: ProfileApplyShimmerView = {
        let userProfileShimmer = ProfileApplyShimmerView()
        userProfileShimmer.translatesAutoresizingMaskIntoConstraints = false
        return userProfileShimmer
    }()

    // Parameters Checklist Card (Container + Views)
    private let parametersContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let parametersView: ParametersApplyView = {
        let view = ParametersApplyView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let parametersShimmerView: ParametersApplyShimmerView = {
        let view = ParametersApplyShimmerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Bottom Bar Actions
    private let bottomButtonsContainer: UIView = {
        let bottomButtonsContainer = UIView()
        bottomButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonsContainer.isHidden = true
        return bottomButtonsContainer
    }()
    
    private let cancelButton = DivoButton()
    private let submitButton = DivoButton()
    
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

    // MARK: - Success State UI
    private let successContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let successCheckmarkView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        iv.tintColor = .systemGreen
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let successTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "YOU'RE IN!"
        label.font = Font.helveticaNeue(28)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let successSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(15)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let successCloseButton = DivoButton()

    // MARK: - Init
    init(context: AccountContext) {
        self.context = context
        super.init()
        setupUI()
    }
    
    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        applyGradientBlurMask()
    }

    private func setupUI() {
        self.view.addSubview(backgroundImageView)
        self.view.addSubview(scrollView)
        
        scrollView.insertSubview(whiteSheetBackground, belowSubview: contentViewStack)
        scrollView.addSubview(contentViewStack)
        
        setupProfileHeader()
        setupWhiteSheetBackground()
        setupUserProfile()
        setupBottomActionsBar()
        setupParametersChecklist()

        setupNavBar()
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

        setupConstraints()
        setupErrorView() // Встраиваем вью ошибок
    }
    
    private func setupProfileHeader() {
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        spacerView.backgroundColor = .clear
        contentViewStack.addArrangedSubview(spacerView)
        spacerView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        
        profileContainer.addSubview(profileHeader)
        profileContainer.addSubview(profileShimmerView)
        
        NSLayoutConstraint.activate([
            profileContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),

            profileHeader.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            profileHeader.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            profileHeader.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            profileHeader.topAnchor.constraint(equalTo: profileContainer.topAnchor),

            profileShimmerView.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            profileShimmerView.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            profileShimmerView.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            profileShimmerView.topAnchor.constraint(equalTo: profileContainer.topAnchor),
            profileShimmerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),
        ])
        contentViewStack.addArrangedSubview(profileContainer)
    }
    
    private func setupWhiteSheetBackground() {
        NSLayoutConstraint.activate([
            whiteSheetBackground.topAnchor.constraint(equalTo: profileContainer.topAnchor, constant: 34),
            whiteSheetBackground.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            whiteSheetBackground.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            whiteSheetBackground.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 1000),
        ])
    }
    
    private func setupUserProfile() {
        userProfileContainer.addSubview(userProfile)
        userProfileContainer.addSubview(userProfileShimmer)
        
        NSLayoutConstraint.activate([
            userProfileContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 70),

            userProfile.leadingAnchor.constraint(equalTo: userProfileContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            userProfile.trailingAnchor.constraint(equalTo: userProfileContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            userProfile.bottomAnchor.constraint(equalTo: userProfileContainer.bottomAnchor),
            userProfile.topAnchor.constraint(equalTo: userProfileContainer.topAnchor),

            userProfileShimmer.leadingAnchor.constraint(equalTo: userProfileContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            userProfileShimmer.trailingAnchor.constraint(equalTo: userProfileContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            userProfileShimmer.bottomAnchor.constraint(equalTo: userProfileContainer.bottomAnchor),
            userProfileShimmer.topAnchor.constraint(equalTo: userProfileContainer.topAnchor),
            userProfileShimmer.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
        ])
        contentViewStack.addArrangedSubview(userProfileContainer)
        contentViewStack.setCustomSpacing(10, after: userProfileContainer)
    }
    
    private func setupBottomActionsBar() {
        self.view.addSubview(bottomFadeOverlay)
        self.view.addSubview(bottomButtonsContainer)
        
        cancelButton.makeDivoButton(title: DivoStrings.cancel, buttonFont: Font.helveticaNeue(18), radius: 28, divoButtonStyle: .secondary)
        cancelButton.backgroundColor = DivoColorPalette.secondaryButtonBackground
        submitButton.makeDivoButton(title: DivoStrings.submit, buttonFont: Font.helveticaNeue(18), radius: 28)
        
        let actionsStack = UIStackView(arrangedSubviews: [cancelButton, submitButton])
        actionsStack.axis = .horizontal
        actionsStack.spacing = 10
        actionsStack.distribution = .fillEqually
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonsContainer.addSubview(actionsStack)

        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: 160),
            
            bottomButtonsContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            bottomButtonsContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            bottomButtonsContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            bottomButtonsContainer.heightAnchor.constraint(equalToConstant: 100),
            
            actionsStack.leadingAnchor.constraint(equalTo: bottomButtonsContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            actionsStack.trailingAnchor.constraint(equalTo: bottomButtonsContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            actionsStack.topAnchor.constraint(equalTo: bottomButtonsContainer.topAnchor, constant: DivoDesignTokens.Spacing.m),
            actionsStack.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
    
    private func setupParametersChecklist() {
        parametersContainer.addSubview(parametersView)
        parametersContainer.addSubview(parametersShimmerView)
        
        NSLayoutConstraint.activate([
            parametersContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            parametersView.leadingAnchor.constraint(equalTo: parametersContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            parametersView.trailingAnchor.constraint(equalTo: parametersContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            parametersView.bottomAnchor.constraint(equalTo: parametersContainer.bottomAnchor),
            parametersView.topAnchor.constraint(equalTo: parametersContainer.topAnchor),
            
            parametersShimmerView.leadingAnchor.constraint(equalTo: parametersContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            parametersShimmerView.trailingAnchor.constraint(equalTo: parametersContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            parametersShimmerView.bottomAnchor.constraint(equalTo: parametersContainer.bottomAnchor),
            parametersShimmerView.topAnchor.constraint(equalTo: parametersContainer.topAnchor),
            parametersShimmerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
        contentViewStack.addArrangedSubview(parametersContainer)
    }
    
    private func setupNavBar() {
        self.view.addSubview(blurredHeaderImageView)
        self.view.addSubview(customNavBar)
        customNavBar.addSubview(closeButton)
        customNavBar.addSubview(navTitleLabel)
        
        NSLayoutConstraint.activate([
            customNavBar.topAnchor.constraint(equalTo: self.view.topAnchor),
            customNavBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            customNavBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            customNavBar.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 52),

            closeButton.leadingAnchor.constraint(equalTo: customNavBar.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            closeButton.centerYAnchor.constraint(equalTo: customNavBar.bottomAnchor, constant: -25),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            navTitleLabel.centerXAnchor.constraint(equalTo: customNavBar.centerXAnchor),
            navTitleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            
            blurredHeaderImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            blurredHeaderImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            blurredHeaderImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            blurredHeaderImageView.heightAnchor.constraint(equalToConstant: 180),
        ])
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),

            contentViewStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentViewStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentViewStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentViewStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -120),
            contentViewStack.widthAnchor.constraint(equalTo: self.view.widthAnchor),
        ])
    }
    
    private func setupErrorView() {
        self.view.addSubview(errorView)
        NSLayoutConstraint.activate([
            errorView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            errorView.topAnchor.constraint(equalTo: self.view.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        // Кнопка назад и кастомный навбар должны остаться на переднем плане
        self.view.bringSubviewToFront(customNavBar)
    }
    
    private func formatEventDateAndTime(dateString: String?) -> (date: String, time: String) {
        guard let dateString = dateString else {
            return (DivoStrings.tbd, DivoStrings.tbd)
        }

        let serverFormatter = DateFormatter()
        serverFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = serverFormatter.date(from: dateString) else {
            return (dateString, "")
        }

        let languageCode = Locale.preferredLanguages.first?.components(separatedBy: "-").first?.lowercased() ?? "en"
        let localeIdentifierByLanguage:[String: String] = [
            "ru": "ru_RU",
            "en": "en_US",
            "pt": "pt_PT",
            "es": "es_ES",
            "zh": "zh_CN"
        ]
        let locale = Locale(identifier: localeIdentifierByLanguage[languageCode] ?? "en_US")

        let dateUIFormatter = DateFormatter()
        dateUIFormatter.locale = locale
        dateUIFormatter.dateFormat = "LLLL d"
        let rawFormattedDate = dateUIFormatter.string(from: date)
        let formattedDate: String = {
            guard let first = rawFormattedDate.first else { return rawFormattedDate }
            return String(first).uppercased(with: locale) + rawFormattedDate.dropFirst()
        }()

        let timeUIFormatter = DateFormatter()
        timeUIFormatter.locale = locale
        switch languageCode {
        case "en": timeUIFormatter.dateFormat = "h:mm a"
        case "zh": timeUIFormatter.dateFormat = "a h:mm"
        case "ru", "pt", "es": timeUIFormatter.dateFormat = "HH:mm"
        default: timeUIFormatter.dateFormat = "HH:mm"
        }
        let formattedTime = timeUIFormatter.string(from: date)

        return (formattedDate, formattedTime)
    }
    
    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }
    
    private func applyPhase() {
        switch phase {
        case .loading:
            scrollView.isHidden = true
            bottomButtonsContainer.isHidden = true
            successContainer.isHidden = true
            errorView.isHidden = true
            
            profileShimmerView.isHidden = false
            profileHeader.isHidden = true
            
            userProfileShimmer.isHidden = false
            userProfile.isHidden = true
            
            parametersShimmerView.isHidden = false
            parametersView.isHidden = true
            
            navTitleLabel.isHidden = true
            bottomButtonsContainer.isHidden = true
            
            profileShimmerView.startAnimation()
            userProfileShimmer.startAnimation()
            parametersShimmerView.startAnimation()
            
        case .confirmation:
            errorView.isHidden = true
            UIView.animate(withDuration: 0.3) {
                self.scrollView.isHidden = false
                self.bottomButtonsContainer.isHidden = false
                self.successContainer.isHidden = true
                self.scrollView.isScrollEnabled = true
                
                self.profileShimmerView.isHidden = true
                self.profileHeader.isHidden = false
                
                self.userProfileShimmer.isHidden = true
                self.userProfile.isHidden = false
                
                self.parametersShimmerView.isHidden = true
                self.parametersView.isHidden = false
                
                self.navTitleLabel.isHidden = false
                self.bottomButtonsContainer.isHidden = false
            }
            profileShimmerView.stopAnimation()
            userProfileShimmer.stopAnimation()
            parametersShimmerView.stopAnimation()
            
        case .success(let deadlineText):
            scrollView.isHidden = true
            bottomButtonsContainer.isHidden = true
            errorView.isHidden = true
            
            // Format success subtitle safely with the deadline date
            successSubtitleLabel.text = "Your application has been sent. The organiser will review it by \(deadlineText)."
            
            successContainer.isHidden = false
            
            profileShimmerView.stopAnimation()
            userProfileShimmer.stopAnimation()
            parametersShimmerView.stopAnimation()
            
        case .failed(let networkError):
            // Прячем абсолютно все секции и контент
            scrollView.isHidden = true
            bottomButtonsContainer.isHidden = true
            successContainer.isHidden = true
            
            profileShimmerView.stopAnimation()
            profileShimmerView.isHidden = true
            userProfileShimmer.stopAnimation()
            userProfileShimmer.isHidden = true
            parametersShimmerView.stopAnimation()
            parametersShimmerView.isHidden = true
            
            errorView.configure(
                title: networkError ? DivoStrings.profileTabErrorNetworkTitle : DivoStrings.eventDetailErrorTitle,
                subtitle: DivoStrings.profileTabErrorSubtitle,
                onRetry: { [weak self] in self?.onRetryTapped?() }
            )
            errorView.isHidden = false
        }
    }

    private func buildParametersList(matches: [ParameterMatch]) {
        // Логика чек-листа полностью инкапсулирована в ParametersApplyView.
        // Этот приватный метод в EventApplyConfirmationNode больше не используется.
    }
    
    private func applyGradientBlurMask() {
        let blurBounds = blurredHeaderImageView.bounds
        guard blurBounds.height > 0 else { return }
        
        let maskLayer = CAGradientLayer()
        maskLayer.frame = blurBounds
        
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
  
        maskLayer.colors = [
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(0.85).cgColor,
            UIColor.black.withAlphaComponent(0.35).cgColor,
            UIColor.clear.cgColor
        ]
        maskLayer.locations = [0.0, 0.45, 0.80, 1.0] as [NSNumber]
        
        blurredHeaderImageView.layer.mask = maskLayer
    }


    // MARK: - Public State API
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        self.layoutIfNeeded()
    }

    func update(
        user: UserDetail,
        event: EventFullDetailData,
        matches: [ParameterMatch],
        hasMismatch: Bool,
        isMultipleMismatches: Bool,
        singleMismatch: ParameterMatch?
    ) {
        self.phase = .confirmation(matches: matches, hasMismatch: hasMismatch)

        // Event cover
        if let firstFile = event.files?.first?.fullUrl, let url = CDNURLHelper.convertToCDNURL(firstFile) {
            backgroundImageView.loadImage(from: url)
        }
        
        // Header
        var fullLocationString: String
        let isFree = event.paymentType?.id == 2
        let costPart = isFree ? nil : (event.cost ?? "")
        let countryFlag = Self.flag(for: event.address?.city?.countryCode)
        let (date, time) = formatEventDateAndTime(dateString: event.date)
        guard let city = event.address?.city?.name else { return }
        if let costPart = costPart {
            fullLocationString = "\(date) • \(time) • \(countryFlag) \(city) • $ \(costPart)"
        } else {
            fullLocationString = "\(date) • \(time) • \(countryFlag) \(city)"
        }
        
        profileHeader.configure(fullUrl: event.creator?.avatar?.fullUrl, fullName: event.title, eventType: event.type?.title, eventInfo: fullLocationString)
        
        // User profile Card
        // ХАРДКОР МЕТА - НЕ ГОТОВ БЭК
        userProfile.configure(name: user.fullName, role: Role(apiRole: user.role).title, meta: "12K followers · Online", fullUrl: user.avatar?.fullUrl)

        // Parameters Checklist Card
        parametersView.configure(matches: matches, hasMismatch: hasMismatch, isMultipleMismatches: isMultipleMismatches, singleMismatch: singleMismatch)
    }
    
    func showSuccessState(deadlineText: String) {
        self.phase = .success(deadlineText: deadlineText)
    }

    func toggleSubmitLoading(active: Bool) {
        submitButton.setSaving(active, in: self.view)
    }
    
    func markFailed(networkError: Bool) {
        self.phase = .failed(networkError: networkError)
    }

    func resetToLoading() {
        self.phase = .loading
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() { onBackTapped?() }
    @objc private func cancelButtonTapped() { onCancelTapped?() }
    @objc private func submitButtonTapped() { onSubmitTapped?() }
}
