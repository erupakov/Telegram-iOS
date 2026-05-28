import UIKit
import Display

/// Кастомный alert dialog в DIVO-стиле.
///
/// Подтверждение деструктивных действий (logout, удаление модели, удаление события и т.п.).
/// Презентуется поверх view контроллера или поверх key window приложения.
///
/// API:
/// ```swift
/// DivoAlertView.present(
///     in: viewController,
///     title: "Выйти?",
///     message: nil,
///     cancelTitle: DivoStrings.cancel,
///     actionTitle: DivoStrings.logOut,
///     actionHandler: { /* logout */ }
/// )
/// ```
public final class DivoAlertView: UIView {

    // MARK: - Layout tokens

    private enum Layout {
        /// Целевая ширина card; на узких экранах сжимается до краёв с отступом `safeAreaInset`.
        static let cardWidth: CGFloat = 270
        /// 30 — corner radius card. TODO: DS alignment — не в шкале DivoDesignTokens.Radius.
        static let cardCornerRadius: CGFloat = 30
        /// Padding внутри card от краёв до содержимого со всех сторон.
        static let cardPadding: CGFloat = 20
        /// Gap между title и description.
        static let titleDescriptionGap: CGFloat = 4
        /// Gap между текстовым блоком и кнопками.
        static let textsToButtonsGap: CGFloat = 34
        /// Gap между кнопками.
        static let buttonsGap: CGFloat = 4
        /// Высота каждой кнопки.
        static let buttonHeight: CGFloat = 40
        /// Минимальное расстояние от alert до краёв экрана.
        static let safeAreaInset: CGFloat = 16
    }

    private enum AnimationToken {
        static let duration: TimeInterval = 0.25
        static let scaleFrom: CGFloat = 0.9
    }

    // MARK: - Subviews

    private let backdropView = UIView()
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let buttonsContainer = UIStackView()
    private let cancelButton = UIButton(type: .custom)
    private let actionButton = UIButton(type: .custom)

    // MARK: - State

    private var cancelHandler: (() -> Void)?
    private var actionHandler: (() -> Void)?
    /// Удерживает собственный UIWindow на время презентации (когда alert показан без viewController).
    private var hostingWindow: UIWindow?

    // MARK: - Init

    private init() {
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    @discardableResult
    public static func present(
        in viewController: UIViewController? = nil,
        title: String,
        message: String? = nil,
        cancelTitle: String,
        cancelHandler: (() -> Void)? = nil,
        actionTitle: String,
        actionHandler: @escaping () -> Void
    ) -> DivoAlertView {
        let alert = DivoAlertView()
        alert.configure(
            title: title,
            message: message,
            cancelTitle: cancelTitle,
            cancelHandler: cancelHandler,
            actionTitle: actionTitle,
            actionHandler: actionHandler
        )

        if let vc = viewController {
            alert.attach(to: vc.view)
        } else {
            alert.attachInOwnWindow()
        }
        alert.animateIn()
        return alert
    }

    /// Создаёт собственный `UIWindow` с `windowLevel = .alert` и показывает alert в нём.
    /// Гарантирует, что тапы попадают в наш UI, а не «протекают» в нижние окна/overlay'и
    /// (Telegram-iOS использует множественные windows для navigation/keyboard/etc).
    private func attachInOwnWindow() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert
        window.backgroundColor = .clear

        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear
        window.rootViewController = rootVC

        hostingWindow = window
        window.makeKeyAndVisible()

        attach(to: rootVC.view)
    }

    // MARK: - Setup

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false

        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.backgroundColor = DivoColorPalette.alertBackdrop
        addSubview(backdropView)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = DivoColorPalette.alertCardBackground
        cardView.layer.cornerRadius = Layout.cardCornerRadius
        cardView.layer.masksToBounds = true
        addSubview(cardView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .center
        // Разрешаем label сжиматься по горизонтали — иначе он распирает card шире 270pt,
        // чтобы вместить текст в одну строку, и numberOfLines=0 не срабатывает.
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        cardView.addSubview(titleLabel)

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.numberOfLines = 0
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.textAlignment = .center
        descriptionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        descriptionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        cardView.addSubview(descriptionLabel)

        buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonsContainer.axis = .horizontal
        buttonsContainer.distribution = .fillEqually
        buttonsContainer.spacing = Layout.buttonsGap
        cardView.addSubview(buttonsContainer)

        configureButton(cancelButton, style: .secondary)
        configureButton(actionButton, style: .primary)
        buttonsContainer.addArrangedSubview(cancelButton)
        buttonsContainer.addArrangedSubview(actionButton)

        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }

    private func configureButton(_ button: UIButton, style: DivoButtonStyle) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = Layout.buttonHeight / 2
        button.layer.masksToBounds = true
        button.heightAnchor.constraint(equalToConstant: Layout.buttonHeight).isActive = true
        button.addDivoPressState(style)
    }

    private func configure(
        title: String,
        message: String?,
        cancelTitle: String,
        cancelHandler: (() -> Void)?,
        actionTitle: String,
        actionHandler: @escaping () -> Void
    ) {
        self.cancelHandler = cancelHandler
        self.actionHandler = actionHandler

        titleLabel.attributedText = Self.makeTitleAttributedString(title)

        if let message {
            descriptionLabel.attributedText = Self.makeDescriptionAttributedString(message)
            descriptionLabel.isHidden = false
        } else {
            descriptionLabel.isHidden = true
        }

        cancelButton.setAttributedTitle(Self.makeButtonAttributedString(cancelTitle), for: .normal)
        actionButton.setAttributedTitle(Self.makeButtonAttributedString(actionTitle), for: .normal)
    }

    private func attach(to host: UIView) {
        host.addSubview(self)

        // Self заполняет весь host — это позволяет backdrop'у поймать любой тап и заблокировать UI под ним.
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: host.topAnchor),
            leadingAnchor.constraint(equalTo: host.leadingAnchor),
            trailingAnchor.constraint(equalTo: host.trailingAnchor),
            bottomAnchor.constraint(equalTo: host.bottomAnchor),

            backdropView.topAnchor.constraint(equalTo: topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Ширина card: целевая 270, но не больше чем экран − 2×safeAreaInset.
        let preferredWidth = cardView.widthAnchor.constraint(equalToConstant: Layout.cardWidth)
        preferredWidth.priority = .defaultHigh
        let maxWidth = cardView.widthAnchor.constraint(
            lessThanOrEqualTo: widthAnchor,
            constant: -Layout.safeAreaInset * 2
        )
        NSLayoutConstraint.activate([preferredWidth, maxWidth])

        let titleTop = titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Layout.cardPadding)
        let titleLeading = titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Layout.cardPadding)
        let titleTrailing = titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Layout.cardPadding)

        let descriptionLeading = descriptionLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Layout.cardPadding)
        let descriptionTrailing = descriptionLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Layout.cardPadding)

        let buttonsLeading = buttonsContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Layout.cardPadding)
        let buttonsTrailing = buttonsContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Layout.cardPadding)
        let buttonsBottom = buttonsContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -Layout.cardPadding)

        NSLayoutConstraint.activate([
            titleTop, titleLeading, titleTrailing,
            descriptionLeading, descriptionTrailing,
            buttonsLeading, buttonsTrailing, buttonsBottom,
        ])

        if descriptionLabel.isHidden {
            buttonsContainer.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: Layout.textsToButtonsGap
            ).isActive = true
        } else {
            descriptionLabel.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: Layout.titleDescriptionGap
            ).isActive = true
            buttonsContainer.topAnchor.constraint(
                equalTo: descriptionLabel.bottomAnchor,
                constant: Layout.textsToButtonsGap
            ).isActive = true
        }
    }

    // MARK: - Animation

    private func animateIn() {
        backdropView.alpha = 0
        cardView.alpha = 0
        cardView.transform = CGAffineTransform(scaleX: AnimationToken.scaleFrom, y: AnimationToken.scaleFrom)

        UIView.animate(withDuration: AnimationToken.duration, delay: 0, options: .curveEaseOut) {
            self.backdropView.alpha = 1
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(
            withDuration: AnimationToken.duration,
            delay: 0,
            options: .curveEaseIn,
            animations: {
                self.backdropView.alpha = 0
                self.cardView.alpha = 0
                self.cardView.transform = CGAffineTransform(
                    scaleX: AnimationToken.scaleFrom,
                    y: AnimationToken.scaleFrom
                )
            },
            completion: { _ in
                self.removeFromSuperview()
                if let window = self.hostingWindow {
                    window.isHidden = true
                    self.hostingWindow = nil
                }
                completion()
            }
        )
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        let handler = self.cancelHandler
        animateOut { handler?() }
    }

    @objc private func actionTapped() {
        let handler = self.actionHandler
        animateOut { handler?() }
    }

    // MARK: - Attributed strings

    private static func makeTitleAttributedString(_ text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 22
        paragraph.maximumLineHeight = 22
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        return NSAttributedString(string: text, attributes: [
            .font: Font.semibold(17),
            .foregroundColor: DivoColorPalette.alertTitleText,
            .kern: -0.41,
            .paragraphStyle: paragraph,
        ])
    }

    private static func makeDescriptionAttributedString(_ text: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 18
        paragraph.maximumLineHeight = 18
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        return NSAttributedString(string: text, attributes: [
            .font: Font.regular(13),
            .foregroundColor: DivoColorPalette.alertDescriptionText,
            .kern: -0.08,
            .paragraphStyle: paragraph,
        ])
    }

    private static func makeButtonAttributedString(_ text: String) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [
            .font: Font.helveticaNeue(16),
            .foregroundColor: DivoColorPalette.primaryTextOnDark,
            .kern: 16 * 0.005,
        ])
    }

}
