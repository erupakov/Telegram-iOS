import UIKit
import Display

public final class DivoEmptyStateView: UIView {

    public struct Configuration {
        public let icon: UIImage
        public let title: String
        public let subtitle: String
        public let ctaTitle: String?
        public let onCTATapped: (() -> Void)?
        public let secondaryCtaTitle: String?
        public let onSecondaryCTATapped: (() -> Void)?
        public let iconSize: CGFloat?

        public init(
            icon: UIImage,
            title: String,
            subtitle: String,
            ctaTitle: String? = nil,
            onCTATapped: (() -> Void)? = nil,
            secondaryCtaTitle: String? = nil,
            onSecondaryCTATapped: (() -> Void)? = nil,
            iconSize: CGFloat? = nil
        ) {
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.ctaTitle = ctaTitle
            self.onCTATapped = onCTATapped
            self.secondaryCtaTitle = secondaryCtaTitle
            self.onSecondaryCTATapped = onSecondaryCTATapped
            self.iconSize = iconSize
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
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?

    public init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    public func configure(_ config: Configuration) {
        titleLabel.text = config.title.uppercased()
        subtitleLabel.text = config.subtitle

        if let size = config.iconSize {
            iconView.image = config.icon.withRenderingMode(.alwaysOriginal)
            circleView.backgroundColor = .clear
            iconWidthConstraint?.constant = size
            iconHeightConstraint?.constant = size
        } else {
            iconView.image = config.icon.withRenderingMode(.alwaysTemplate)
            circleView.backgroundColor = DivoColorPalette.emptyCircleBackground
            iconWidthConstraint?.constant = 32
            iconHeightConstraint?.constant = 32
        }

        if let ctaTitle = config.ctaTitle {
            installCTAIfNeeded()
            ctaButton?.makeDivoButton(title: ctaTitle)
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

        NSLayoutConstraint.activate([
            circleView.widthAnchor.constraint(equalToConstant: circleSize),
            circleView.heightAnchor.constraint(equalToConstant: circleSize),

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
        NSLayoutConstraint.activate([
            buttonsStack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            buttonsStack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            buttonsStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
    }

    private func installCTAIfNeeded() {
        installButtonsStackIfNeeded()
        guard ctaButton == nil else { return }

        let button = DivoButton()
        button.addTarget(self, action: #selector(ctaTapped), for: .touchUpInside)
        buttonsStack.insertArrangedSubview(button, at: 0)

        ctaButton = button
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
