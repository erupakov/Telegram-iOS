import Display
import UIKit
import AsyncDisplayKit
import DivoUIKit
import DivoCore

final class SetNameNode: ASDisplayNode {

    private enum Layout {
        static let buttonBottomInset: CGFloat = 40
        static let bottomFadeHeight: CGFloat = 140
        static let bottomFadeOpaqueLocation: NSNumber = 0.45
        static let navBarToContentSpacing: CGFloat = 24
    }

    var onBackTapped: (() -> Void)?
    var saveName: ((String) -> Void)?

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

    private let nameTextField: DivoTextField
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

    private let initialName: String

    // MARK: - Init

    init(currentName: String?) {
        let name = (currentName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.initialName = name
        self.nameTextField = DivoTextField(title: name, prefix: "")
        super.init()

        self.backgroundColor = DivoColorPalette.screenBackground

        navigationBar.makeNavigationBar(
            title: DivoStrings.settingsSetUsername.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            rightButtonConfiguration: .text(DivoStrings.save),
            onBackTapped: { [weak self] in self?.onBackTapped?() },
            onCircleTextTapped: { [weak self] in self?.saveButtonPressed() }
        )

        applyButton.makeDivoButton(title: DivoStrings.save, loading: DivoStrings.saving)
    }

    deinit {
        keyboardHandler?.unsubscribe()
    }

    override func didLoad() {
        super.didLoad()

        nameTextField.textField.attributedPlaceholder = NSAttributedString(
            string: DivoStrings.name,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        nameTextField.textField.autocapitalizationType = .words
        nameTextField.textField.returnKeyType = .done
        nameTextField.onReturn = { [weak self] in self?.view.endEditing(true) }

        setupUI()
        setupConstraints()

        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Layout.bottomFadeHeight, right: 0)
        scrollView.scrollIndicatorInsets = scrollView.contentInset

        nameTextField.textField.addTarget(self, action: #selector(nameDidChange), for: .editingChanged)
        applyButton.addTarget(self, action: #selector(saveButtonPressed), for: .touchUpInside)

        keyboardHandler = DivoKeyboardHandler(
            scrollView: scrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: Layout.bottomFadeHeight
        )
        keyboardHandler?.subscribe()

        updateSaveButtonState()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(navigationBar)

        nameTextField.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(nameTextField.view)
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

            nameTextField.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Layout.navBarToContentSpacing),
            nameTextField.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            nameTextField.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            nameTextField.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            nameTextField.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),

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

    private func updateSaveButtonState() {
        let trimmed = (nameTextField.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let isValid = !trimmed.isEmpty && trimmed != initialName
        applyButton.isEnabled = isValid
        navigationBar.setEnableRightButton(isValid)
    }

    // MARK: - Actions

    @objc private func nameDidChange() {
        updateSaveButtonState()
    }

    @objc private func saveButtonPressed() {
        view.endEditing(true)
        let trimmed = (nameTextField.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        toggleSaving(active: true)
        saveName?(trimmed)
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
