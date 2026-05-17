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

    private let backButton = UIButton(type: .system)
    private let progressLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let optionsStack = UIStackView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let bottomFadeOverlay = OnboardingBottomFadeOverlay()
    private let continueButton = DivoButton()

    // MARK: - Init

    public init(descriptor: OnboardingQuizDescriptor, currentSelection: String?) {
        self.descriptor = descriptor
        self.selectedOptionId = currentSelection
        super.init(nibName: nil, bundle: nil)
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
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = DivoColorPalette.primaryText
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = Font.regular(13)
        progressLabel.textColor = DivoColorPalette.secondaryText
        progressLabel.textAlignment = .center

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Font.helveticaNeue(24)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.numberOfLines = 0

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = Font.regular(14)
        subtitleLabel.textColor = DivoColorPalette.secondaryText
        subtitleLabel.numberOfLines = 0

        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.axis = .vertical
        optionsStack.spacing = DivoDesignTokens.Spacing.s
        optionsStack.alignment = .fill

        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)

        view.addSubview(backButton)
        view.addSubview(progressLabel)
        view.addSubview(scrollView)
        // bottomFadeOverlay добавляется ПОСЛЕ scrollView и ДО кнопки — лежит над контентом,
        // под кнопкой. Контент, скроллящийся вниз, плавно «уходит» в screenBackground.
        view.addSubview(bottomFadeOverlay)
        view.addSubview(continueButton)
        scrollView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(optionsStack)

        // Контент скроллится на всю высоту экрана; нижний контент защищён contentInset.bottom,
        // чтобы последняя опция не оказывалась под кнопкой даже когда скролл не нужен.
        scrollView.contentInset.bottom = OnboardingBottomFadeOverlay.defaultHeight - 20
        scrollView.verticalScrollIndicatorInsets.bottom = scrollView.contentInset.bottom

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: DivoDesignTokens.Spacing.s),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            progressLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: OnboardingBottomFadeOverlay.defaultHeight),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.xs),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            optionsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.l),
            optionsStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            optionsStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),

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

        titleLabel.text = OnboardingStrings.resolve(descriptor.titleKey)

        if let s = descriptor.subtitleKey, !OnboardingStrings.resolve(s).isEmpty {
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
                let row = OnboardingQuizOptionRow(option: option, isSelected: option.id == selectedOptionId)
                row.onTap = { [weak self] in
                    self?.selectOption(option.id)
                }
                optionsStack.addArrangedSubview(row)
                // Уменьшенный отступ между заголовком секции и первой её опцией.
                if let header = previousView as? UILabel {
                    optionsStack.setCustomSpacing(DivoDesignTokens.Spacing.xs, after: header)
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
        label.font = Font.helveticaNeue(11)
        label.textColor = DivoColorPalette.secondaryText
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

// MARK: - Option row

private final class OnboardingQuizOptionRow: UIControl {
    let option: OnboardingQuizDescriptor.Option
    var onTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let radioView = UIImageView()
    private let stack = UIStackView()

    init(option: OnboardingQuizDescriptor.Option, isSelected: Bool) {
        self.option = option
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = DivoColorPalette.cardBackground
        layer.cornerRadius = DivoDesignTokens.Radius.card
        layer.borderWidth = isSelected ? 2 : 1
        layer.borderColor = (isSelected ? DivoColorPalette.accent : DivoColorPalette.separatorLight).cgColor

        radioView.translatesAutoresizingMaskIntoConstraints = false
        radioView.contentMode = .scaleAspectFit
        radioView.tintColor = DivoColorPalette.accent

        titleLabel.font = Font.helveticaNeue(14)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.numberOfLines = 0
        titleLabel.text = OnboardingStrings.resolve(option.titleKey)

        subtitleLabel.font = Font.regular(12)
        subtitleLabel.textColor = DivoColorPalette.secondaryText
        subtitleLabel.numberOfLines = 0
        if let subtitleKey = option.subtitleKey {
            subtitleLabel.text = OnboardingStrings.resolve(subtitleKey)
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 2
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        // Пропускаем тачи насквозь к UIControl-родителю — иначе UIStackView перехватывает
        // hit-test и touchUpInside на row не срабатывает, кроме области radioView.
        stack.isUserInteractionEnabled = false

        addSubview(radioView)
        addSubview(stack)

        NSLayoutConstraint.activate([
            radioView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            radioView.centerYAnchor.constraint(equalTo: centerYAnchor),
            radioView.widthAnchor.constraint(equalToConstant: 22),
            radioView.heightAnchor.constraint(equalToConstant: 22),

            stack.leadingAnchor.constraint(equalTo: radioView.trailingAnchor, constant: DivoDesignTokens.Spacing.m),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: DivoDesignTokens.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DivoDesignTokens.Spacing.m),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
        ])

        setSelected(isSelected)
        addTarget(self, action: #selector(tap), for: .touchUpInside)
        // Стандартный DIVO press-state: alpha 0.65 + лёгкий scale 0.98 для list-row.
        addPressState(alpha: DivoDesignTokens.PressState.alpha, scale: DivoDesignTokens.PressState.scaleListRow)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ isSelected: Bool) {
        let symbol = isSelected ? "largecircle.fill.circle" : "circle"
        radioView.image = UIImage(systemName: symbol)
        layer.borderWidth = isSelected ? 2 : 1
        layer.borderColor = (isSelected ? DivoColorPalette.accent : DivoColorPalette.separatorLight).cgColor
    }

    @objc private func tap() { onTap?() }
}
