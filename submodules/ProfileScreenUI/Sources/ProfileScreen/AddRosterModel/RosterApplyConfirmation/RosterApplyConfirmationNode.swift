//
//  RosterApplyConfirmationNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 01.06.2026.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import DivoUIKit
import DivoCore

final class RosterApplyConfirmationNode: ASDisplayNode {
    private var containerLayout: (ContainerViewLayout, CGFloat)?

    // Callbacks
    var onCancelTapped: (() -> Void)?
    var onConfirmTapped: ((String?) -> Void)?
    var onRetryTapped: (() -> Void)?

    // MARK: - Load phase
    enum RosterPhase: Equatable {
        case loading
        case content
        case failed(networkError: Bool)
    }

    private var phase: RosterPhase = .loading {
        didSet {
            if oldValue != phase { applyPhase() }
        }
    }
    
    private var userFullName: String?

    // MARK: - UI Elements
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let contentViewStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Background Cover Image
    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.backgroundColor = DivoColorPalette.imagePlaceholderMedium
        return iv
    }()

    private let whiteSheetBackground: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let profileContainer: UIView = {
        let profileContainer = UIView()
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        return profileContainer
    }()
    
    private let profileHeader: RosterHeaderView = {
        let profileHeader = RosterHeaderView()
        profileHeader.translatesAutoresizingMaskIntoConstraints = false
        profileHeader.isHidden = true
        return profileHeader
    }()
    
    private let profileShimmerView: RosterHeaderShimmerView = {
        let profileShimmerView = RosterHeaderShimmerView()
        profileShimmerView.translatesAutoresizingMaskIntoConstraints = false
        return profileShimmerView
    }()

    private let parametersContainer: UIView = {
        let profileContainer = UIView()
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        return profileContainer
    }()
    
    private let parametersPillContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let parametersLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let parametersShimmer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 17
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Note Section
    private let noteTitleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.addModelNote
        label.font = Font.regular(20)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        label.numberOfLines = 0
        return label
    }()
    
    private let noteTitleShimmer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 17
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let bottomButtonsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let cancelButton = DivoButton()
    private let confirmButton = DivoButton()

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

    private let errorView: ProfileTabErrorView = {
        let view = ProfileTabErrorView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private var didStartShimmerAnimation = false
    

    // MARK: - Init
    
    override init() {
        super.init()
        setupUI()
    }
    
    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        
        if case .loading = phase, !didStartShimmerAnimation, profileShimmerView.bounds.width > 0 {
            profileShimmerView.startAnimation()
            
            parametersShimmer.stopShimmering()
            parametersShimmer.startShimmering()
            
            noteTitleShimmer.stopShimmering()
            noteTitleShimmer.startShimmering()
            
            didStartShimmerAnimation = true
        }
    }

    private func setupUI() {
        self.view.addSubview(coverImageView)
        self.view.addSubview(scrollView)
        
        scrollView.insertSubview(whiteSheetBackground, belowSubview: contentViewStack)
        scrollView.addSubview(contentViewStack)
        
        setupProfileHeader()
        setupWhiteSheetBackground()
        setupParameters()
        setupNoteSection()
        setupBottomActionsBar()
        setupStatusViews()
        setupConstraints()
        
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(dismissTap)
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
    
    private func setupParameters() {
        parametersContainer.addSubview(parametersPillContainer)
        parametersPillContainer.addSubview(parametersLabel)
        parametersContainer.addSubview(parametersShimmer)
        
        NSLayoutConstraint.activate([
            parametersContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 34),
            
            parametersPillContainer.centerXAnchor.constraint(equalTo: parametersContainer.centerXAnchor),
            parametersPillContainer.centerYAnchor.constraint(equalTo: parametersContainer.centerYAnchor),
            parametersPillContainer.bottomAnchor.constraint(equalTo: parametersContainer.bottomAnchor),
            parametersPillContainer.topAnchor.constraint(equalTo: parametersContainer.topAnchor),
            
            parametersLabel.leadingAnchor.constraint(equalTo: parametersPillContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            parametersLabel.trailingAnchor.constraint(equalTo: parametersPillContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            parametersLabel.bottomAnchor.constraint(equalTo: parametersPillContainer.bottomAnchor),
            parametersLabel.topAnchor.constraint(equalTo: parametersPillContainer.topAnchor),
            
            parametersShimmer.centerXAnchor.constraint(equalTo: parametersContainer.centerXAnchor),
            parametersShimmer.centerYAnchor.constraint(equalTo: parametersContainer.centerYAnchor),
            parametersShimmer.bottomAnchor.constraint(equalTo: parametersContainer.bottomAnchor),
            parametersShimmer.topAnchor.constraint(equalTo: parametersContainer.topAnchor),
            parametersShimmer.heightAnchor.constraint(greaterThanOrEqualToConstant: 34),
            parametersShimmer.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
        contentViewStack.addArrangedSubview(parametersContainer)
    }

    private func setupNoteSection() {
        let noteContainer = UIView()
        noteContainer.translatesAutoresizingMaskIntoConstraints = false
        
        noteContainer.addSubview(noteTitleLabel)
        noteContainer.addSubview(noteTitleShimmer)
        contentViewStack.addArrangedSubview(noteContainer)

        NSLayoutConstraint.activate([
            noteContainer.heightAnchor.constraint(equalToConstant: 160),
            
            noteTitleLabel.topAnchor.constraint(equalTo: noteContainer.topAnchor),
            noteTitleLabel.leadingAnchor.constraint(equalTo: noteContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            noteTitleLabel.trailingAnchor.constraint(equalTo: noteContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            noteTitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: noteContainer.bottomAnchor),
            
            noteTitleShimmer.topAnchor.constraint(equalTo: noteContainer.topAnchor),
            noteTitleShimmer.leadingAnchor.constraint(equalTo: noteContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            noteTitleShimmer.trailingAnchor.constraint(equalTo: noteContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            noteTitleShimmer.bottomAnchor.constraint(equalTo: noteContainer.bottomAnchor),

        ])
    }

    private func setupBottomActionsBar() {
        self.view.addSubview(bottomFadeOverlay)
        self.view.addSubview(bottomButtonsContainer)
        
        cancelButton.makeDivoButton(title: DivoStrings.cancel, buttonFont: Font.helveticaNeue(18), radius: 28, divoButtonStyle: .secondary)
        cancelButton.backgroundColor = DivoColorPalette.secondaryButtonBackground
        confirmButton.makeDivoButton(title: DivoStrings.addModelConfirm, loading: DivoStrings.addModelConfirming, buttonFont: Font.helveticaNeue(18), radius: 28)
        
        let actionsStack = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        actionsStack.axis = .horizontal
        actionsStack.spacing = 10
        actionsStack.distribution = .fillEqually
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        bottomButtonsContainer.addSubview(actionsStack)

        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)

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

    private func setupStatusViews() {
        self.view.addSubview(errorView)
        
        NSLayoutConstraint.activate([
            errorView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            errorView.topAnchor.constraint(equalTo: self.view.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            coverImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            coverImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

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

    private func applyPhase() {
        switch phase {
        case .loading:
            profileShimmerView.isHidden = false
            profileHeader.isHidden = true
            profileShimmerView.startAnimation()
            
            parametersShimmer.isHidden = false
            parametersPillContainer.isHidden = true
            parametersShimmer.stopShimmering()
            parametersShimmer.startShimmering()
            
            noteTitleShimmer.isHidden = false
            noteTitleLabel.isHidden = true
            noteTitleShimmer.stopShimmering()
            noteTitleShimmer.startShimmering()
            
            scrollView.isHidden = false
            bottomButtonsContainer.isHidden = true
            errorView.isHidden = true
            
        case .content:
            profileShimmerView.isHidden = true
            profileHeader.isHidden = false
            
            parametersShimmer.isHidden = true
            parametersPillContainer.isHidden = false
            parametersShimmer.stopShimmering()
            
            noteTitleShimmer.isHidden = true
            noteTitleLabel.isHidden = false
            noteTitleShimmer.stopShimmering()
            
            errorView.isHidden = true
            
            UIView.animate(withDuration: 0.3) {
                self.scrollView.isHidden = false
                self.bottomButtonsContainer.isHidden = false
            }
            
        case .failed(let networkError):
            profileShimmerView.isHidden = true
            profileHeader.isHidden = true
            profileShimmerView.stopAnimation()
            
            parametersShimmer.isHidden = true
            parametersPillContainer.isHidden = true
            parametersShimmer.stopShimmering()
            
            noteTitleShimmer.isHidden = true
            noteTitleLabel.isHidden = true
            noteTitleShimmer.stopShimmering()
            
            scrollView.isHidden = true
            bottomButtonsContainer.isHidden = true
            
            errorView.configure(
                title: networkError ? DivoStrings.profileTabErrorNetworkTitle : DivoStrings.failedLoadInteractionList,
                subtitle: DivoStrings.profileTabErrorSubtitle,
                onRetry: { [weak self] in self?.onRetryTapped?() }
            )
            errorView.isHidden = false
        }
    }

    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }

    // MARK: - Public State API
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        self.layoutIfNeeded()
    }

    func update(with user: UserDetail) {
        self.phase = .content
        self.userFullName = user.fullName
        
        if let userCover = user.photo?.fullUrl, let url = CDNURLHelper.convertToCDNURL(userCover) {
            coverImageView.loadImage(from: url)
        }
        
        let countryFlag = Self.flag(for: user.city?.countryCode)
        let agePart = user.birthday
            .flatMap { calculateAge(from: $0) }
            .map { DivoStrings.ageString($0) }
        let cityPart = user.city?.name
            .map { "\(countryFlag) \($0)" }
        let parts = [agePart, cityPart].compactMap { $0 }
        let fullLocationString = parts.isEmpty ? nil : parts.joined(separator: " • ")
        
        profileHeader.configure(fullUrl: user.avatar?.fullUrl, fullName: user.fullName, role: user.roleLabel,  meta: fullLocationString)

        let app = user.model?.appearance
        let h = app?.height.flatMap { "H \(Int($0))" } ?? ""
        let b = app?.weight.flatMap { "B \(Int($0))" } ?? ""
        let w = app?.waist.flatMap { "W \(Int($0))" } ?? ""
        let hips = app?.hips.flatMap { "H \(Int($0))" } ?? ""
        let pillText = [h, b, w, hips].filter { !$0.isEmpty }.joined(separator: " · ")
        parametersLabel.text = pillText
        parametersContainer.isHidden = pillText.isEmpty
    }

    func toggleSubmitLoading(active: Bool) {
        confirmButton.setSaving(active, in: self.view)
    }
    
    func markFailed(networkError: Bool) {
        self.phase = .failed(networkError: networkError)
    }

    func resetToLoading() {
        self.phase = .loading
    }

    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }
    
    private func calculateAge(from birthdayString: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let birthday = formatter.date(from: birthdayString) else { return nil }

        let now = Date()
        let calendar = Calendar.current
        return calendar.dateComponents([.year], from: birthday, to: now).year
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() { onCancelTapped?() }
    @objc private func confirmButtonTapped() { onConfirmTapped?(self.userFullName) }
    
    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: DivoDesignTokens.Spacing.m,
            bottomAnchor: bottomButtonsContainer.topAnchor,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }
}
