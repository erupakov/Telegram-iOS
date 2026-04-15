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
    var saveSocialLinks: ((LinksData) -> Void)?
    
    private var linksData: LinksData
    
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
    
    private let instagramTextField: DivoTextField
    private let tiktokTextField: DivoTextField
    private let youtubeTextField: DivoTextField
    private let websiteTextField: DivoTextField
    
    private var initialTexts: [String] = []

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
    
    init(context: AccountContext, presentationData: PresentationData, linksData: LinksData) {
        self.context = context
        self.linksData = linksData
        self.presentationData = presentationData
        
        let tiktok = linksData.tiktokUrl ?? ""
        let youtube = linksData.youtubeUrl ?? ""
        let instagram = linksData.instagramUrl ?? ""
        let website = linksData.websiteUrl ?? ""

        self.instagramTextField = DivoTextField(title: instagram, prefix: "instagram.com/")
        self.tiktokTextField = DivoTextField(title: tiktok, prefix: "tiktok.com/")
        self.youtubeTextField = DivoTextField(title: youtube, prefix: "youtube.com/")
        
        self.websiteTextField = DivoTextField(title: website, prefix: "")
        self.websiteTextField.textField.attributedPlaceholder = NSAttributedString(
            string: DivoStrings.enterYourWebsite,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        
        super.init()
        
        self.backgroundColor = DivoColorPalette.screenBackground
        
        navigationBar.makeNavigationBar(
            title: DivoStrings.editSocialLinks.uppercased(),
            backButtonConfiguration: .circle("chevron.left"),
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

        let fields = [instagramTextField, tiktokTextField, youtubeTextField, websiteTextField]
        initialTexts = fields.map { $0.textField.text ?? "" }
        applyButton.isEnabled = false
    }

    private func updateSaveButtonState() {
        let fields = [instagramTextField, tiktokTextField, youtubeTextField, websiteTextField]
        let currentTexts = fields.map { $0.textField.text ?? "" }
        let hasChanges = currentTexts != initialTexts
        applyButton.isEnabled = hasChanges
    }
    
    private func setupUI() {
        view.addSubview(navigationBar)
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        let formElements = [
            instagramTextField,
            tiktokTextField,
            youtubeTextField,
            websiteTextField
        ]
        
        for field in formElements {
            field.view.translatesAutoresizingMaskIntoConstraints = false
            field.view.heightAnchor.constraint(equalToConstant: 46).isActive = true
            contentStackView.addArrangedSubview(field.view)
        }
        
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

        let fields = [instagramTextField, tiktokTextField, youtubeTextField, websiteTextField]
        keyboardHandler = DivoKeyboardHandler(
            scrollView: scrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 0,
            scrollToActiveField: { [weak self] in
                guard let self else { return }
                let allFields = [self.instagramTextField, self.tiktokTextField, self.youtubeTextField, self.websiteTextField]
                if let active = allFields.first(where: { $0.textField.isFirstResponder }) {
                    self.scrollToField(active)
                }
            }
        )
        keyboardHandler?.subscribe()

        for (index, field) in fields.enumerated() {
            let isLast = index == fields.count - 1
            field.textField.returnKeyType = isLast ? .done : .next
            if !isLast {
                let nextField = fields[index + 1]
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

    private func constructFullURL(from handle: String, with prefix: String) -> String? {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        
        let plainHandle = trimmed
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        
        var userPath = plainHandle
        if !prefix.isEmpty {
            let cleanPrefix = prefix.replacingOccurrences(of: "/", with: "")
            userPath = plainHandle.replacingOccurrences(of: cleanPrefix, with: "")
        }
        
        let cleanedPath = userPath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if cleanedPath.isEmpty { return nil }
        
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return trimmed }
        return "https://\(trimmed)"
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

        let instagramHandle = self.instagramTextField.textField.text ?? ""
        let tiktokHandle = self.tiktokTextField.textField.text ?? ""
        let youtubeHandle = self.youtubeTextField.textField.text ?? ""
        let websiteHandle = self.websiteTextField.textField.text ?? ""

        let linksData = LinksData(
            tiktokUrl: constructFullURL(from: tiktokHandle, with: "tiktok.com/"),
            youtubeUrl: constructFullURL(from: youtubeHandle, with: "youtube.com/"),
            telegramUrl: nil,
            instagramUrl: constructFullURL(from: instagramHandle, with: "instagram.com/"),
            websiteUrl: constructFullURL(from: websiteHandle, with: "")
        )
        
        self.toggleSaving(active: true)
        self.saveSocialLinks?(linksData)
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
