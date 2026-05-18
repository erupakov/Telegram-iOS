import UIKit
import Display
import DivoCore
import DivoUIKit

/// Универсальный result-экран Phase 3.3 («YOU'RE A …»).
/// Один контроллер на все 9 вариантов — отличаются текстом, картинкой и тем,
/// какую форму открывают дальше.
///
/// Михаил при вёрстке оставляет API контроллера (`configure(...)`, `delegate`)
/// неизменным; меняет только размещение subviews / типографику / тени и привязывает
/// финальные ассеты по имени `presentation.imageAssetName` через `DivoImage.<name>`.
public final class OnboardingRoleResultViewController: UIViewController {

    public protocol Delegate: AnyObject {
        func roleResultControllerDidConfirm(_ controller: OnboardingRoleResultViewController)
        func roleResultControllerDidRequestRestart(_ controller: OnboardingRoleResultViewController)
        func roleResultControllerDidTapBack(_ controller: OnboardingRoleResultViewController)
    }

    public weak var delegate: Delegate?

    // MARK: - UI

    private let imageView = UIImageView()
    private let gradientOverlay = CAGradientLayer()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let primaryButton = DivoButton()
    private let secondaryButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)

    private var presentation: OnboardingResultPresentation

    // MARK: - Init

    public init(presentation: OnboardingResultPresentation) {
        self.presentation = presentation
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    public func configure(presentation: OnboardingResultPresentation) {
        self.presentation = presentation
        if isViewLoaded { applyPresentation() }
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.darkBackground
        setupUI()
        applyPresentation()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientOverlay.frame = imageView.bounds
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - UI

    private func setupUI() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = DivoColorPalette.placeholderCardBackground

        gradientOverlay.colors = [
            UIColor.clear.cgColor,
            DivoColorPalette.darkBackground.withAlphaComponent(0.9).cgColor,
            DivoColorPalette.darkBackground.cgColor,
        ]
        gradientOverlay.locations = [0.4, 0.75, 1.0]
        imageView.layer.addSublayer(gradientOverlay)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = DivoColorPalette.primaryTextOnDark
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Font.helveticaNeue(28)
        titleLabel.textColor = DivoColorPalette.primaryTextOnDark
        titleLabel.numberOfLines = 0

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = Font.regular(14)
        descriptionLabel.textColor = DivoColorPalette.textOnDarkSecondary
        descriptionLabel.numberOfLines = 0

        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        secondaryButton.translatesAutoresizingMaskIntoConstraints = false
        secondaryButton.titleLabel?.font = Font.helveticaNeue(16)
        secondaryButton.setTitleColor(DivoColorPalette.primaryTextOnDark, for: .normal)
        secondaryButton.backgroundColor = DivoColorPalette.bannerBackgroundDark
        secondaryButton.layer.cornerRadius = DivoDesignTokens.Radius.pill
        secondaryButton.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)

        view.addSubview(imageView)
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(primaryButton)
        view.addSubview(secondaryButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: 80),

            backButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: DivoDesignTokens.Spacing.s),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.l),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.l),
            titleLabel.bottomAnchor.constraint(equalTo: descriptionLabel.topAnchor, constant: -DivoDesignTokens.Spacing.s),

            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: primaryButton.topAnchor, constant: -DivoDesignTokens.Spacing.l),

            primaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            primaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            primaryButton.heightAnchor.constraint(equalToConstant: 56),
            primaryButton.bottomAnchor.constraint(equalTo: secondaryButton.topAnchor, constant: -DivoDesignTokens.Spacing.s),

            secondaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            secondaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            secondaryButton.heightAnchor.constraint(equalToConstant: 56),
            secondaryButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
    }

    private func applyPresentation() {
        titleLabel.text = OnboardingStrings.resolve(presentation.titleKey)
        descriptionLabel.text = OnboardingStrings.resolve(presentation.descriptionKey)
        primaryButton.makeDivoButton(title: OnboardingStrings.resolve(presentation.primaryButtonKey))
        secondaryButton.setTitle(OnboardingStrings.resolve(presentation.secondaryButtonKey), for: .normal)

        // Михаил подключает финальный ассет через DivoImage. До тех пор — заглушка.
        imageView.image = UIImage(named: presentation.imageAssetName)
    }

    // MARK: - Actions

    @objc private func primaryTapped()   { delegate?.roleResultControllerDidConfirm(self) }
    @objc private func secondaryTapped() { delegate?.roleResultControllerDidRequestRestart(self) }
    @objc private func backTapped()      { delegate?.roleResultControllerDidTapBack(self) }
}
