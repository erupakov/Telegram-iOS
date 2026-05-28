import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramCore
import TelegramBaseController
import SwiftSignalKit
import DivoCore
import DivoUIKit

public final class DivoLanguagePickerController: TelegramBaseController {

    private let context: AccountContext

    private var pickerNode: DivoLanguagePickerNode {
        return self.displayNode as! DivoLanguagePickerNode
    }

    public init(context: AccountContext) {
        self.context = context
        super.init(context: context, navigationBarPresentationData: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = DivoLanguagePickerNode()

        self.pickerNode.onBackTapped = { [weak self] in
            let _ = (self?.navigationController as? NavigationController)?.popViewController(animated: true)
        }
        self.pickerNode.onLanguageSelected = { [weak self] selection in
            self?.applySelection(selection)
        }

        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.pickerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }

    private func applySelection(_ selection: DivoLanguagePickerNode.Selection) {
        // Сохраняем выбор в DivoStrings. didChangeNotification разлетится подписчикам.
        //
        // ВАЖНО: TelegramRootController.refreshDivoTabTitles подписан на эту нотификацию
        // и делает popToRoot(animated: false) — чтобы push'нутые внутри табов экраны (которые
        // могут не быть подписаны на notification) пересоздались с новым языком. Это значит:
        //  - при реальной смене языка popToRoot сам уберёт picker, manual pop НЕ нужен;
        //  - если язык не сменился (нажали back/тот же язык) — notification не летит,
        //    picker нужно закрыть руками.
        //
        // Если делать manual pop + полагаться на popToRoot одновременно — две pop-операции
        // конфликтуют и дают чёрный экран.
        //
        // Sync с Telegram-pack'ом через downloadAndApplyLocalization НЕ вызываем —
        // вешает серый overlay (teamgram language pack pull).
        let didChange: Bool
        switch selection {
        case .auto:
            didChange = DivoStrings.isOverridden
            if didChange {
                DivoStrings.resetToDeviceLanguage()
            }
        case .explicit(let lang):
            didChange = !DivoStrings.isOverridden || DivoStrings.current != lang
            if didChange {
                DivoStrings.current = lang
            }
        }

        if !didChange {
            let _ = (self.navigationController as? NavigationController)?.popViewController(animated: true)
        }
    }
}

// MARK: - Node

private final class DivoLanguagePickerNode: ASDisplayNode {

    enum Selection {
        case auto
        case explicit(DivoStrings.Language)
    }

    private enum Layout {
        static let rowHeight: CGFloat = 56
        static let cardInnerPadding: CGFloat = 12
        static let cardHorizontalPadding: CGFloat = 18
        static let sectionSpacing: CGFloat = 24
        static let contentTopInset: CGFloat = 8
        static let contentBottomInset: CGFloat = 20
        static let scrollBottomExtra: CGFloat = 20
        /// Соответствует heightAnchor у `DivoNavigationBar` (50pt).
        static let navigationBarHeight: CGFloat = 50
    }

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.m
        return stack
    }()

    private let navigationBar = DivoNavigationBar()

    private let topBlurView: DivoGlassBlurView = {
        let view = DivoGlassBlurView(
            direction: .top,
            blurStyle: .systemUltraThinMaterialLight,
            falloff: .anchored
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let autoRow = LanguagePickerRowView()
    private var languageRows: [DivoStrings.Language: LanguagePickerRowView] = [:]

    private var navigationBarTopConstraint: NSLayoutConstraint?

    var onBackTapped: (() -> Void)?
    var onLanguageSelected: ((Selection) -> Void)?

    override init() {
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
    }

    override func didLoad() {
        super.didLoad()

        navigationBar.makeNavigationBar(
            title: DivoStrings.language.uppercased(),
            font: Font.helveticaNeue(20),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            rightButtonConfiguration: nil,
            onBackTapped: { [weak self] in self?.onBackTapped?() }
        )

        setupUI()
        applySelection()
    }

    private func setupUI() {
        // z-order снизу вверх: scroll → blur (occupies navbar area) → navbar.
        // Контент скроллится «под» navbar, blur размывает то, что под ним.
        view.addSubview(scrollView)
        view.addSubview(topBlurView)
        view.addSubview(navigationBar)
        scrollView.addSubview(contentStack)

        let topCns = navigationBar.topAnchor.constraint(equalTo: view.topAnchor)
        self.navigationBarTopConstraint = topCns

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            topBlurView.topAnchor.constraint(equalTo: view.topAnchor),
            topBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBlurView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor),

            topCns,
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Layout.contentTopInset),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Layout.contentBottomInset),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        setupAutoSection()
        setupLanguagesSection()

        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        bottomSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        contentStack.addArrangedSubview(bottomSpacer)
    }

    private func setupAutoSection() {
        autoRow.configure(
            title: DivoStrings.languageAuto,
            subtitle: DivoStrings.languageSystemSubtitle(DivoStrings.deviceLanguage.displayName),
            isLast: true
        )
        autoRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(autoTapped)))

        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(autoRow)

        let card = makeCardContainer()
        card.addSubview(stackContainer)

        let sectionContainer = UIView()
        sectionContainer.translatesAutoresizingMaskIntoConstraints = false
        sectionContainer.addSubview(card)

        NSLayoutConstraint.activate(cardLayoutConstraints(card: card, stack: stackContainer, container: sectionContainer))
        NSLayoutConstraint.activate([
            autoRow.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
        ])

        contentStack.addArrangedSubview(sectionContainer)
        contentStack.setCustomSpacing(Layout.sectionSpacing, after: sectionContainer)
    }

    private func setupLanguagesSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical

        let allLanguages = DivoStrings.Language.allCases
        for (idx, lang) in allLanguages.enumerated() {
            let row = LanguagePickerRowView()
            row.configure(
                title: lang.displayName,
                subtitle: lang.rawValue.uppercased(),
                isLast: idx == allLanguages.count - 1
            )
            row.tag = idx
            row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(languageRowTapped(_:))))
            languageRows[lang] = row
            stackContainer.addArrangedSubview(row)

            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
            ])
        }

        let card = makeCardContainer()
        card.addSubview(stackContainer)

        let sectionContainer = UIView()
        sectionContainer.translatesAutoresizingMaskIntoConstraints = false
        sectionContainer.addSubview(card)

        NSLayoutConstraint.activate(cardLayoutConstraints(card: card, stack: stackContainer, container: sectionContainer))

        contentStack.addArrangedSubview(sectionContainer)
    }

    private func applySelection() {
        let isOverridden = DivoStrings.isOverridden
        let current = DivoStrings.current

        autoRow.setChecked(!isOverridden)
        for (lang, row) in languageRows {
            row.setChecked(isOverridden && lang == current)
        }
    }

    private func makeCardContainer() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
        view.backgroundColor = DivoColorPalette.cardBackground
        return view
    }

    private func cardLayoutConstraints(card: UIView, stack: UIStackView, container: UIView) -> [NSLayoutConstraint] {
        [
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Layout.cardHorizontalPadding),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Layout.cardHorizontalPadding),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            card.topAnchor.constraint(equalTo: container.topAnchor),

            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Layout.cardInnerPadding),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: Layout.cardInnerPadding),
        ]
    }

    @objc private func autoTapped() {
        // Picker всё равно сразу popится — оптимистично UI не дёргаем, чтобы не было
        // visible "прыжка" чекмарка прямо перед pop animation.
        onLanguageSelected?(.auto)
    }

    @objc private func languageRowTapped(_ recognizer: UITapGestureRecognizer) {
        guard let row = recognizer.view as? LanguagePickerRowView else { return }
        let allLanguages = DivoStrings.Language.allCases
        guard row.tag >= 0, row.tag < allLanguages.count else { return }
        onLanguageSelected?(.explicit(allLanguages[row.tag]))
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        let statusBarHeight = layout.statusBarHeight ?? 0
        navigationBarTopConstraint?.constant = statusBarHeight

        // scrollView расширен под navbar (top=view.top), поэтому начальный контент
        // нужно опустить через contentInset.top — иначе первая карточка прячется под blur.
        let topInset = statusBarHeight + Layout.navigationBarHeight
        scrollView.contentInset = UIEdgeInsets(
            top: topInset,
            left: layout.safeInsets.left,
            bottom: layout.intrinsicInsets.bottom + Layout.scrollBottomExtra,
            right: layout.safeInsets.right
        )
        scrollView.scrollIndicatorInsets = scrollView.contentInset
    }
}

// MARK: - Row View

private final class LanguagePickerRowView: UIView {

    private enum Layout {
        static let horizontalPadding: CGFloat = DivoDesignTokens.Spacing.m
        static let checkmarkSize: CGFloat = 20
        static let separatorHeight: CGFloat = 1
        static let titleSubtitleSpacing: CGFloat = 2
        static let titleCheckmarkSpacing: CGFloat = 8
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(13)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let checkmarkImageView: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        iv.image = UIImage(systemName: "checkmark", withConfiguration: config)
        iv.tintColor = DivoColorPalette.accent
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    private let separator: UIView = {
        let separator = UIView()
        separator.backgroundColor = DivoColorPalette.screenBackground
        separator.translatesAutoresizingMaskIntoConstraints = false
        return separator
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = .clear
        self.translatesAutoresizingMaskIntoConstraints = false
        addPressState(alpha: DivoDesignTokens.PressState.alphaOnClear, scale: DivoDesignTokens.PressState.scaleListRow)

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(checkmarkImageView)
        addSubview(separator)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkImageView.leadingAnchor, constant: -Layout.titleCheckmarkSpacing),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.titleSubtitleSpacing),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkImageView.leadingAnchor, constant: -Layout.titleCheckmarkSpacing),

            checkmarkImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),
            checkmarkImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: Layout.checkmarkSize),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: Layout.checkmarkSize),

            separator.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: Layout.separatorHeight),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, subtitle: String?, isLast: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = (subtitle?.isEmpty ?? true)
        separator.isHidden = isLast
    }

    func setChecked(_ checked: Bool) {
        checkmarkImageView.isHidden = !checked
    }
}
