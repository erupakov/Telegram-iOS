import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI
import DivoUIKit

/// Описание одного поля ссылки: model-режим собирает статичный набор,
/// agency-режим строит поля из справочника /social-network (id = socialNetworkId).
struct SocialLinkFieldSpec {
    let id: Int
    let prefix: String
    let placeholder: String?
    let initialText: String
}

final class EditSocialLinksNode: ASDisplayNode, UITextFieldDelegate {
    
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    private var readyValue = false {
        didSet {
            if self.readyValue, self.readyValue != oldValue {
                self._ready.set(.single(self.readyValue))
            }
        }
    }
    var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    
    var onBackTapped: (() -> Void)?
    /// texts: id поля → текст вместе с prefix; changedIds — поля, отличающиеся от исходных
    var onSave: ((_ texts: [Int: String], _ changedIds: Set<Int>) -> Void)?

    private let navigationBar = DivoNavigationBar()
        
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12 // TODO: DS alignment — не в шкале Spacing (между s=8 и m=16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private var fieldEntries: [(spec: SocialLinkFieldSpec, field: DivoTextField)] = []
    private var pendingSpecs: [SocialLinkFieldSpec]?

    private var initialTexts: [String] = []

    private let fieldsSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    private let applyButton = DivoButton()

    private var applyButtonBottomConstraint: NSLayoutConstraint?

    private let bottomFadeOverlay: UIView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
                DivoColorPalette.screenBackground.cgColor
            ]
            gradient.locations = [0, 0.45]
        }
        return view
    }()

    private var bottomFadeOverlayBottomConstraint: NSLayoutConstraint?
    private var keyboardHandler: DivoKeyboardHandler?

    // MARK: - Init
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData

        super.init()
        
        self.backgroundColor = DivoColorPalette.screenBackground
        
        navigationBar.makeNavigationBar(
            title: DivoStrings.editSocialLinks.uppercased(),
            backButtonConfiguration: .circle(DivoImage.searchChevronLeft),
            onBackTapped: { [weak self] in self?.onBackTapped?() }
        )

        applyButton.makeDivoButton(title: DivoStrings.save, loading: DivoStrings.saving)
    }

    deinit {
        self.supportPeerDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didLoad() {
        super.didLoad()
        setupUI()
        setupConstraints()
        setupInteractions()

        applyButton.isEnabled = false
        if let specs = pendingSpecs {
            pendingSpecs = nil
            buildFields(specs)
        }
    }

    private func updateSaveButtonState() {
        let currentTexts = fieldEntries.map { $0.field.textField.text ?? "" }
        applyButton.isEnabled = currentTexts != initialTexts
    }

    /// Набор полей задаёт контроллер: model — статичный, agency — из справочника.
    func setFields(_ specs: [SocialLinkFieldSpec]) {
        if self.isNodeLoaded {
            buildFields(specs)
        } else {
            pendingSpecs = specs
        }
    }

    func setFieldsLoading(_ active: Bool) {
        if active {
            fieldsSpinner.startAnimating()
        } else {
            fieldsSpinner.stopAnimating()
        }
    }

    private func buildFields(_ specs: [SocialLinkFieldSpec]) {
        for entry in fieldEntries {
            entry.field.view.removeFromSuperview()
        }

        fieldEntries = specs.map { spec in
            let field = DivoTextField(title: spec.initialText, prefix: spec.prefix)
            if let placeholder = spec.placeholder {
                field.textField.attributedPlaceholder = NSAttributedString(
                    string: placeholder,
                    font: Font.regular(16),
                    textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
                )
            }
            return (spec, field)
        }

        for (index, entry) in fieldEntries.enumerated() {
            let field = entry.field
            field.view.translatesAutoresizingMaskIntoConstraints = false
            field.view.heightAnchor.constraint(equalToConstant: 46).isActive = true
            contentStackView.addArrangedSubview(field.view)

            let isLast = index == fieldEntries.count - 1
            field.textField.returnKeyType = isLast ? .done : .next
            if !isLast {
                let nextField = fieldEntries[index + 1].field
                field.onReturn = { [weak nextField] in
                    nextField?.textField.becomeFirstResponder()
                }
            }
            field.onBeginEditing = { [weak self, weak field] in
                guard let self, let field else { return }
                self.scrollToField(field)
            }
            field.textField.addTarget(self, action: #selector(textFieldDidChangeValue), for: .editingChanged)
        }

        initialTexts = fieldEntries.map { $0.field.textField.text ?? "" }
        applyButton.isEnabled = false
        hideSnackbar(animated: true)
    }

    private func setupUI() {
        view.addSubview(navigationBar)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        view.addSubview(fieldsSpinner)
        view.addSubview(bottomFadeOverlay)
        view.addSubview(applyButton)
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        let buttonBottomCns = applyButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        self.applyButtonBottomConstraint = buttonBottomCns

        let bottomFadeOverlayCns = bottomFadeOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        self.bottomFadeOverlayBottomConstraint = bottomFadeOverlayCns
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: safeArea.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // --- ScrollView ---
            scrollView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: DivoDesignTokens.Spacing.m),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: DivoDesignTokens.Spacing.m),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -DivoDesignTokens.Spacing.xl),
            
            fieldsSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fieldsSpinner.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 48),

            buttonBottomCns,
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            bottomFadeOverlayCns,
            bottomFadeOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFadeOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFadeOverlay.heightAnchor.constraint(equalToConstant: 160)
        ])
    }
    
    private func setupInteractions() {
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(dismissTap)
        scrollView.keyboardDismissMode = .interactive

        keyboardHandler = DivoKeyboardHandler(
            scrollView: scrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 0,
            scrollToActiveField: { [weak self] in
                guard let self else { return }
                if let active = self.fieldEntries.first(where: { $0.field.textField.isFirstResponder })?.field {
                    self.scrollToField(active)
                }
            }
        )
        keyboardHandler?.subscribe()

        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        if !readyValue {
            readyValue = true
        }
    }
    
    func toggleSaving(active: Bool) {
        applyButton.setSaving(active, in: self.view)
    }

    private func scrollToField(_ field: DivoTextField) {
        let frame = field.view.frame.insetBy(dx: 0, dy: -16)
        scrollView.scrollRectToVisible(frame, animated: true)
    }

    // MARK: - Actions

    @objc private func textFieldDidChangeValue() {
        updateSaveButtonState()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func applyButtonTapped() {
        view.endEditing(true)

        var texts: [Int: String] = [:]
        var changedIds: Set<Int> = []
        for (index, entry) in fieldEntries.enumerated() {
            let text = entry.field.textField.text ?? ""
            texts[entry.spec.id] = text
            if index < initialTexts.count, text != initialTexts[index] {
                changedIds.insert(entry.spec.id)
            }
        }

        self.toggleSaving(active: true)
        self.onSave?(texts, changedIds)
    }
    
    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: 16,
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

// MARK: - GradientView

private final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
}
