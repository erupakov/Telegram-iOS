import UIKit
import Display

public final class DivoEmptyStateView: UIView {

    /// Визуальный стиль эмпти-стейта. Иконка binding'ом к стилю — там где она показывается.
    public enum Style {
        /// Белый круг 68×68 (полупрозрачный `emptyCircleBackground`) + иконка 24×24, tint `profileEmptyIconTint`. Для эмпти на сером фоне (лента, поиск, список Events).
        case smallOnTinted(icon: UIImage)
        /// Серый круг 68×68 (`profileEmptyCircleBackground`) + иконка 24×24, tint `profileEmptyIconTint`. Контейнер красится в белый. Для профильных табов.
        case smallOnLight(icon: UIImage)
        /// Иконка 68×68 без круга, в оригинальной отрисовке. Переходный кейс — для face-search error и подобных.
        case largeIcon(icon: UIImage)
        /// Только тексты, без иконки и круга.
        case textOnly
    }

    public struct Configuration {
        public let style: Style
        public let title: String
        public let subtitle: String
        public let ctaTitle: String?
        public let ctaLeadingIcon: UIImage?
        public let onCTATapped: (() -> Void)?
        public let secondaryCtaTitle: String?
        public let onSecondaryCTATapped: (() -> Void)?

        public init(
            style: Style,
            title: String,
            subtitle: String,
            ctaTitle: String? = nil,
            ctaLeadingIcon: UIImage? = nil,
            onCTATapped: (() -> Void)? = nil,
            secondaryCtaTitle: String? = nil,
            onSecondaryCTATapped: (() -> Void)? = nil
        ) {
            self.style = style
            self.title = title
            self.subtitle = subtitle
            self.ctaTitle = ctaTitle
            self.ctaLeadingIcon = ctaLeadingIcon
            self.onCTATapped = onCTATapped
            self.secondaryCtaTitle = secondaryCtaTitle
            self.onSecondaryCTATapped = onSecondaryCTATapped
        }
    }

    private let circleView: UIView = {
        let v = UIView()
        v.backgroundColor = DivoColorPalette.emptyCircleBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = DivoColorPalette.emptyIconTint
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = Font.helveticaNeue(26)
        l.textColor = DivoColorPalette.primaryText
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = Font.medium(16)
        l.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let buttonsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = DivoDesignTokens.Spacing.s
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private var ctaButton: DivoButton?
    private var ctaAction: (() -> Void)?
    private var secondaryCtaButton: UIButton?
    private var secondaryCtaAction: (() -> Void)?
    private var buttonsStackBottomConstraint: NSLayoutConstraint?

    /// Дополнительный нижний отступ блока кнопок сверх safe area. Нужен, когда эмпти-стейт
    /// лежит под overlay-таббаром Telegram — `safeAreaLayoutGuide` его не учитывает, и хост
    /// передаёт сюда высоту таббара, чтобы CTA не уезжала под него.
    public var additionalBottomInset: CGFloat = 0 {
        didSet {
            guard oldValue != additionalBottomInset else { return }
            buttonsStackBottomConstraint?.constant = -(DivoDesignTokens.Spacing.m + additionalBottomInset)
        }
    }
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private var circleWidthConstraint: NSLayoutConstraint?
    private var circleHeightConstraint: NSLayoutConstraint?

    public init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func configure(_ config: Configuration) {
        UIView.performWithoutAnimation {
            self._configure(config)
            self.layoutIfNeeded()
        }
    }

    private func _configure(_ config: Configuration) {
        titleLabel.text = config.title.uppercased()
        subtitleLabel.text = config.subtitle

        applyStyle(config.style)

        let inlineCTA = isInlineCTA(for: config.style)

        if let ctaTitle = config.ctaTitle {
            let button = installCTAButton(inline: inlineCTA)
            // По дизайну compact-CTA в empty-state: HelveticaNeue-CondensedBold 16.
            // Полноразмерная (non-compact) CTA остаётся на дефолтных 20pt.
            let buttonFont = inlineCTA ? Font.helveticaNeue(16) : Font.helveticaNeue(20)
            if let leadingIcon = config.ctaLeadingIcon {
                button.makeDivoButton(title: ctaTitle, leadingIcon: leadingIcon, buttonFont: buttonFont, compact: inlineCTA)
            } else {
                button.makeDivoButton(title: ctaTitle, buttonFont: buttonFont)
            }
            ctaAction = config.onCTATapped
        } else {
            ctaButton?.removeFromSuperview()
            ctaButton = nil
            ctaAction = nil
        }

        if let secondaryTitle = config.secondaryCtaTitle {
            installSecondaryCTAIfNeeded()
            secondaryCtaButton?.setTitle(secondaryTitle, for: .normal)
            secondaryCtaAction = config.onSecondaryCTATapped
        } else {
            secondaryCtaButton?.removeFromSuperview()
            secondaryCtaButton = nil
            secondaryCtaAction = nil
        }
    }

    private func applyStyle(_ style: Style) {
        switch style {
        case let .smallOnTinted(icon):
            iconView.image = icon.withRenderingMode(.alwaysTemplate)
            iconView.tintColor = DivoColorPalette.profileEmptyIconTint
            circleView.isHidden = false
            circleView.backgroundColor = DivoColorPalette.emptyCircleBackground
            setCircleSize(68)
            setIconSize(24)

        case let .smallOnLight(icon):
            backgroundColor = DivoColorPalette.profileEmptyBackground
            iconView.image = icon.withRenderingMode(.alwaysTemplate)
            iconView.tintColor = DivoColorPalette.profileEmptyIconTint
            circleView.isHidden = false
            circleView.backgroundColor = DivoColorPalette.profileEmptyCircleBackground
            setCircleSize(68)
            setIconSize(24)

        case let .largeIcon(icon):
            iconView.image = icon.withRenderingMode(.alwaysOriginal)
            circleView.isHidden = false
            circleView.backgroundColor = .clear
            setCircleSize(68)
            setIconSize(68)

        case .textOnly:
            iconView.image = nil
            circleView.isHidden = true
            circleView.backgroundColor = .clear
            setCircleSize(0)
            setIconSize(0)
        }
    }

    private func setCircleSize(_ size: CGFloat) {
        circleWidthConstraint?.constant = size
        circleHeightConstraint?.constant = size
        circleView.layer.cornerRadius = size / 2
    }

    private func setIconSize(_ size: CGFloat) {
        iconWidthConstraint?.constant = size
        iconHeightConstraint?.constant = size
    }

    private func setupUI() {
        let circleSize: CGFloat = 80

        addSubview(contentStack)
        contentStack.addArrangedSubview(circleView)
        contentStack.setCustomSpacing(20, after: circleView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(DivoDesignTokens.Spacing.s, after: titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)

        circleView.addSubview(iconView)

        let wc = iconView.widthAnchor.constraint(equalToConstant: 32)
        let hc = iconView.heightAnchor.constraint(equalToConstant: 32)
        iconWidthConstraint = wc
        iconHeightConstraint = hc

        let cwc = circleView.widthAnchor.constraint(equalToConstant: circleSize)
        let chc = circleView.heightAnchor.constraint(equalToConstant: circleSize)
        circleWidthConstraint = cwc
        circleHeightConstraint = chc

        NSLayoutConstraint.activate([
            cwc, chc,

            iconView.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),
            wc, hc,

            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -50),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.xl),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.xl),
        ])

        circleView.layer.cornerRadius = circleSize / 2
    }

    private func installButtonsStackIfNeeded() {
        guard buttonsStack.superview == nil else { return }
        addSubview(buttonsStack)
        let bottom = buttonsStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -(DivoDesignTokens.Spacing.m + additionalBottomInset))
        buttonsStackBottomConstraint = bottom
        NSLayoutConstraint.activate([
            buttonsStack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            buttonsStack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bottom,
        ])
    }

    private func isInlineCTA(for style: Style) -> Bool {
        if case .smallOnLight = style { return true }
        return false
    }

    private func installCTAButton(inline: Bool) -> DivoButton {
        if let existing = ctaButton {
            let alreadyInline = contentStack.arrangedSubviews.contains(existing)
            if alreadyInline == inline {
                return existing
            }
            existing.removeFromSuperview()
        }

        let button = DivoButton()
        button.addTarget(self, action: #selector(ctaTapped), for: .touchUpInside)

        if inline {
            contentStack.addArrangedSubview(button)
            contentStack.setCustomSpacing(16, after: subtitleLabel)
        } else {
            installButtonsStackIfNeeded()
            buttonsStack.insertArrangedSubview(button, at: 0)
        }

        ctaButton = button
        return button
    }

    private func installSecondaryCTAIfNeeded() {
        installButtonsStackIfNeeded()
        guard secondaryCtaButton == nil else { return }

        let button = UIButton(type: .custom)
        button.setTitleColor(DivoColorPalette.primaryTextOnDark, for: .normal)
        button.titleLabel?.font = Font.helveticaNeue(20)
        button.backgroundColor = DivoColorPalette.secondaryButtonBackground
        button.layer.cornerRadius = 28 // соответствует DivoButton
        button.addDivoPressState(.secondary)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        button.addTarget(self, action: #selector(secondaryCtaTapped), for: .touchUpInside)
        buttonsStack.addArrangedSubview(button)

        secondaryCtaButton = button
    }

    @objc private func ctaTapped() {
        ctaAction?()
    }

    @objc private func secondaryCtaTapped() {
        secondaryCtaAction?()
    }

    /// Проигрывает spring-анимацию появления: круг масштабируется 0.6→1, текст выезжает снизу.
    /// Вызывать после добавления view на иерархию и applying layout.
    public func animateAppearance() {
        alpha = 0
        circleView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: []) {
            self.alpha = 1
            self.circleView.transform = .identity
        }
        UIView.animate(withDuration: 0.35, delay: 0.1, options: [.curveEaseOut]) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }
        UIView.animate(withDuration: 0.35, delay: 0.15, options: [.curveEaseOut]) {
            self.subtitleLabel.alpha = 1
            self.subtitleLabel.transform = .identity
        }
    }
}
