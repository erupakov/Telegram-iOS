import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI

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
    private let youtubeTextField: DivoTextField
    private let websiteTextField: DivoTextField
    
    private let applyButton: ASControlNode
    private let addPhoto: () -> Void
    var showAlert: ((String) -> Void)?
    
    private let model: ProfileModel
    
    init(context: AccountContext, model: ProfileModel, addPhoto: @escaping () -> Void) {
        self.context = context
        self.addPhoto = addPhoto
        self.model = model
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.scrollNode = ASScrollNode()
        
        self.instagramTextField = DivoTextField(title: "username", prefix: "instagram.com/")
        self.tiktokTextField = DivoTextField(title: "username", prefix: "tiktok.com/")
        self.youtubeTextField = DivoTextField(title: "username", prefix: "youtube.com/")
        
        self.websiteTextField = DivoTextField(title: "Enter your website")
        
        self.applyButton = ButtonWithIconNode(title: "Save", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.addSubnode(self.instagramTextField)
        self.scrollNode.addSubnode(self.tiktokTextField)
        self.scrollNode.addSubnode(self.youtubeTextField)
        self.scrollNode.addSubnode(self.websiteTextField)
        
        self.scrollNode.addSubnode(self.applyButton)
    }

    deinit {
        self.supportPeerDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didLoad() {
        super.didLoad()
        self.applyButton.addTarget(self, action: #selector(self.applyButtonTapped), forControlEvents: .touchUpInside)
    }

    @objc private func applyButtonTapped() {
        
        let instagram = instagramTextField.textField.text ?? ""
        let tiktok = tiktokTextField.textField.text ?? ""
        let youtube = youtubeTextField.textField.text ?? ""
        let website = websiteTextField.textField.text ?? ""
        
        
        let supportPeer = Promise<String?>()
        supportPeer.set(
            context.engine.profileEngine.updateSocialLinks(
                instagram: instagram,
                tiktok: tiktok,
                youtube: youtube,
                website: website
            ))
        
        self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { peerId in
            self.showAlert?("Saved")
        }))
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
        self.websiteTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        self.applyButton.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: 50.0))
        
        currentY += 70.0
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY)
        self.readyValue = true
    }
}

private func getTextFiel(title: String, isMultiline: Bool = false) -> TextFieldNode {
    let field = TextFieldNode()
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = .white.withAlphaComponent(0.6)
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    field.borderWidth = 1.0
    field.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
    field.cornerRadius = 11.0
    field.clipsToBounds = true
    if isMultiline {
        field.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    } else {
        field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    
    return field
}
