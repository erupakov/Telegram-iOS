import UIKit
import Display
import DivoCore
import DivoUIKit

/// Welcome / entry-point экран авторизации DIVO.
///
/// Три пути входа (соответствуют 4 путям из плана Eugene'а):
/// - Continue with phone — путь 3 (teamgram), реальный
/// - Sign In with Google — путь 1, заглушка «Coming soon»
/// - Sign In with Apple — путь 2, заглушка «Coming soon»
///
/// Презентуется как корневой контроллер AuthorizationSequenceController в `.empty` state.
/// Наследуется от Display.ViewController (не UIViewController), так как
/// NavigationController в Telegram-iOS форс-кастит свои children к ViewController.
public final class DivoAuthWelcomeController: ViewController {

    // MARK: - Layout

    private enum Layout {
        static let sidePadding: CGFloat = 24
        static let topPadding: CGFloat = 88
        static let titleSubtitleGap: CGFloat = 10
        static let subtitleToContinueGap: CGFloat = 32
        static let continueToSeparatorGap: CGFloat = 39
        static let separatorToGoogleGap: CGFloat = 39
        static let googleToAppleGap: CGFloat = 16
        static let appleToTermsGap: CGFloat = 32
        static let bottomPadding: CGFloat = 24
        static let separatorHeight: CGFloat = 16
    }

    // MARK: - Callbacks

    public var onContinueWithPhone: (() -> Void)?
    public var onSignInWithGoogle: (() -> Void)?
    public var onSignInWithApple: (() -> Void)?
    public var onOpenTerms: (() -> Void)?
    public var onOpenPrivacy: (() -> Void)?

    // MARK: - Subviews

    private let scrollView = UIScrollView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let continueButton = DivoButton()
    private let orSeparator = ORSeparatorView()
    private let googleButton = WhiteOAuthButton()
    private let appleButton = WhiteOAuthButton()
    private let termsLabel = UILabel()
    private let snackbar = DivoSnackbar()

    // MARK: - Init

    public init() {
        super.init(navigationBarPresentationData: nil)
    }

    @available(*, unavailable)
    required init(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.screenBackground

        configureTitle()
        configureSubtitle()
        configureContinueButton()
        configureGoogleButton()
        configureAppleButton()
        configureTermsLabel()
        layoutAll()
    }

    // MARK: - Configuration

    private func configureTitle() {
        // Helvetica Neue LT Com 77 Bold Condensed 32 / 100% / letter-spacing 0.5pt / uppercase
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 32
        paragraph.maximumLineHeight = 32
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        titleLabel.attributedText = NSAttributedString(
            string: DivoStrings.authWelcomeTitle.uppercased(),
            attributes: [
                .font: Font.helveticaNeue(32),
                .foregroundColor: DivoColorPalette.primaryText,
                .kern: 0.5,
                .paragraphStyle: paragraph,
            ]
        )
        titleLabel.numberOfLines = 0
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func configureSubtitle() {
        // Helvetica Neue Regular 16 / 130% line height / color #222222CC
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 21
        paragraph.maximumLineHeight = 21
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        subtitleLabel.attributedText = NSAttributedString(
            string: DivoStrings.authWelcomeSubtitle,
            attributes: [
                .font: DivoFont.helveticaNeueRegular(16),
                .foregroundColor: DivoColorPalette.authMutedText,
                .paragraphStyle: paragraph,
            ]
        )
        subtitleLabel.numberOfLines = 0
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func configureContinueButton() {
        continueButton.makeDivoButton(
            title: DivoStrings.authContinueWithPhone,
            buttonFont: Font.helveticaNeue(18),
            divoButtonStyle: .primary
        )
        continueButton.addTarget(self, action: #selector(continueWithPhoneTapped), for: .touchUpInside)
    }

    private func configureGoogleButton() {
        let icon = DivoImage.authGoogleLogo.withRenderingMode(.alwaysOriginal)
        googleButton.configure(title: DivoStrings.authSignInWithGoogle, icon: icon)
        googleButton.addTarget(self, action: #selector(googleTapped), for: .touchUpInside)
    }

    private func configureAppleButton() {
        let icon = DivoImage.authAppleLogo.withTintColor(DivoColorPalette.authOAuthButtonText, renderingMode: .alwaysOriginal)
        appleButton.configure(title: DivoStrings.authSignInWithApple, icon: icon)
        appleButton.addTarget(self, action: #selector(appleTapped), for: .touchUpInside)
    }

    private func configureTermsLabel() {
        let prefix = DivoStrings.authTermsAndPrivacyPrefix
        let terms = DivoStrings.authTermsOfService
        let conj = DivoStrings.authTermsAndPrivacyConjunction
        let privacy = DivoStrings.authPrivacyPolicy
        let full = "\(prefix) \(terms) \(conj) \(privacy)."

        // Helvetica Neue Regular 14 / 130% line height / letter-spacing 0
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 18
        paragraph.maximumLineHeight = 18
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let attr = NSMutableAttributedString(string: full, attributes: [
            .font: DivoFont.helveticaNeueRegular(14),
            .foregroundColor: DivoColorPalette.authTermsText,
            .paragraphStyle: paragraph,
        ])
        let ns = full as NSString
        let termsRange = ns.range(of: terms)
        if termsRange.location != NSNotFound {
            attr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: termsRange)
        }
        let privacyRange = ns.range(of: privacy)
        if privacyRange.location != NSNotFound {
            attr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: privacyRange)
        }

        termsLabel.attributedText = attr
        termsLabel.textAlignment = .center
        termsLabel.numberOfLines = 0
        termsLabel.isUserInteractionEnabled = true
        termsLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(termsLabelTapped(_:))))
    }

    private func layoutAll() {
        // Скролл нужен только если контент не влезает (iPhone SE / landscape).
        // alwaysBounceVertical=false — bounce и скролл только при превышении размера.
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            spacing(Layout.titleSubtitleGap),
            subtitleLabel,
            spacing(Layout.subtitleToContinueGap),
            continueButton,
            spacing(Layout.continueToSeparatorGap),
            orSeparator,
            spacing(Layout.separatorToGoogleGap),
            googleButton,
            spacing(Layout.googleToAppleGap),
            appleButton,
            spacing(Layout.appleToTermsGap),
            termsLabel,
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Layout.topPadding),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Layout.bottomPadding),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Layout.sidePadding),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Layout.sidePadding),

            // Ширина stack привязана к frameLayoutGuide — это даёт scrollView
            // правильный intrinsic content size по вертикали (контент не скроллится горизонтально).
            stack.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor,
                constant: -Layout.sidePadding * 2
            ),
        ])
    }

    private func spacing(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    // MARK: - Actions

    @objc private func continueWithPhoneTapped() {
        onContinueWithPhone?()
    }

    @objc private func googleTapped() {
        if let handler = onSignInWithGoogle {
            handler()
        } else {
            showComingSoon()
        }
    }

    @objc private func appleTapped() {
        if let handler = onSignInWithApple {
            handler()
        } else {
            showComingSoon()
        }
    }

    @objc private func termsLabelTapped(_ recognizer: UITapGestureRecognizer) {
        guard let attr = termsLabel.attributedText else { return }
        let location = recognizer.location(in: termsLabel)
        let terms = DivoStrings.authTermsOfService
        let privacy = DivoStrings.authPrivacyPolicy
        let nsText = attr.string as NSString

        if pointInRange(location, of: nsText.range(of: terms), in: termsLabel) {
            onOpenTerms?()
        } else if pointInRange(location, of: nsText.range(of: privacy), in: termsLabel) {
            onOpenPrivacy?()
        }
    }

    private func pointInRange(_ point: CGPoint, of range: NSRange, in label: UILabel) -> Bool {
        guard range.location != NSNotFound, let attr = label.attributedText else { return false }
        let textStorage = NSTextStorage(attributedString: attr)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: label.bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.maximumNumberOfLines = label.numberOfLines
        layoutManager.addTextContainer(textContainer)
        let index = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        return NSLocationInRange(index, range)
    }

    private func showComingSoon() {
        snackbar.show(
            in: view,
            message: DivoStrings.authComingSoon,
            style: .success,
            bottomInset: 24
        )
    }
}

// MARK: - White OAuth button (Google / Apple)

private final class WhiteOAuthButton: UIButton {

    private enum Layout {
        static let height: CGFloat = 56
        static let cornerRadius: CGFloat = 28
        static let horizontalPadding: CGFloat = 24
        static let iconTitleGap: CGFloat = 8
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = DivoColorPalette.cardBackground
        layer.cornerRadius = Layout.cornerRadius
        heightAnchor.constraint(equalToConstant: Layout.height).isActive = true
        addDivoPressState(.pill)

        contentEdgeInsets = UIEdgeInsets(top: 0, left: Layout.horizontalPadding, bottom: 0, right: Layout.horizontalPadding)
        imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: Layout.iconTitleGap)
        titleEdgeInsets = UIEdgeInsets(top: 0, left: Layout.iconTitleGap, bottom: 0, right: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, icon: UIImage?) {
        // Helvetica Neue Medium 16 / 130% / letter-spacing 0 / color #0A0A0A
        let attr: [NSAttributedString.Key: Any] = [
            .font: DivoFont.helveticaNeueMedium(16),
            .foregroundColor: DivoColorPalette.authOAuthButtonText,
        ]
        setAttributedTitle(NSAttributedString(string: title, attributes: attr), for: .normal)
        setImage(icon, for: .normal)
    }
}

// MARK: - "or" separator

private final class ORSeparatorView: UIView {

    private let leftLine = UIView()
    private let rightLine = UIView()
    private let label = UILabel()

    var text: String = "or" {
        didSet { label.text = text }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        leftLine.backgroundColor = DivoColorPalette.authSeparatorLine
        leftLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftLine)

        rightLine.backgroundColor = DivoColorPalette.authSeparatorLine
        rightLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rightLine)

        label.text = DivoStrings.authSeparatorOr
        // Helvetica Neue Regular 12 / 100% line height / letter-spacing 0 / color #222222CC
        label.font = DivoFont.helveticaNeueRegular(12)
        label.textColor = DivoColorPalette.authMutedText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 16),

            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            leftLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            leftLine.trailingAnchor.constraint(equalTo: label.leadingAnchor, constant: -24),
            leftLine.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftLine.heightAnchor.constraint(equalToConstant: 1),

            rightLine.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 24),
            rightLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightLine.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightLine.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
