import Display
import UIKit
import AsyncDisplayKit
import DivoUIKit
import DivoCore

final class SetNameNode: ASDisplayNode {

    /// Состояние валидации ника. Источник истины для статус-строки и гейтинга кнопки Save.
    enum UsernameState: Equatable {
        case neutral                    // пустой или не изменённый ник — валидно, статус не показываем
        case checking
        case available(message: String)
        case error(message: String)
    }

    /// Что делать с ником при сохранении — решает нода, исполняет контроллер.
    enum UsernameAction: Equatable {
        case unchanged
        case set(String)
        case clear
    }

    private enum Layout {
        static let buttonBottomInset: CGFloat = 40
        static let bottomFadeHeight: CGFloat = 140
        static let bottomFadeOpaqueLocation: NSNumber = 0.45
        static let navBarToContentSpacing: CGFloat = 24
        static let labelToFieldSpacing: CGFloat = 8
        static let statusToHintSpacing: CGFloat = 4
    }

    var onBackTapped: (() -> Void)?
    var onSave: ((_ firstName: String, _ lastName: String, _ usernameAction: UsernameAction) -> Void)?
    var onUsernameChanged: ((_ handle: String) -> Void)?

    private let navigationBar = DivoNavigationBar()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.contentInsetAdjustmentBehavior = .never
        sv.keyboardDismissMode = .interactive
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let formStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.labelToFieldSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let nameSectionLabel = SetNameNode.makeSectionLabel(DivoStrings.firstName)
    private let lastNameSectionLabel = SetNameNode.makeSectionLabel(DivoStrings.lastName)
    private let usernameSectionLabel = SetNameNode.makeSectionLabel(DivoStrings.usernameSection)

    private let nameTextField: DivoTextField
    private let lastNameTextField = DivoTextField(title: "", prefix: "")
    private let usernameTextField = DivoTextField(title: "", prefix: "@")

    private let usernameStatusRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }()
    private let usernameSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        spinner.color = DivoColorPalette.secondaryText
        return spinner
    }()
    private let usernameStatusLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(13)
        label.textColor = DivoColorPalette.secondaryText
        label.numberOfLines = 0
        return label
    }()
    private let usernameHintLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.usernameHint
        label.font = Font.regular(13)
        label.textColor = DivoColorPalette.secondaryText
        label.numberOfLines = 0
        return label
    }()

    private let applyButton = DivoButton()
    private var applyButtonBottomConstraint: NSLayoutConstraint?

    private let bottomFadeOverlay: SetNameGradientView = {
        let view = SetNameGradientView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
                DivoColorPalette.screenBackground.cgColor,
            ]
            gradient.locations = [0, Layout.bottomFadeOpaqueLocation]
        }
        return view
    }()
    private var bottomFadeOverlayBottomConstraint: NSLayoutConstraint?

    private let snackbar = DivoSnackbar()
    typealias SnackbarStyle = DivoSnackbar.Style

    private var keyboardHandler: DivoKeyboardHandler?

    private let isAgency: Bool
    private var initialFirstName: String
    private var initialLastName: String = ""
    private var initialUsername: String = ""
    private var usernameState: UsernameState = .neutral {
        didSet {
            if oldValue != usernameState {
                renderUsernameState()
            }
        }
    }

    // MARK: - Init

    init(currentName: String?, isAgency: Bool) {
        let name = (currentName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.isAgency = isAgency
        self.initialFirstName = name
        self.nameTextField = DivoTextField(title: name, prefix: "")
        super.init()

        // У агентства одно поле — название агентства, не личное имя/фамилия.
        if isAgency {
            nameSectionLabel.text = DivoStrings.agencyName
        }
        self.backgroundColor = DivoColorPalette.screenBackground

        navigationBar.makeNavigationBar(
            title: DivoStrings.settingsSetUsername.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            onBackTapped: { [weak self] in self?.onBackTapped?() }
        )

        applyButton.makeDivoButton(title: DivoStrings.save, loading: DivoStrings.saving)
    }

    deinit {
        keyboardHandler?.unsubscribe()
    }

    override func didLoad() {
        super.didLoad()

        nameTextField.textField.attributedPlaceholder = NSAttributedString(
            string: isAgency ? DivoStrings.agencyName : DivoStrings.firstName,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        nameTextField.textField.autocapitalizationType = .words
        nameTextField.textField.returnKeyType = .next
        nameTextField.onReturn = { [weak self] in
            guard let self else { return }
            let next = self.isAgency ? self.usernameTextField : self.lastNameTextField
            next.textField.becomeFirstResponder()
        }

        lastNameTextField.textField.attributedPlaceholder = NSAttributedString(
            string: DivoStrings.lastName,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        lastNameTextField.textField.autocapitalizationType = .words
        lastNameTextField.textField.returnKeyType = .next
        lastNameTextField.onReturn = { [weak self] in self?.usernameTextField.textField.becomeFirstResponder() }

        usernameTextField.textField.autocapitalizationType = .none
        usernameTextField.textField.autocorrectionType = .no
        usernameTextField.textField.keyboardType = .asciiCapable
        usernameTextField.textField.returnKeyType = .done
        usernameTextField.onReturn = { [weak self] in self?.view.endEditing(true) }

        setupUI()
        setupConstraints()

        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Layout.bottomFadeHeight, right: 0)
        scrollView.scrollIndicatorInsets = scrollView.contentInset

        nameTextField.textField.addTarget(self, action: #selector(nameDidChange), for: .editingChanged)
        lastNameTextField.textField.addTarget(self, action: #selector(nameDidChange), for: .editingChanged)
        usernameTextField.textField.addTarget(self, action: #selector(usernameDidChange), for: .editingChanged)
        applyButton.addTarget(self, action: #selector(saveButtonPressed), for: .touchUpInside)

        keyboardHandler = DivoKeyboardHandler(
            scrollView: scrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: Layout.bottomFadeHeight
        )
        keyboardHandler?.subscribe()

        if !initialFirstName.isEmpty {
            nameTextField.setText(initialFirstName)
            if !isAgency {
                lastNameTextField.setText(initialLastName)
            }
        }
        if !initialUsername.isEmpty {
            usernameTextField.setText(initialUsername)
        }
        renderUsernameState()
        updateSaveButtonState()
    }

    // MARK: - Setup

    private static func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = Font.medium(14)
        label.textColor = DivoColorPalette.primaryText
        label.numberOfLines = 1
        return label
    }

    private func setupUI() {
        view.addSubview(navigationBar)

        usernameStatusRow.addArrangedSubview(usernameSpinner)
        usernameStatusRow.addArrangedSubview(usernameStatusLabel)

        formStack.addArrangedSubview(nameSectionLabel)
        formStack.addArrangedSubview(nameTextField.view)
        if !isAgency {
            formStack.addArrangedSubview(lastNameSectionLabel)
            formStack.addArrangedSubview(lastNameTextField.view)
        }
        formStack.addArrangedSubview(usernameSectionLabel)
        formStack.addArrangedSubview(usernameTextField.view)
        formStack.addArrangedSubview(usernameStatusRow)
        formStack.addArrangedSubview(usernameHintLabel)
        formStack.setCustomSpacing(DivoDesignTokens.Spacing.l, after: nameTextField.view)
        if !isAgency {
            formStack.setCustomSpacing(DivoDesignTokens.Spacing.l, after: lastNameTextField.view)
        }
        formStack.setCustomSpacing(Layout.statusToHintSpacing, after: usernameStatusRow)

        scrollView.addSubview(formStack)
        view.addSubview(scrollView)

        view.addSubview(bottomFadeOverlay)
        view.addSubview(applyButton)
    }

    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide

        let buttonBottomCns = applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Layout.buttonBottomInset)
        self.applyButtonBottomConstraint = buttonBottomCns

        let bottomFadeCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.bottomFadeOverlayBottomConstraint = bottomFadeCns

        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: safeArea.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            formStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Layout.navBarToContentSpacing),
            formStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            formStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            formStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            formStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),

            buttonBottomCns,
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            bottomFadeCns,
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: Layout.bottomFadeHeight),
        ])
    }

    // MARK: - State

    func toggleSaving(active: Bool) {
        applyButton.setSaving(active, in: view)
    }

    /// Прелоад имени/фамилии из Telegram-аккаунта (там они уже разбиты) — приходит асинхронно.
    /// Если teamgram имя не отдал — оставляем стартовый DIVO fullName в поле имени (выставлен в init).
    func setInitialName(firstName: String, lastName: String) {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty else { return }
        self.initialFirstName = first
        self.initialLastName = last
        guard isNodeLoaded else { return }
        nameTextField.setText(first)
        lastNameTextField.setText(last)
        updateSaveButtonState()
    }

    /// Прелоад текущего ника (из Telegram-аккаунта) — приходит асинхронно.
    func setInitialUsername(_ username: String) {
        self.initialUsername = username
        guard isNodeLoaded else { return }
        if !username.isEmpty {
            usernameTextField.setText(username)
        }
        updateSaveButtonState()
    }

    /// Применить результат валидации ника (из контроллера) и пересчитать кнопку Save.
    func applyUsernameState(_ state: UsernameState) {
        self.usernameState = state
        updateSaveButtonState()
    }

    private func renderUsernameState() {
        switch usernameState {
        case .neutral:
            usernameSpinner.stopAnimating()
            usernameStatusLabel.text = nil
            usernameStatusRow.isHidden = true
        case .checking:
            usernameSpinner.startAnimating()
            usernameStatusLabel.text = nil
            usernameStatusRow.isHidden = false
        case let .available(message):
            usernameSpinner.stopAnimating()
            usernameStatusLabel.text = message
            usernameStatusLabel.textColor = DivoColorPalette.snackbarSuccess
            usernameStatusRow.isHidden = false
        case let .error(message):
            usernameSpinner.stopAnimating()
            usernameStatusLabel.text = message
            usernameStatusLabel.textColor = DivoColorPalette.errorState
            usernameStatusRow.isHidden = false
        }
    }

    private func currentFirstNameTrimmed() -> String {
        return (nameTextField.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentLastNameTrimmed() -> String {
        return (lastNameTextField.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentHandle() -> String {
        var raw = usernameTextField.textField.text ?? ""
        while raw.hasPrefix("@") { raw.removeFirst() }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateSaveButtonState() {
        let first = currentFirstNameTrimmed()
        let last = currentLastNameTrimmed()
        let handle = currentHandle()
        let nameChanged = first != initialFirstName || last != initialLastName
        let usernameChanged = handle != initialUsername
        let usernameOK: Bool
        switch usernameState {
        case .neutral, .available:
            usernameOK = true
        case .checking, .error:
            usernameOK = false
        }
        let canSave = !first.isEmpty && usernameOK && (nameChanged || usernameChanged)
        applyButton.isEnabled = canSave
    }

    // MARK: - Actions

    @objc private func nameDidChange() {
        updateSaveButtonState()
    }

    @objc private func usernameDidChange() {
        let handle = currentHandle()
        // Пустой/неизменённый ник валиден без обращения к серверу; иначе ждём проверки занятости.
        self.usernameState = (handle.isEmpty || handle == initialUsername) ? .neutral : .checking
        onUsernameChanged?(handle)
        updateSaveButtonState()
    }

    @objc private func saveButtonPressed() {
        view.endEditing(true)
        let firstName = currentFirstNameTrimmed()
        let lastName = currentLastNameTrimmed()
        guard !firstName.isEmpty else { return }

        let handle = currentHandle()
        let action: UsernameAction
        if handle == initialUsername {
            action = .unchanged
        } else if handle.isEmpty {
            action = .clear
        } else {
            action = .set(handle)
        }

        toggleSaving(active: true)
        onSave?(firstName, lastName, action)
    }

    // MARK: - Snackbar

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: view,
            message: message,
            style: style,
            bottomInset: DivoDesignTokens.Spacing.m,
            bottomAnchor: applyButton.topAnchor,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }
}

private final class SetNameGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}
