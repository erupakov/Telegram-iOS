import UIKit
import Display
import DivoUIKit
import DivoCore

/// Promo-баннер для экрана Settings. Готовый компонент — подключается одной
/// строкой `setupBannerSection()` в `DivoSettingsNode.setupUI()` в релизе,
/// когда фича включится.
final class BannerView: UIView {

    private enum Layout {
        static let logoHeight: CGFloat = 30
        static let logoWidth: CGFloat = 78
        static let titleTopOffset: CGFloat = 20
        static let descriptionTopOffset: CGFloat = 6
        static let buttonTopOffset: CGFloat = 12
        static let buttonHeight: CGFloat = 40
    }

    private let bannerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        return view
    }()

    private let bannerImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = DivoImage.settingsBannerBackground
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = DivoDesignTokens.Radius.l
        return iv
    }()

    private let bannerLogoView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = DivoImage.settingsSmallLogo
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    private let bannerTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(16)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.settingsBannerTitle.uppercased()
        return label
    }()

    private let bannerDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.bannerSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.settingsBannerDescription
        label.numberOfLines = 0
        return label
    }()

    private let learnMoreButton = DivoButton()

    var onLearnMoreTapped: (() -> Void)?

    init() {
        super.init(frame: .zero)

        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        learnMoreButton.makeDivoButton(title: DivoStrings.settingsLearnMore, buttonFont: Font.helveticaNeue(16), radius: DivoDesignTokens.Radius.pill)

        addSubview(bannerContainer)
        bannerContainer.addSubview(bannerImageView)
        bannerContainer.addSubview(bannerLogoView)
        bannerContainer.addSubview(bannerTitleLabel)
        bannerContainer.addSubview(bannerDescriptionLabel)
        bannerContainer.addSubview(learnMoreButton)

        learnMoreButton.addTarget(self, action: #selector(learnMoreTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            bannerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            bannerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            bannerContainer.topAnchor.constraint(equalTo: topAnchor),
            bannerContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            bannerImageView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
            bannerImageView.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor),
            bannerImageView.topAnchor.constraint(equalTo: bannerContainer.topAnchor),
            bannerImageView.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor),

            bannerLogoView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bannerLogoView.topAnchor.constraint(equalTo: bannerContainer.topAnchor, constant: DivoDesignTokens.Spacing.l),
            bannerLogoView.heightAnchor.constraint(equalToConstant: Layout.logoHeight),
            bannerLogoView.widthAnchor.constraint(equalToConstant: Layout.logoWidth),

            bannerTitleLabel.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bannerTitleLabel.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bannerTitleLabel.topAnchor.constraint(equalTo: bannerLogoView.bottomAnchor, constant: Layout.titleTopOffset),

            bannerDescriptionLabel.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bannerDescriptionLabel.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bannerDescriptionLabel.topAnchor.constraint(equalTo: bannerTitleLabel.bottomAnchor, constant: Layout.descriptionTopOffset),

            learnMoreButton.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            learnMoreButton.topAnchor.constraint(equalTo: bannerDescriptionLabel.bottomAnchor, constant: Layout.buttonTopOffset),
            learnMoreButton.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            learnMoreButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.buttonHeight),
        ])
    }

    @objc private func learnMoreTapped() {
        onLearnMoreTapped?()
    }
}
