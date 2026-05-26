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
    }

    public weak var delegate: Delegate?

    // MARK: - UI

    private let imageView = UIImageView()
    private let gradientOverlay = CAGradientLayer()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(32)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let primaryButton = DivoButton()
    private let secondaryButton = DivoButton()
    
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

        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        secondaryButton.translatesAutoresizingMaskIntoConstraints = false
        secondaryButton.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)

        view.addSubview(imageView)
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(primaryButton)
        view.addSubview(secondaryButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            titleLabel.bottomAnchor.constraint(equalTo: descriptionLabel.topAnchor, constant: -12),

            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: primaryButton.topAnchor, constant: -DivoDesignTokens.Spacing.xl),

            primaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            primaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            primaryButton.heightAnchor.constraint(equalToConstant: 56),
            primaryButton.bottomAnchor.constraint(equalTo: secondaryButton.topAnchor, constant: -DivoDesignTokens.Spacing.m),

            secondaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            secondaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            secondaryButton.heightAnchor.constraint(equalToConstant: 56),
            secondaryButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])
    }

    private func applyPresentation() {
        titleLabel.text = OnboardingStrings.resolve(presentation.titleKey).uppercased()
        descriptionLabel.text = OnboardingStrings.resolve(presentation.descriptionKey)
        primaryButton.makeDivoButton(title: OnboardingStrings.resolve(presentation.primaryButtonKey))
        secondaryButton.makeDivoButton(title: OnboardingStrings.resolve(presentation.secondaryButtonKey), divoButtonStyle: .secondary)
        secondaryButton.backgroundColor = DivoColorPalette.secondaryButtonBackground
        imageView.image = OnboardingImages.resolve(presentation.imageAssetName)
    }

    // MARK: - Actions

    @objc private func primaryTapped()   { delegate?.roleResultControllerDidConfirm(self) }
    @objc private func secondaryTapped() { delegate?.roleResultControllerDidRequestRestart(self) }
}
