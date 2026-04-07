import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramBaseController
import TelegramCore
import DivoCore
import AppBundle
import ProfileScreenUI

public final class DivoSettingsController: TelegramBaseController {

    private let _ready = Promise<Bool>(true)
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private let context: AccountContext
    private var presentationData: PresentationData

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let copperColor = UIColor(red: 191.0/255.0, green: 122.0/255.0, blue: 84.0/255.0, alpha: 1.0)

        let navTheme = NavigationBarTheme(
            overallDarkAppearance: false,
            buttonColor: copperColor,
            disabledButtonColor: copperColor.withAlphaComponent(0.4),
            primaryTextColor: .black,
            backgroundColor: .white,
            opaqueBackgroundColor: .white,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear
        )
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(theme: navTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))

        // Custom title label: HelveticaNeue-CondensedBold 20px, centered
        let titleLabel = UILabel()
        let titleFont = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold)
        let titleAttr = NSAttributedString(string: DivoStrings.settings, attributes: [
            .font: titleFont,
            .foregroundColor: UIColor.black,
            .kern: 0.5
        ])
        titleLabel.attributedText = titleAttr
        titleLabel.textAlignment = .center
        titleLabel.frame = CGRect(x: 0, y: 0, width: 200, height: 44)
        self.navigationItem.titleView = titleLabel

        self.tabBarItem.title = DivoStrings.tabSettings
        let settingsIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconSettings"), color: UIColor(white: 0.55, alpha: 1))
        let settingsIconSelected = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconSettings"), color: UIColor(white: 0.2, alpha: 1))
        self.tabBarItem.image = settingsIcon
        self.tabBarItem.selectedImage = settingsIconSelected

        // QR button (left) — use alwaysOriginal so the nav bar theme doesn't override tint
        let qrImage = generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: copperColor)?.withRenderingMode(.alwaysOriginal)
        let qrButton = UIBarButtonItem(
            image: qrImage,
            style: .plain,
            target: self,
            action: #selector(qrTapped)
        )
        self.navigationItem.leftBarButtonItem = qrButton

        self.navigationItem.rightBarButtonItem = makeEditButton()
        NotificationCenter.default.addObserver(forName: DivoConfig.tokenDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            (self.displayNode as? DivoSettingsNode)?.reloadProfile()
        }

        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.tabBarItem.title = DivoStrings.tabSettings
            let titleFont = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold)
            let titleAttr = NSAttributedString(string: DivoStrings.settings, attributes: [
                .font: titleFont,
                .foregroundColor: UIColor.black,
                .kern: 0.5
            ])
            (self.navigationItem.titleView as? UILabel)?.attributedText = titleAttr
            self.navigationItem.rightBarButtonItem = self.makeEditButton()
        }
    }

    private func makeEditButton() -> UIBarButtonItem {
        let copperColor = UIColor(red: 191.0/255.0, green: 122.0/255.0, blue: 84.0/255.0, alpha: 1.0)
        let editFont = UIFont(name: "HelveticaNeue-CondensedBold", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .bold)
        let button = UIBarButtonItem(title: DivoStrings.settingsEdit, style: .plain, target: self, action: #selector(editTapped))
        button.setTitleTextAttributes([.foregroundColor: copperColor, .font: editFont], for: .normal)
        button.setTitleTextAttributes([.foregroundColor: copperColor.withAlphaComponent(0.5), .font: editFont], for: .highlighted)
        return button
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = DivoSettingsNode(context: self.context)
        node.onProfileTapped = { [weak self] in
            self?.openMyProfile()
        }
        node.onSetUsernameTapped = { [weak self] in
            // TODO: open set username flow
            _ = self
        }
        node.onFillParametersTapped = { [weak self] in
            // TODO: open parameters flow
            _ = self
        }
        node.onLearnMoreTapped = { [weak self] in
            // TODO: open learn more
            _ = self
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        (self.displayNode as? DivoSettingsNode)?.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (self.displayNode as? DivoSettingsNode)?.loadProfile()
    }

    // MARK: - Actions

    @objc private func qrTapped() {
        // TODO: open QR scanner
    }

    @objc private func editTapped() {
        openMyProfile()
    }

    private func openMyProfile() {
        let profileModel = ProfileModel(
            name: "",
            age: 0,
            location: "",
            mainImageName: "",
            avatarImageName: "",
            isVerified: false,
            likesCount: "0",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            galleryImageNames: [],
            isMyProfile: true
        )
        let profileController = PublicProfileScreenController(context: context, model: profileModel)
        if let nav = self.navigationController as? NavigationController {
            nav.pushViewController(profileController, animated: true)
        }
    }
}

// MARK: - Shimmer

private extension UIView {
    func startSettingsShimmer() {
        let shimmerColor = UIColor(white: 0.88, alpha: 1.0).cgColor
        let highlightColor = UIColor(white: 0.96, alpha: 1.0).cgColor

        let gradient = CAGradientLayer()
        gradient.name = "settingsShimmer"
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.colors = [shimmerColor, highlightColor, shimmerColor]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
        gradient.cornerRadius = layer.cornerRadius

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0.0, 0.1, 0.2]
        animation.toValue = [0.8, 0.9, 1.0]
        animation.duration = 1.4
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        gradient.add(animation, forKey: "shimmer")

        layer.addSublayer(gradient)
    }

    func stopSettingsShimmer() {
        layer.sublayers?.filter { $0.name == "settingsShimmer" }.forEach { $0.removeFromSuperlayer() }
    }
}

// MARK: - Colors

private enum DivoSettingsColors {
    static let accent = UIColor(red: 0.76, green: 0.55, blue: 0.38, alpha: 1.0) // brown/copper
    static let background = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
    static let separator = UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.0)
}

// MARK: - Node

private final class DivoSettingsNode: ASDisplayNode {

    private let context: AccountContext
    private let scrollView = UIScrollView()

    // Profile section
    private let profileContainer = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let phoneLabel = UILabel()
    private let profileChevron = UIImageView()

    // Set Username section
    private let usernameContainer = UIView()
    private let usernameIconView = UILabel()
    private let usernameLabel = UILabel()

    // Fill parameters button
    private let parametersButton = UIButton(type: .system)

    // Promo banner
    private let bannerContainer = UIView()
    private let bannerImageView = UIImageView()
    private let bannerOverlay = UIView()
    private let bannerDivoLabel = UILabel()
    private let bannerTitleLabel = UILabel()
    private let bannerDescriptionLabel = UILabel()
    private let learnMoreButton = UIButton(type: .system)

    // Separators
    private let separator1 = UIView()
    private let separator2 = UIView()

    var onProfileTapped: (() -> Void)?
    var onSetUsernameTapped: (() -> Void)?
    var onFillParametersTapped: (() -> Void)?
    var onLearnMoreTapped: (() -> Void)?

    init(context: AccountContext) {
        self.context = context
        super.init()
        self.backgroundColor = .white
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Scroll view
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        self.view.addSubview(scrollView)

        // MARK: Profile section
        profileContainer.backgroundColor = .white
        let profileTap = UITapGestureRecognizer(target: self, action: #selector(profileTapped))
        profileContainer.addGestureRecognizer(profileTap)
        scrollView.addSubview(profileContainer)

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = UIColor(white: 0.92, alpha: 1)
        profileContainer.addSubview(avatarImageView)

        nameLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        nameLabel.textColor = .black
        nameLabel.text = " "
        profileContainer.addSubview(nameLabel)

        phoneLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        phoneLabel.textColor = UIColor(white: 0.45, alpha: 1)
        phoneLabel.text = " "
        profileContainer.addSubview(phoneLabel)

        profileChevron.image = UIImage(systemName: "chevron.right")
        profileChevron.tintColor = UIColor(white: 0.75, alpha: 1)
        profileChevron.contentMode = .scaleAspectFit
        profileContainer.addSubview(profileChevron)

        // Separator
        separator1.backgroundColor = DivoSettingsColors.separator
        scrollView.addSubview(separator1)

        // MARK: Set Username section
        usernameContainer.backgroundColor = .white
        let usernameTap = UITapGestureRecognizer(target: self, action: #selector(usernameTapped))
        usernameContainer.addGestureRecognizer(usernameTap)
        scrollView.addSubview(usernameContainer)

        usernameIconView.text = "@"
        usernameIconView.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        usernameIconView.textColor = UIColor(white: 0.45, alpha: 1)
        usernameIconView.textAlignment = .center
        usernameIconView.backgroundColor = UIColor(red: 0.95, green: 0.92, blue: 0.90, alpha: 1)
        usernameIconView.clipsToBounds = true
        usernameContainer.addSubview(usernameIconView)

        usernameLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        usernameLabel.textColor = .black
        usernameLabel.text = DivoStrings.settingsSetUsername
        usernameContainer.addSubview(usernameLabel)

        // Separator
        separator2.backgroundColor = DivoSettingsColors.separator
        scrollView.addSubview(separator2)

        // MARK: Fill your parameters button
        parametersButton.backgroundColor = DivoSettingsColors.accent
        parametersButton.setTitle(DivoStrings.settingsFillParameters, for: .normal)
        parametersButton.setTitleColor(.white, for: .normal)
        parametersButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        parametersButton.layer.cornerRadius = 12
        parametersButton.addTarget(self, action: #selector(parametersTapped), for: .touchUpInside)
        scrollView.addSubview(parametersButton)

        // MARK: Promo banner
        bannerContainer.backgroundColor = UIColor(white: 0.15, alpha: 1)
        bannerContainer.layer.cornerRadius = 16
        bannerContainer.clipsToBounds = true
        scrollView.addSubview(bannerContainer)

        bannerImageView.contentMode = .scaleAspectFill
        bannerImageView.alpha = 0.4
        bannerContainer.addSubview(bannerImageView)

        bannerDivoLabel.text = "DIVO"
        bannerDivoLabel.font = UIFont.systemFont(ofSize: 28, weight: .light)
        bannerDivoLabel.textColor = DivoSettingsColors.accent.withAlphaComponent(0.7)
        bannerContainer.addSubview(bannerDivoLabel)

        bannerTitleLabel.text = DivoStrings.settingsBannerTitle
        bannerTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        bannerTitleLabel.textColor = .white
        bannerTitleLabel.numberOfLines = 0
        bannerContainer.addSubview(bannerTitleLabel)

        bannerDescriptionLabel.text = DivoStrings.settingsBannerDescription
        bannerDescriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        bannerDescriptionLabel.textColor = UIColor(white: 0.82, alpha: 1)
        bannerDescriptionLabel.numberOfLines = 0
        bannerContainer.addSubview(bannerDescriptionLabel)

        learnMoreButton.setTitle(DivoStrings.settingsLearnMore, for: .normal)
        learnMoreButton.setTitleColor(.white, for: .normal)
        learnMoreButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        learnMoreButton.backgroundColor = DivoSettingsColors.accent
        learnMoreButton.layer.cornerRadius = 8
        learnMoreButton.layer.borderWidth = 1
        learnMoreButton.layer.borderColor = DivoSettingsColors.accent.cgColor
        learnMoreButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        learnMoreButton.addTarget(self, action: #selector(learnMoreTapped), for: .touchUpInside)
        bannerContainer.addSubview(learnMoreButton)
        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.usernameLabel.text = DivoStrings.settingsSetUsername
            self.parametersButton.setTitle(DivoStrings.settingsFillParameters, for: .normal)
            self.bannerTitleLabel.text = DivoStrings.settingsBannerTitle
            self.bannerDescriptionLabel.text = DivoStrings.settingsBannerDescription
            self.learnMoreButton.setTitle(DivoStrings.settingsLearnMore, for: .normal)
        }
    }

    // MARK: - Layout

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let bounds = CGRect(origin: .zero, size: layout.size)
        scrollView.frame = CGRect(x: 0, y: navigationBarHeight, width: bounds.width, height: bounds.height - navigationBarHeight)

        let insets = layout.safeInsets
        let sideInset: CGFloat = 16 + insets.left
        let contentWidth = bounds.width - sideInset * 2
        var y: CGFloat = 8

        // Profile section
        let profileHeight: CGFloat = 80
        let avatarSize: CGFloat = 64
        profileContainer.frame = CGRect(x: 0, y: y, width: bounds.width, height: profileHeight)
        avatarImageView.frame = CGRect(x: sideInset, y: (profileHeight - avatarSize) / 2, width: avatarSize, height: avatarSize)
        avatarImageView.layer.cornerRadius = avatarSize / 2

        let textX = sideInset + avatarSize + 14
        let chevronSize: CGFloat = 14
        profileChevron.frame = CGRect(x: bounds.width - sideInset - chevronSize, y: (profileHeight - chevronSize) / 2, width: chevronSize, height: chevronSize)

        let textWidth = profileChevron.frame.minX - textX - 8
        nameLabel.frame = CGRect(x: textX, y: profileHeight / 2 - 24, width: textWidth, height: 26)
        phoneLabel.frame = CGRect(x: textX, y: profileHeight / 2 + 2, width: textWidth, height: 20)
        y += profileHeight

        // Separator 1
        separator1.frame = CGRect(x: sideInset, y: y, width: contentWidth, height: 0.5)
        y += 0.5

        // Username section
        let usernameHeight: CGFloat = 52
        let iconSize: CGFloat = 36
        usernameContainer.frame = CGRect(x: 0, y: y, width: bounds.width, height: usernameHeight)
        usernameIconView.frame = CGRect(x: sideInset, y: (usernameHeight - iconSize) / 2, width: iconSize, height: iconSize)
        usernameIconView.layer.cornerRadius = 8

        usernameLabel.frame = CGRect(x: sideInset + iconSize + 12, y: 0, width: contentWidth - iconSize - 12, height: usernameHeight)
        y += usernameHeight

        // Separator 2
        separator2.frame = CGRect(x: sideInset, y: y, width: contentWidth, height: 0.5)
        y += 0.5 + 20

        // Fill your parameters button
        let buttonHeight: CGFloat = 50
        parametersButton.frame = CGRect(x: sideInset, y: y, width: contentWidth, height: buttonHeight)
        y += buttonHeight + 20

        // Promo banner
        let bannerPadding: CGFloat = 20
        let bannerTextWidth = contentWidth - bannerPadding * 2

        bannerDivoLabel.frame = CGRect(x: bannerPadding, y: bannerPadding, width: bannerTextWidth, height: 32)

        let titleSize = bannerTitleLabel.sizeThatFits(CGSize(width: bannerTextWidth, height: .greatestFiniteMagnitude))
        bannerTitleLabel.frame = CGRect(x: bannerPadding, y: bannerDivoLabel.frame.maxY + 8, width: bannerTextWidth, height: titleSize.height)

        let descSize = bannerDescriptionLabel.sizeThatFits(CGSize(width: bannerTextWidth, height: .greatestFiniteMagnitude))
        bannerDescriptionLabel.frame = CGRect(x: bannerPadding, y: bannerTitleLabel.frame.maxY + 8, width: bannerTextWidth, height: descSize.height)

        let learnMoreSize = learnMoreButton.sizeThatFits(CGSize(width: bannerTextWidth, height: 44))
        learnMoreButton.frame = CGRect(x: bannerPadding, y: bannerDescriptionLabel.frame.maxY + 16, width: learnMoreSize.width, height: learnMoreSize.height)

        let bannerHeight = learnMoreButton.frame.maxY + bannerPadding
        bannerContainer.frame = CGRect(x: sideInset, y: y, width: contentWidth, height: bannerHeight)
        bannerImageView.frame = bannerContainer.bounds
        y += bannerHeight + 20

        // Bottom inset
        let bottomInset = layout.intrinsicInsets.bottom
        scrollView.contentSize = CGSize(width: bounds.width, height: y + bottomInset)
    }

    // MARK: - Data loading

    private var isProfileLoaded = false

    func reloadProfile() {
        isProfileLoaded = false
        loadProfile()
    }

    func loadProfile() {
        guard !isProfileLoaded else { return }
        startProfileShimmer()
        Task { @MainActor in
            do {
                let response: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/info"
                )
                self.isProfileLoaded = true
                self.updateWithProfile(response.data)
            } catch {
                self.stopProfileShimmer()
            }
        }
    }

    private func startProfileShimmer() {
        nameLabel.text = nil
        phoneLabel.text = nil
        let placeholderColor = UIColor(white: 0.88, alpha: 1)
        nameLabel.backgroundColor = placeholderColor
        nameLabel.layer.cornerRadius = 4
        nameLabel.clipsToBounds = true
        phoneLabel.backgroundColor = placeholderColor
        phoneLabel.layer.cornerRadius = 4
        phoneLabel.clipsToBounds = true
        [avatarImageView, nameLabel, phoneLabel].forEach { $0.startSettingsShimmer() }
    }

    private func stopProfileShimmer() {
        [avatarImageView, nameLabel, phoneLabel].forEach { $0.stopSettingsShimmer() }
        nameLabel.backgroundColor = .clear
        phoneLabel.backgroundColor = .clear
    }

    private func updateWithProfile(_ user: UserDetail) {
        stopProfileShimmer()
        nameLabel.text = user.fullName ?? "User"
        phoneLabel.text = user.phone ?? ""

        // Load avatar
        if let avatarURL = CDNURLHelper.convertToCDNURL(user.avatar?.fullUrl) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: avatarURL)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.avatarImageView.image = image
                            self.avatarImageView.applyAvatarTopCropIfNeeded(image: image)
                        }
                    }
                } catch {}
            }
        }
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

    @objc private func learnMoreTapped() {
        onLearnMoreTapped?()
    }
}
