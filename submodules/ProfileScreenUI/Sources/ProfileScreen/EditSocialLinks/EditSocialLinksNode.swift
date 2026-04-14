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
    
    private let navigationBar: DivoNavigationBar = {
        let bar = DivoNavigationBar()
        bar.setTitle(DivoStrings.editSocialLinks)
        return bar
    }()
        
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
    private let telegramTextField: DivoTextField
    private let websiteTextField: DivoTextField
    
    private var initialTexts: [String] = []

    private static let saveButtonFont = UIFont(name: "HelveticaNeue-CondensedBold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
    private static let saveButtonDisabledBackground = UIColor(red: 228/255, green: 228/255, blue: 228/255, alpha: 1)
    private static let saveButtonDisabledTextColor = UIColor(red: 175/255, green: 175/255, blue: 177/255, alpha: 1)

    private let applyButton: UIButton = {
        let btn = UIButton(type: .custom)
        let font = EditSocialLinksNode.saveButtonFont
        let kern: CGFloat = 18 * 0.005

        let normalAttr: [NSAttributedString.Key: Any] = [
            .font: font, .kern: kern, .foregroundColor: DivoColorPalette.primaryTextOnDark
        ]
        btn.setAttributedTitle(NSAttributedString(string: DivoStrings.save.uppercased(), attributes: normalAttr), for: .normal)

        let disabledAttr: [NSAttributedString.Key: Any] = [
            .font: font, .kern: kern, .foregroundColor: EditSocialLinksNode.saveButtonDisabledTextColor
        ]
        btn.setAttributedTitle(NSAttributedString(string: DivoStrings.save.uppercased(), attributes: disabledAttr), for: .disabled)

        btn.backgroundColor = DivoColorPalette.accent
        btn.layer.cornerRadius = 28 // TODO: DS alignment — не в шкале Radius
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private var applyButtonBottomConstraint: NSLayoutConstraint?
    
    private let applyButtonSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = DivoColorPalette.cardBackground
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

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
        let telegram = linksData.telegramUrl ?? ""
        let instagram = linksData.instagramUrl ?? ""
        let website = linksData.websiteUrl ?? ""

        self.instagramTextField = DivoTextField(title: instagram, prefix: "instagram.com/")
        self.tiktokTextField = DivoTextField(title: tiktok, prefix: "tiktok.com/")
        self.youtubeTextField = DivoTextField(title: youtube, prefix: "youtube.com/")
        self.telegramTextField = DivoTextField(title: telegram, prefix: "t.me/")
        
        self.websiteTextField = DivoTextField(title: website, prefix: "")
        self.websiteTextField.textField.attributedPlaceholder = NSAttributedString(
            string: DivoStrings.enterYourWebsite,
            font: Font.regular(16),
            textColor: DivoColorPalette.primaryText.withAlphaComponent(0.4)
        )
        
        super.init()
        
        self.backgroundColor = DivoColorPalette.screenBackground
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

        let fields = [instagramTextField, tiktokTextField, youtubeTextField, telegramTextField, websiteTextField]
        initialTexts = fields.map { $0.textField.text ?? "" }
        applyButton.isEnabled = false
        applyButton.backgroundColor = Self.saveButtonDisabledBackground
    }

    private func updateSaveButtonState() {
        let fields = [instagramTextField, tiktokTextField, youtubeTextField, telegramTextField, websiteTextField]
        let currentTexts = fields.map { $0.textField.text ?? "" }
        let hasChanges = currentTexts != initialTexts
        applyButton.isEnabled = hasChanges
        applyButton.backgroundColor = hasChanges
            ? DivoColorPalette.accent
            : Self.saveButtonDisabledBackground
    }
    
    private func setupUI() {
        view.addSubview(navigationBar)
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        let formElements = [
            instagramTextField,
            tiktokTextField,
            youtubeTextField,
            telegramTextField,
            websiteTextField
        ]
        
        for field in formElements {
            field.view.translatesAutoresizingMaskIntoConstraints = false
            field.view.heightAnchor.constraint(equalToConstant: 46).isActive = true
            contentStackView.addArrangedSubview(field.view)
        }
        
        applyButton.heightAnchor.constraint(equalToConstant: 56).isActive = true

        view.addSubview(bottomFadeOverlay)
        view.addSubview(applyButton)
        
        applyButton.addSubview(applyButtonSpinner)
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
            applyButtonSpinner.centerXAnchor.constraint(equalTo: applyButton.centerXAnchor),
            applyButtonSpinner.centerYAnchor.constraint(equalTo: applyButton.centerYAnchor),
            
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

        let fields = [instagramTextField, tiktokTextField, youtubeTextField, telegramTextField, websiteTextField]
        keyboardHandler = DivoKeyboardHandler(
            scrollView: scrollView,
            buttonConstraint: applyButtonBottomConstraint!,
            overlayConstraint: bottomFadeOverlayBottomConstraint!,
            hostView: self.view,
            defaultScrollInset: 0,
            scrollToActiveField: { [weak self] in
                guard let self else { return }
                let allFields = [self.instagramTextField, self.tiktokTextField, self.youtubeTextField, self.telegramTextField, self.websiteTextField]
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

        navigationBar.onBackTapped = { [weak self] in self?.onBackTapped?() }
        applyButton.addTarget(self, action: #selector(applyButtonTapped), for: .touchUpInside)

        applyButton.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchDown)
        applyButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        if !readyValue {
            readyValue = true
        }
    }
    
    func toggleSpinner(active: Bool) {
        self.applyButton.isUserInteractionEnabled = !active

        if active {
            self.applyButtonSpinner.startAnimating()
            UIView.animate(withDuration: 0.2) {
                self.applyButton.setAttributedTitle(NSAttributedString(string: ""), for: .normal)
            }
        } else {
            self.applyButtonSpinner.stopAnimating()
            let kern: CGFloat = 18 * 0.005
            let attr: [NSAttributedString.Key: Any] = [
                .font: Self.saveButtonFont, .kern: kern, .foregroundColor: DivoColorPalette.primaryTextOnDark
            ]
            UIView.animate(withDuration: 0.2) {
                self.applyButton.setAttributedTitle(NSAttributedString(string: DivoStrings.save.uppercased(), attributes: attr), for: .normal)
            }
        }
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
        let telegramHandle = self.telegramTextField.textField.text ?? ""
        let websiteHandle = self.websiteTextField.textField.text ?? ""
        
        let linksData = LinksData(
            tiktokUrl: constructFullURL(from: tiktokHandle, with: "tiktok.com/"),
            youtubeUrl: constructFullURL(from: youtubeHandle, with: "youtube.com/"),
            telegramUrl: constructFullURL(from: telegramHandle, with: "t.me/"),
            instagramUrl: constructFullURL(from: instagramHandle, with: "instagram.com/"),
            websiteUrl: constructFullURL(from: websiteHandle, with: "")
        )
        
        self.toggleSpinner(active: true)
        self.saveSocialLinks?(linksData)
    }
    
    @objc private func buttonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            sender.alpha = 0.6
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        })
    }
    
    @objc private func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, animations: {
            sender.alpha = 1.0
            sender.transform = .identity
        })
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