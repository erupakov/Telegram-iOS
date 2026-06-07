import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import AppBundle
import DivoCore
import DivoUIKit

enum ScreenLoadPhase: Equatable {
    case loading
    case ready
    case failed
}

final class DivoSettingsNode: ASDisplayNode {

    private enum Layout {
        static let profileSectionHeight: CGFloat = 152
        static let profileShimmerTopInset: CGFloat = 12
        static let rowHeight: CGFloat = 46
        static let cardInnerPadding: CGFloat = 12
        static let cardHorizontalPadding: CGFloat = 18
        static let sectionSpacing: CGFloat = 24
        static let contentTopInset: CGFloat = 8
        static let contentBottomInset: CGFloat = 20
        static let scrollBottomExtra: CGFloat = 20
        static let snackbarBottomInset: CGFloat = 16
        static let dimmedAlpha: CGFloat = 0.5
    }

    private struct MeasuringOption {
        let id: String
        let title: String
    }

    private let context: AccountContext

    private var screenPhase: ScreenLoadPhase = .loading {
        didSet {
            if oldValue != screenPhase {
                applyState()
            }
        }
    }

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        return scrollView
    }()

    private let contentViewStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.m
        return stack
    }()

    private let navigationBar = DivoNavigationBar()

    private let profileContainer = UIView()
    private let profileHeader = HeaderSettingsView()
    private let profileShimmerView = HeaderSettingsShimmerView()

    private let usernameContainer = SettingsRowView(icon: DivoImage.settingsSetUsername, title: DivoStrings.settingsSetUsername, isLast: false)
    private let parametersContainer = SettingsRowView(icon: DivoImage.settingsParameters, title: DivoStrings.fillYourParameters, isLast: true)
    private let parametersUsernameStackContainer = UIView()

    private let savedMessagesStackContainer = UIView()
    private let savedMessagesContainer = SettingsRowView(icon: DivoImage.settingsSavedMessages, title: DivoStrings.savedMessages, isLast: true)

    private let mainSettingsStackContainer = UIView()
    private let notificationsSoundsContainer = SettingsRowView(icon: DivoImage.settingsNotifications, title: DivoStrings.notificationsSounds, isLast: false)
    private let privacySecurityContainer = SettingsRowView(icon: DivoImage.settingsPrivacy, title: DivoStrings.privacySecurity, isLast: false)
    private let dataStorageContainer = SettingsRowView(icon: DivoImage.settingsData, title: DivoStrings.dataStorage, isLast: false)
    private let languageContainer = SettingsRowView(icon: DivoImage.settingsLanguage, title: DivoStrings.language, isLast: false)
    // scalemass.fill — временная SF-иконка для measuringSystem, пока DIVO-иконка не подключена.
    private let measuringSystemContainer = SettingsRowView(
        icon: UIImage(systemName: "scalemass.fill") ?? UIImage(),
        title: DivoStrings.measuringSystem,
        isLast: true
    )

    private let logOutStackContainer = UIView()
    private let logOutContainer = SettingsRowView(icon: DivoImage.settingsLogOut, title: DivoStrings.logOut, isLast: true)

    // Debug-row под логаутом: запускает регистрационный онбординг минуя авторизацию.
    // Виден только когда `DivoDebugFlags.showOnboardingEntry == true` (переключатель в Debug Menu).
    private let onboardingEntryStackContainer = UIView()
    private let onboardingEntryContainer = SettingsRowView(
        icon: UIImage(systemName: "person.crop.rectangle.stack") ?? UIImage(),
        title: DivoStrings.settingsDebugLaunchOnboarding,
        isLast: true
    )

    var onProfileTapped: (() -> Void)?
    var onOnboardingEntryTapped: (() -> Void)?
    var onSetUsernameTapped: (() -> Void)?
    var onFillParametersTapped: (() -> Void)?
    var onLanguageTapped: (() -> Void)?
    var onQrTapped: (() -> Void)?
    var onLogOutTapped: (() -> Void)?
    var presentController: ((UIViewController) -> Void)?
    var saveMeasuringSystem: ((String?) -> Void)?

    private var localizationObserver: NSObjectProtocol?

    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var navigationBarTopConstraint: NSLayoutConstraint?

    private var selectedMeasuringSystemId: String?
    private var selectedMeasuringSystemTitle: String?
    private var measuringSystem: [MeasuringOption] {
        [
            MeasuringOption(id: "metric", title: DivoStrings.metric),
            MeasuringOption(id: "imperial", title: DivoStrings.imperial),
        ]
    }

    private let snackbar = DivoSnackbar()
    typealias SnackbarStyle = DivoSnackbar.Style

    init(context: AccountContext) {
        self.context = context
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground

        navigationBar.makeNavigationBar(
            title: DivoStrings.settings,
            font: Font.helveticaNeue(20),
            backButtonConfiguration: .circle(DivoImage.qrCode),
            rightButtonConfiguration: .text(DivoStrings.settingsEdit),
            onBackTapped: { [weak self] in self?.onQrTapped?() },
            onCircleTextTapped: { [weak self] in self?.onProfileTapped?() }
        )

        measuringSystemContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(measuringSystemTapped)))
        languageContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(languageTapped)))

        setupCustomNavBar()
        setupUI()

        // Стартовое значение для row "Язык" — сами title'ы уже выставлены в init у containers.
        languageContainer.setValue(DivoStrings.current.displayName)

        applyState()

        localizationObserver = NotificationCenter.default.addObserver(
            forName: DivoStrings.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyLocalization()
        }
    }

    deinit {
        if let observer = localizationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Перерисовывает title'ы row'ов и navbar после смены `DivoStrings.current`.
    /// Сами row-view создаются с готовыми title'ами в init — без этого метода они застряли бы на старом языке до перезапуска.
    private func applyLocalization() {
        navigationBar.setTitle(DivoStrings.settings)
        navigationBar.setRightButtonTitle(DivoStrings.settingsEdit)
        usernameContainer.setTitle(DivoStrings.settingsSetUsername)
        parametersContainer.setTitle(DivoStrings.fillYourParameters)
        savedMessagesContainer.setTitle(DivoStrings.savedMessages)
        notificationsSoundsContainer.setTitle(DivoStrings.notificationsSounds)
        privacySecurityContainer.setTitle(DivoStrings.privacySecurity)
        dataStorageContainer.setTitle(DivoStrings.dataStorage)
        languageContainer.setTitle(DivoStrings.language)
        languageContainer.setValue(DivoStrings.current.displayName)
        measuringSystemContainer.setTitle(DivoStrings.measuringSystem)
        logOutContainer.setTitle(DivoStrings.logOut)
        onboardingEntryContainer.setTitle(DivoStrings.settingsDebugLaunchOnboarding)
        // measuring system dropdown value title тоже зависит от языка — обновим выбранный заголовок.
        selectedMeasuringSystemTitle = measuringSystem.first(where: { $0.id == selectedMeasuringSystemId })?.title
        measuringSystemContainer.setValue(selectedMeasuringSystemTitle ?? "")
    }

    private func applyState() {
        switch screenPhase {
        case .loading, .failed:
            // .failed визуально совпадает с .loading: контент остаётся затемнённым,
            // а пользователю показывается persistent snackbar с retry (см. DivoSettingsController).
            scrollView.isScrollEnabled = false

            profileShimmerView.isHidden = false
            profileHeader.isHidden = true

            setDimmedSectionsActive(true)

            if screenPhase == .loading {
                profileShimmerView.startAnimation()
            } else {
                profileShimmerView.stopAnimation()
            }

        case .ready:
            profileShimmerView.stopAnimation()
            UIView.animate(withDuration: 0.3) {
                self.scrollView.isScrollEnabled = true
                self.profileShimmerView.isHidden = true
                self.profileHeader.isHidden = false
                self.setDimmedSectionsActive(false)
            }
        }
    }

    private func setDimmedSectionsActive(_ dimmed: Bool) {
        let alpha: CGFloat = dimmed ? Layout.dimmedAlpha : 1.0
        let interactive = !dimmed
        for view in [parametersUsernameStackContainer, savedMessagesStackContainer, mainSettingsStackContainer, logOutStackContainer, onboardingEntryStackContainer] {
            view.alpha = alpha
            view.isUserInteractionEnabled = interactive
        }
    }

    private func setupCustomNavBar() {
        view.addSubview(navigationBar)

        // Реальная позиция выставляется в containerLayoutUpdated через
        // layout.statusBarHeight (высота только статус-бара). У TelegramBaseController
        // навбар у нас не показывается, но место под него зарезервировано в
        // navigationBarHeight — поэтому им пользоваться нельзя.
        let topCns = navigationBar.topAnchor.constraint(equalTo: view.topAnchor)
        self.navigationBarTopConstraint = topCns

        NSLayoutConstraint.activate([
            topCns,
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentViewStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentViewStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Layout.contentTopInset),
            contentViewStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentViewStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentViewStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Layout.contentBottomInset),
            contentViewStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        setupProfileSection()
        setupUsernameParametersSection()
        setupSavedMessagesSection()
        setupMainSection()
        setupLogOutSection()
        setupOnboardingEntrySection()

        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        bottomSpacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        contentViewStack.addArrangedSubview(bottomSpacer)
    }

    private func setupProfileSection() {
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        profileContainer.backgroundColor = DivoColorPalette.screenBackground
        profileContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(profileTapped)))
        profileContainer.addPressState(alpha: DivoDesignTokens.PressState.alphaOnClear, scale: DivoDesignTokens.PressState.scaleListRow)

        profileContainer.addSubview(profileHeader)
        profileHeader.translatesAutoresizingMaskIntoConstraints = false

        profileContainer.addSubview(profileShimmerView)
        profileShimmerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            profileContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.profileSectionHeight),

            profileHeader.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor),
            profileHeader.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor),
            profileHeader.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            profileHeader.topAnchor.constraint(equalTo: profileContainer.topAnchor),

            profileShimmerView.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor, constant: Layout.cardHorizontalPadding),
            profileShimmerView.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor, constant: -Layout.cardHorizontalPadding),
            profileShimmerView.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            profileShimmerView.topAnchor.constraint(equalTo: profileContainer.topAnchor, constant: Layout.profileShimmerTopInset),
            profileShimmerView.heightAnchor.constraint(equalToConstant: Layout.profileSectionHeight),
        ])

        contentViewStack.addArrangedSubview(profileContainer)
        contentViewStack.setCustomSpacing(Layout.sectionSpacing, after: profileContainer)
    }

    private func setupUsernameParametersSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(usernameContainer)
        stackContainer.addArrangedSubview(parametersContainer)
        parametersContainer.isHidden = true
        usernameContainer.setSeparatorHidden(true)

        let whiteContainer = makeCardContainer()
        whiteContainer.addSubview(stackContainer)

        parametersUsernameStackContainer.translatesAutoresizingMaskIntoConstraints = false
        parametersUsernameStackContainer.addSubview(whiteContainer)

        NSLayoutConstraint.activate(cardLayoutConstraints(card: whiteContainer, stack: stackContainer, container: parametersUsernameStackContainer))

        NSLayoutConstraint.activate([
            usernameContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
            parametersContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
        ])

        usernameContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(usernameTapped)))
        parametersContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(parametersTapped)))

        contentViewStack.addArrangedSubview(parametersUsernameStackContainer)
    }

    private func setupSavedMessagesSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(savedMessagesContainer)

        let whiteContainer = makeCardContainer()
        whiteContainer.addSubview(stackContainer)

        savedMessagesStackContainer.translatesAutoresizingMaskIntoConstraints = false
        savedMessagesStackContainer.addSubview(whiteContainer)

        NSLayoutConstraint.activate(cardLayoutConstraints(card: whiteContainer, stack: stackContainer, container: savedMessagesStackContainer))

        NSLayoutConstraint.activate([
            savedMessagesContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
        ])

        contentViewStack.addArrangedSubview(savedMessagesStackContainer)
    }

    private func setupMainSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(notificationsSoundsContainer)
        stackContainer.addArrangedSubview(privacySecurityContainer)
        stackContainer.addArrangedSubview(dataStorageContainer)
        stackContainer.addArrangedSubview(languageContainer)
        stackContainer.addArrangedSubview(measuringSystemContainer)
        measuringSystemContainer.isHidden = true
        languageContainer.setSeparatorHidden(true)

        let whiteContainer = makeCardContainer()
        whiteContainer.addSubview(stackContainer)

        mainSettingsStackContainer.translatesAutoresizingMaskIntoConstraints = false
        mainSettingsStackContainer.addSubview(whiteContainer)

        NSLayoutConstraint.activate(cardLayoutConstraints(card: whiteContainer, stack: stackContainer, container: mainSettingsStackContainer))

        NSLayoutConstraint.activate([
            notificationsSoundsContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
            privacySecurityContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
            dataStorageContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
            languageContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
            measuringSystemContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
        ])

        contentViewStack.addArrangedSubview(mainSettingsStackContainer)
    }

    private func setupLogOutSection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(logOutContainer)

        let whiteContainer = makeCardContainer()
        whiteContainer.addSubview(stackContainer)

        logOutStackContainer.translatesAutoresizingMaskIntoConstraints = false
        logOutStackContainer.addSubview(whiteContainer)

        NSLayoutConstraint.activate(cardLayoutConstraints(card: whiteContainer, stack: stackContainer, container: logOutStackContainer))

        NSLayoutConstraint.activate([
            logOutContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
        ])

        logOutContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(logOutTapped)))

        contentViewStack.addArrangedSubview(logOutStackContainer)
    }

    @objc private func logOutTapped() {
        onLogOutTapped?()
    }

    private func setupOnboardingEntrySection() {
        let stackContainer = UIStackView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        stackContainer.axis = .vertical
        stackContainer.addArrangedSubview(onboardingEntryContainer)

        let whiteContainer = makeCardContainer()
        whiteContainer.addSubview(stackContainer)

        onboardingEntryStackContainer.translatesAutoresizingMaskIntoConstraints = false
        onboardingEntryStackContainer.addSubview(whiteContainer)

        NSLayoutConstraint.activate(cardLayoutConstraints(card: whiteContainer, stack: stackContainer, container: onboardingEntryStackContainer))

        NSLayoutConstraint.activate([
            onboardingEntryContainer.heightAnchor.constraint(equalToConstant: Layout.rowHeight),
        ])

        onboardingEntryContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onboardingEntryTapped)))
        onboardingEntryContainer.addPressState(alpha: DivoDesignTokens.PressState.alpha, scale: DivoDesignTokens.PressState.scaleListRow)

        contentViewStack.addArrangedSubview(onboardingEntryStackContainer)
        applyOnboardingEntryVisibility()
    }

    /// Прячет/показывает debug-row онбординга в зависимости от текущего флага.
    /// Зовётся при первичной сборке и из контроллера на смену `DivoDebugFlags.didChangeNotification`.
    func applyOnboardingEntryVisibility() {
        onboardingEntryStackContainer.isHidden = !DivoDebugFlags.showOnboardingEntry
    }

    @objc private func onboardingEntryTapped() {
        guard screenPhase == .ready else { return }
        onOnboardingEntryTapped?()
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

    private func presentSheet(_ vc: UIViewController) {
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = DivoDesignTokens.Radius.card
            }
        }
        presentController?(nav)
    }

    private func updateDropdownsUI() {
        measuringSystemContainer.setValue(selectedMeasuringSystemTitle ?? "")
    }

    // MARK: - Internal

    func markLoading() {
        screenPhase = .loading
    }

    func markFailed() {
        screenPhase = .failed
    }

    /// Выставляет выбранную систему измерения. Используется и при первичной загрузке профиля,
    /// и для отката значения, если PATCH-запрос упал с ошибкой.
    func applyMeasuringSystem(_ id: String?) {
        selectedMeasuringSystemId = id
        selectedMeasuringSystemTitle = measuringSystem.first(where: { $0.id == id })?.title
        updateDropdownsUI()
    }

    /// Текущее значение системы измерения — нужно контроллеру для запоминания предыдущего
    /// значения перед PATCH-запросом (для отката при ошибке).
    var currentMeasuringSystemId: String? {
        return selectedMeasuringSystemId
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat) {
        self.containerLayout = (layout, navigationBarHeight)

        navigationBarTopConstraint?.constant = layout.statusBarHeight ?? 0

        scrollView.contentInset = UIEdgeInsets(
            top: 0,
            left: layout.safeInsets.left,
            bottom: layout.intrinsicInsets.bottom + Layout.scrollBottomExtra,
            right: layout.safeInsets.right
        )
        scrollView.scrollIndicatorInsets = scrollView.contentInset
        snackbar.updateBottomInset(layout.intrinsicInsets.bottom + Layout.snackbarBottomInset)
    }

    func updateWithProfile(_ user: UserDetail) {
        let isAgency = Role(apiRole: user.role) == .agency
        let headerName = isAgency ? user.agency?.title : user.fullName
        let headerAvatar = isAgency ? user.agency?.photo?.fullUrl : user.avatar?.fullUrl
        profileHeader.configure(fullUrl: headerAvatar, fullName: headerName, phone: user.phone)
        applyMeasuringSystem(user.measuringSystem)

        parametersContainer.isHidden = isAgency
        usernameContainer.setSeparatorHidden(isAgency)
        measuringSystemContainer.isHidden = isAgency
        languageContainer.setSeparatorHidden(isAgency)

        screenPhase = .ready
    }

    // MARK: - Snackbar

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        let bottomInset = (containerLayout?.0.intrinsicInsets.bottom ?? 0) + Layout.snackbarBottomInset
        snackbar.show(
            in: view,
            message: message,
            style: style,
            bottomInset: bottomInset,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }

    // MARK: - Actions

    @objc private func languageTapped() {
        guard screenPhase == .ready else { return }
        onLanguageTapped?()
    }

    @objc private func measuringSystemTapped() {
        guard screenPhase == .ready else { return }

        let options = measuringSystem.map { FilterOptionItem(id: $0.id, title: $0.title) }
        let selectedIds = selectedMeasuringSystemId.map { [$0] } ?? []

        let vc = FilterOptionsController(
            title: DivoStrings.measuringSystem,
            options: options,
            selectedOptionIds: selectedIds,
            isMultiSelect: false,
            showSearch: false,
            isOpenPresent: true,
            isResetButton: false
        )

        vc.onSave = { [weak self] selectedItems in
            guard let self = self else { return }
            if let selected = selectedItems.first {
                self.selectedMeasuringSystemId = selected.id
                self.selectedMeasuringSystemTitle = selected.title
            } else {
                self.selectedMeasuringSystemId = nil
                self.selectedMeasuringSystemTitle = nil
            }
            self.saveMeasuringSystem?(self.selectedMeasuringSystemId)
            self.updateDropdownsUI()
        }
        presentSheet(vc)
    }

    @objc private func profileTapped() {
        guard screenPhase == .ready else { return }
        onProfileTapped?()
    }

    @objc private func usernameTapped() {
        guard screenPhase == .ready else { return }
        onSetUsernameTapped?()
    }

    @objc private func parametersTapped() {
        guard screenPhase == .ready else { return }
        onFillParametersTapped?()
    }
}
