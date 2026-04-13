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
    private let presentationDataPromise: Promise<PresentationData>
    
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
    
    private let scrollNode: ASScrollNode
    
    private let instagramTextField: DivoTextField
    private let tiktokTextField: DivoTextField
    private let telegramTextField: DivoTextField
    private let youtubeTextField: DivoTextField
    private let websiteTextField: DivoTextField
    
    private let applyButton: ASControlNode
    private let applyButtonSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.hidesWhenStopped = true
        return spinner
    }()
    private let addPhoto: () -> Void
    var showAlert: ((String) -> Void)?
    var saveSocialLinks: ((LinksData) -> Void)?

    private var linksData: LinksData
    
    init(context: AccountContext, presentationData: PresentationData, linksData: LinksData, addPhoto: @escaping () -> Void) {
        self.context = context
        self.addPhoto = addPhoto
        self.linksData = linksData
        
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.scrollNode = ASScrollNode()
        
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
            font: Font.bold(16),
            textColor: DivoColorPalette.overlayInputIcon
        )
        
        self.applyButton = ButtonWithIconNode(title: DivoStrings.save, icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = DivoColorPalette.accentCopperWarm
        
        super.init()
        
        self.backgroundColor = DivoColorPalette.darkBackground
        
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.addSubnode(self.instagramTextField)
        self.scrollNode.addSubnode(self.tiktokTextField)
        self.scrollNode.addSubnode(self.youtubeTextField)
        self.scrollNode.addSubnode(self.telegramTextField)
        self.scrollNode.addSubnode(self.websiteTextField)
        
        self.scrollNode.addSubnode(self.applyButton)
        self.applyButton.view.addSubview(self.applyButtonSpinner)
    }

    deinit {
        self.supportPeerDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
    }

    override func didLoad() {
        super.didLoad()
        self.applyButton.addTarget(self, action: #selector(self.applyButtonTapped), forControlEvents: .touchUpInside)

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        scrollNode.view.addGestureRecognizer(dismissTap)

        scrollNode.view.keyboardDismissMode = .interactive

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        let fields = [instagramTextField, tiktokTextField, youtubeTextField, telegramTextField, websiteTextField]
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
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let keyboardHeight = keyboardFrame.height
        scrollNode.view.contentInset.bottom = keyboardHeight
        scrollNode.view.verticalScrollIndicatorInsets.bottom = keyboardHeight

        UIView.animate(withDuration: duration) {
            let fields = [self.instagramTextField, self.tiktokTextField, self.youtubeTextField, self.telegramTextField, self.websiteTextField]
            if let active = fields.first(where: { $0.textField.isFirstResponder }) {
                self.scrollToField(active)
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        UIView.animate(withDuration: duration) {
            self.scrollNode.view.contentInset.bottom = 0
            self.scrollNode.view.verticalScrollIndicatorInsets.bottom = 0
        }
    }

    private func scrollToField(_ field: DivoTextField) {
        let frame = field.frame.insetBy(dx: 0, dy: -16)
        scrollNode.view.scrollRectToVisible(frame, animated: true)
    }

    func toggleSpinner(active: Bool) {
        self.applyButton.isUserInteractionEnabled = !active
        
        if active {
            self.applyButtonSpinner.startAnimating()
            UIView.animate(withDuration: 0.2) {
                self.applyButton.subnodes?.forEach { $0.alpha = 0.0 }
            }
        } else {
            self.applyButtonSpinner.stopAnimating()
            UIView.animate(withDuration: 0.2) {
                self.applyButton.subnodes?.forEach { $0.alpha = 1.0 }
            }
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
        let topInset = navigationBarHeight
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset))
        
        let sidePadding: CGFloat = 16.0
        let sectionSpacing: CGFloat = 24.0
        let itemHeight: CGFloat = 48.0
        
        var currentY: CGFloat = 30.0
        
        self.instagramTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.tiktokTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.youtubeTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing

        self.telegramTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing

        self.websiteTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.applyButton.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: 50.0))
        
        self.applyButtonSpinner.center = CGPoint(x: self.applyButton.bounds.midX, y: self.applyButton.bounds.midY)

        currentY += 70.0
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY)
        self.readyValue = true
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
        if cleanedPath.isEmpty {
            return nil
        }
        
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        
        return "https://\(trimmed)"
    }

    @objc private func applyButtonTapped() {
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
}