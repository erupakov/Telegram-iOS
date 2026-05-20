import UIKit
import Display
import DivoCore
import DivoUIKit

/// Универсальный экран-«вопрос с вариантами».
/// Покрывает: top-level choice, industry door, sub-role picker'ы, experience quiz.
///
/// Не знает ничего о ролях/формах — берёт всё из `OnboardingQuizDescriptor`.
/// Михаил при вёрстке заменяет placeholder-цвета/шрифты на финальные, но НЕ трогает
/// `delegate` callbacks и поле `selectedOptionId` — на них держится навигация.
public final class OnboardingQuizViewController: UIViewController {

    // MARK: - Delegate

    public protocol Delegate: AnyObject {
        func quizController(_ controller: OnboardingQuizViewController, didSelectOption optionId: String)
        func quizControllerDidTapContinue(_ controller: OnboardingQuizViewController)
        func quizControllerDidTapBack(_ controller: OnboardingQuizViewController)
    }

    public weak var delegate: Delegate?

    // MARK: - State

    private var descriptor: OnboardingQuizDescriptor
    public private(set) var selectedOptionId: String?

    // MARK: - UI

    private let navigationBar = DivoNavigationBar()
    private let topFadeOverlay = OnboardingBottomFadeOverlay()

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = DivoImage.splashScreen
        return imageView
    }()

    private let progressLabel: UILabel = {
        let progressLabel = UILabel()
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = Font.regular(14)
        progressLabel.textColor = DivoColorPalette.primaryText
        progressLabel.textAlignment = .center
        return progressLabel
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(32)
        label.textColor = DivoColorPalette.primaryText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = Font.regular(16)
        subtitleLabel.textColor = DivoColorPalette.primaryTextOnDark
        subtitleLabel.numberOfLines = 0
        return subtitleLabel
    }()
    
    private let optionsStack: UIStackView = {
        let optionsStack = UIStackView()
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.axis = .vertical
        optionsStack.spacing = DivoDesignTokens.Spacing.s
        optionsStack.alignment = .fill
        return optionsStack
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.clipsToBounds = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        return contentView
    }()
    
    private let bottomFadeOverlay = OnboardingBottomFadeOverlay()
    private let continueButton = DivoButton()
    
    private let centerContentIfShort: Bool

    // MARK: - Init

    public init(descriptor: OnboardingQuizDescriptor, currentSelection: String?, centerContentIfShort: Bool = true) {
        self.descriptor = descriptor
        self.selectedOptionId = currentSelection
        self.centerContentIfShort = centerContentIfShort
        super.init(nibName: nil, bundle: nil)

        navigationBar.makeNavigationBar(
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            onBackTapped: {
                [weak self] in self?.backTapped()
            }
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Public

    public func configure(descriptor: OnboardingQuizDescriptor, currentSelection: String?) {
        self.descriptor = descriptor
        self.selectedOptionId = currentSelection
        if isViewLoaded {
            applyDescriptor()
        }
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.screenBackground
        setupUI()
        applyDescriptor()
    }

    // MARK: - UI

    private func setupUI() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        
        view.addSubview(backgroundImageView)
        view.addSubview(scrollView)
        view.addSubview(bottomFadeOverlay)
        view.addSubview(continueButton)
        
        view.addSubview(topFadeOverlay)
        view.addSubview(navigationBar)
        view.addSubview(progressLabel)
        
        topFadeOverlay.transform = CGAffineTransform(rotationAngle: .pi)
        
        let topSpacer = UIView()
        topSpacer.translatesAutoresizingMaskIntoConstraints = false
        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(topSpacer)
        scrollView.addSubview(contentView)
        scrollView.addSubview(bottomSpacer)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(optionsStack)
        
        let safe = view.safeAreaLayoutGuide
        
        let spacerEqualityConstraint = topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor)
        spacerEqualityConstraint.priority = .defaultLow
        
        let topCollapseConstraint = topSpacer.heightAnchor.constraint(equalToConstant: 120)
        topCollapseConstraint.priority = .defaultHigh
        
        if centerContentIfShort {
            spacerEqualityConstraint.isActive = true
            topSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        } else {
            topCollapseConstraint.isActive = true
        }
        
        bottomSpacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        
        NSLayoutConstraint.activate([
            topFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topFadeOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            topFadeOverlay.heightAnchor.constraint(equalToConstant: 140),
            
            navigationBar.topAnchor.constraint(equalTo: safe.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            progressLabel.centerYAnchor.constraint(equalTo: navigationBar.centerYAnchor),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: OnboardingBottomFadeOverlay.defaultHeight),
            
            scrollView.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),
            
            topSpacer.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            topSpacer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            topSpacer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            contentView.topAnchor.constraint(equalTo: topSpacer.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            bottomSpacer.topAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomSpacer.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            bottomSpacer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            bottomSpacer.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            optionsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.l),
            optionsStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            optionsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            continueButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            continueButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
    
    private func applyDescriptor() {
        let progressKey = descriptor.progressLabelKey
        progressLabel.text = progressKey.map { OnboardingStrings.resolve($0) }
        progressLabel.isHidden = (progressKey == nil)
        bottomFadeOverlay.isHidden = (progressKey == nil)
        topFadeOverlay.isHidden = (progressKey == nil)
        backgroundImageView.isHidden = (progressKey != nil)
        
        titleLabel.text = OnboardingStrings.resolve(descriptor.titleKey)

        if let s = descriptor.subtitleKey, !OnboardingStrings.resolve(s).isEmpty {
            subtitleLabel.textColor = descriptor.subtitleKey == "onboarding.quiz.topLevel.subtitle" ? DivoColorPalette.primaryTextOnDark : DivoColorPalette.primaryText.withAlphaComponent(0.8)
            subtitleLabel.text = OnboardingStrings.resolve(s)
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }

        optionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var previousView: UIView? = nil
        for (sectionIndex, section) in descriptor.sections.enumerated() {
            // Заголовок секции рендерится только при наличии titleKey. На безымянных секциях
            // (top-level / industry door / experience quiz) ничего не добавляется — поэтому
            // отрисовка одно- и многосекционных пикеров идёт по одному коду.
            if let titleKey = section.titleKey {
                let header = makeSectionHeaderLabel(titleKey: titleKey)
                optionsStack.addArrangedSubview(header)
                // Перед заголовком следующей секции — увеличенный отступ от предыдущей опции.
                if sectionIndex > 0, let prev = previousView {
                    optionsStack.setCustomSpacing(DivoDesignTokens.Spacing.m, after: prev)
                }
                previousView = header
            }
            for option in section.options {
                guard let iconAssetName = option.iconAssetName else { continue }
                let row = OnboardingQuizOptionRow(
                    option: option,
                    type: option.rowType ?? .big,
                    icon: OnboardingImages.resolve(iconAssetName).withRenderingMode(.alwaysTemplate),
                    isSelected: option.id == selectedOptionId
                )
                row.onTap = { [weak self] in
                    self?.selectOption(option.id)
                }
                optionsStack.addArrangedSubview(row)
                // Уменьшенный отступ между заголовком секции и первой её опцией.
                if let header = previousView as? UILabel {
                    optionsStack.setCustomSpacing(DivoDesignTokens.Spacing.s, after: header)
                }
                previousView = row
            }
        }

        continueButton.makeDivoButton(title: OnboardingStrings.resolve(descriptor.primaryButtonKey))
        continueButton.isEnabled = (selectedOptionId != nil)
    }

    /// Section-заголовок («TALENTS», «CREATIVE»). Уважает правило memory: `.uppercased()`
    /// делается в коде, а не в строке локализации.
    private func makeSectionHeaderLabel(titleKey: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Font.helveticaNeue(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        label.text = OnboardingStrings.resolve(titleKey).uppercased()
        return label
    }

    private func selectOption(_ id: String) {
        selectedOptionId = id
        delegate?.quizController(self, didSelectOption: id)
        for case let row as OnboardingQuizOptionRow in optionsStack.arrangedSubviews {
            row.setSelected(row.option.id == id)
        }
        continueButton.isEnabled = true
    }

    // MARK: - Actions

    @objc private func backTapped() { delegate?.quizControllerDidTapBack(self) }
    @objc private func continueTapped() { delegate?.quizControllerDidTapContinue(self) }
}
