import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import SolidRoundedButtonNode
import AuthorizationUtils

final class AuthorizationSequenceSignUpControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let addPhoto: () -> Void
    
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    private let termsNode: ImmediateTextNode
    
    private let firstNameField: TextFieldNode
    private let lastNameField: TextFieldNode
    private let firstSeparatorNode: ASDisplayNode
    private let lastSeparatorNode: ASDisplayNode
    private let addPhotoButton: HighlightableButtonNode
    private let proceedNode: SolidRoundedButtonNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    private let appearanceTimestamp = CACurrentMediaTime()
    
    var currentName: (String, String) {
        return (self.firstNameField.textField.text ?? "", self.lastNameField.textField.text ?? "")
    }
    
    var signUpWithName: ((String, String) -> Void)?
    var openTermsOfService: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.firstNameField.alpha = self.inProgress ? 0.6 : 1.0
            self.lastNameField.alpha = self.inProgress ? 0.6 : 1.0
            
            if self.inProgress != oldValue {
                if self.inProgress {
                    self.proceedNode.transitionToProgress()
                } else {
                    self.proceedNode.transitionFromProgress()
                }
            }
        }
    }
    
    let titleNode_new: ASTextNode
    let subtitleNode: ASTextNode
    
    private let talentNode: RoleSelectionNode
    private let modelNode: RoleSelectionNode
    private let agencyNode: RoleSelectionNode
    
    private var selectedNode: RoleSelectionNode?
    private let backgroundNode: ASImageNode
    
    init(theme: PresentationTheme, strings: PresentationStrings, addPhoto: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.addPhoto = addPhoto
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_InfoTitle, font: Font.semibold(28.0), textColor: theme.list.itemPrimaryTextColor)
        
        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isUserInteractionEnabled = false
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.attributedText = NSAttributedString(string: self.strings.Login_InfoHelp, font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        self.termsNode = ImmediateTextNode()
        self.termsNode.textAlignment = .center
        self.termsNode.maximumNumberOfLines = 0
        self.termsNode.displaysAsynchronously = false
        let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.termsNode.attributedText = parseMarkdownIntoAttributedString(strings.Login_TermsOfServiceLabel.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        self.firstSeparatorNode = ASDisplayNode()
        self.firstSeparatorNode.isLayerBacked = true
        self.firstSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.lastSeparatorNode = ASDisplayNode()
        self.lastSeparatorNode.isLayerBacked = true
        self.lastSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.firstNameField = TextFieldNode()
        self.firstNameField.textField.font = Font.regular(20.0)
        self.firstNameField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.firstNameField.textField.textAlignment = .natural
        self.firstNameField.textField.returnKeyType = .next
        self.firstNameField.textField.attributedPlaceholder = NSAttributedString(string: self.strings.UserInfo_FirstNamePlaceholder, font: self.firstNameField.textField.font, textColor: self.theme.list.itemPlaceholderTextColor)
        self.firstNameField.textField.autocapitalizationType = .words
        self.firstNameField.textField.autocorrectionType = .no
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.firstNameField.textField.textContentType = .givenName
        }
        self.firstNameField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.firstNameField.textField.tintColor = theme.list.itemAccentColor
        
        self.lastNameField = TextFieldNode()
        self.lastNameField.textField.font = Font.regular(20.0)
        self.lastNameField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.lastNameField.textField.textAlignment = .natural
        self.lastNameField.textField.returnKeyType = .done
        self.lastNameField.textField.attributedPlaceholder = NSAttributedString(string: strings.UserInfo_LastNamePlaceholder, font: self.lastNameField.textField.font, textColor: self.theme.list.itemPlaceholderTextColor)
        self.lastNameField.textField.autocapitalizationType = .words
        self.lastNameField.textField.autocorrectionType = .no
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.lastNameField.textField.textContentType = .familyName
        }
        self.lastNameField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.lastNameField.textField.tintColor = theme.list.itemAccentColor
        
        self.addPhotoButton = HighlightableButtonNode()
        self.addPhotoButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Avatar/EditAvatarIconLarge"), color: self.theme.list.itemAccentColor), for: .normal)
        self.addPhotoButton.setBackgroundImage(generateFilledCircleImage(diameter: 110.0, color: self.theme.list.itemAccentColor.withAlphaComponent(0.1), strokeColor: nil, strokeWidth: nil, backgroundColor: nil), for: .normal)
        
        self.addPhotoButton.allowsGroupOpacity = true
        
        let customButtonTheme = SolidRoundedButtonTheme(
            backgroundColor: UIColor(red: 0.75, green: 0.48, blue: 0.33, alpha: 1.00),
            foregroundColor: .white,
            disabledBackgroundColor: UIColor(red: 0.75, green: 0.48, blue: 0.33, alpha: 1.00),
            disabledForegroundColor: .white
        )
        
        self.proceedNode = SolidRoundedButtonNode(title: self.strings.Login_Continue, theme: customButtonTheme, height: 50.0, cornerRadius: 11.0, gloss: false)
        self.proceedNode.progressType = .embedded
        
        self.titleNode_new = ASTextNode()
        self.titleNode_new.attributedText = NSAttributedString(string: "Choose a role".uppercased(), attributes: [
            .font: UIFont.boldSystemFont(ofSize: 34),
            .foregroundColor: UIColor.white
        ])
        
        self.subtitleNode = ASTextNode()
        self.subtitleNode.attributedText = NSAttributedString(string: "Select the role that your profile will correspond to. The role can be changed at any time", attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ])
        
        self.talentNode = RoleSelectionNode(
            roleImage: UIImage(bundleImageName: "Components/NewTalent"),
            title: "NEW TALENT",
            description: "I don’t have any experience / have little experience. I’m new in."
        )
        self.modelNode = RoleSelectionNode(
            roleImage: UIImage(bundleImageName: "Components/Model"),
            title: "MODEL",
            description: "I have working experience as a model. I’m professional."
        )
        self.agencyNode = RoleSelectionNode(
            roleImage: UIImage(bundleImageName: "Components/Agencies"),
            title: "AGENCIES & SCOUTS",
            description: "Looking for / working with models."
        )
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.contentMode = .scaleAspectFill
        self.backgroundNode.image = UIImage(named: "Components/ChooseRoleBackground")
        self.backgroundNode.displaysAsynchronously = false
        
        super.init()
        
        self.automaticallyManagesSubnodes = true
        
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(titleNode_new)
        self.addSubnode(subtitleNode)
        self.addSubnode(talentNode)
        self.addSubnode(modelNode)
        self.addSubnode(agencyNode)
        
        self.talentNode.tapped = { [weak self] in self?.selectNode(self!.talentNode) }
        self.modelNode.tapped = { [weak self] in self?.selectNode(self!.modelNode) }
        self.agencyNode.tapped = { [weak self] in self?.selectNode(self!.agencyNode) }
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        self.firstNameField.textField.delegate = self
        self.lastNameField.textField.delegate = self
        
        self.addSubnode(self.firstSeparatorNode)
        self.addSubnode(self.lastSeparatorNode)
        self.addSubnode(self.firstNameField)
        self.addSubnode(self.lastNameField)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.termsNode)
        self.termsNode.isHidden = true
        self.addSubnode(self.addPhotoButton)
        self.addSubnode(self.proceedNode)
        
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
        
        self.termsNode.linkHighlightColor = self.theme.list.itemAccentColor.withAlphaComponent(0.2)
        self.termsNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
            } else {
                return nil
            }
        }
        self.termsNode.tapAttributeAction = { [weak self] attributes, _ in
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                self?.openTermsOfService?()
            }
        }
        
        self.proceedNode.pressed = { [weak self] in
            if let strongSelf = self {
                let name = strongSelf.currentName
                strongSelf.signUpWithName?(name.0, name.1)
            }
        }
    }
    
    private func selectNode(_ node: RoleSelectionNode) {
        selectedNode?.isSelected = false
        selectedNode = node
        selectedNode?.isSelected = true
    }
    
    func updateData(firstName: String, lastName: String, hasTermsOfService: Bool) {
        self.termsNode.isHidden = !hasTermsOfService
        self.firstNameField.textField.attributedText = NSAttributedString(string: firstName, font: Font.regular(20.0), textColor: self.theme.list.itemPlaceholderTextColor)
        self.lastNameField.textField.attributedText = NSAttributedString(string: lastName, font: Font.regular(20.0), textColor: self.theme.list.itemPlaceholderTextColor)
        
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
        let maximumWidth: CGFloat = min(430.0, layout.size.width)
        
        let insets = layout.insets(options: [.statusBar])

        self.proceedNode.isHidden = false
        
        let inset: CGFloat = 24.0
        let proceedHeight = self.proceedNode.updateLayout(width: maximumWidth - 48.0, transition: transition)
        let proceedSize = CGSize(width: maximumWidth - 48.0, height: proceedHeight)
        transition.updateFrame(node: self.proceedNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0), y: layout.size.height - insets.bottom - proceedSize.height - inset), size: proceedSize))

        let sideInsets: CGFloat = 20.0
        let verticalSpacing: CGFloat = 15.0
        
        self.backgroundNode.frame = CGRect(origin: .zero, size: layout.size)
        
        let titleSize = self.titleNode_new.measure(CGSize(width: maximumWidth, height: .greatestFiniteMagnitude))
        let titleOriginY: CGFloat = 40.0
        let titleFrame = CGRect(
            origin: CGPoint(x: floorToScreenPixels((layout.size.width - titleSize.width) / 2.0), y: titleOriginY + 100),
            size: titleSize
        )
        self.titleNode_new.frame = titleFrame
        
        let noticeSize = self.subtitleNode.measure(CGSize(width: maximumWidth, height: .greatestFiniteMagnitude))
        let noticeFrame = CGRect(
            origin: CGPoint(x: floorToScreenPixels((layout.size.width - noticeSize.width) / 2.0), y: titleFrame.maxY + 5),
            size: noticeSize
        )
        self.subtitleNode.frame = noticeFrame
        
        var currentY = noticeFrame.maxY + 40
        let nodeWidth = maximumWidth - sideInsets * 2
        let nodeHeight: CGFloat = 120
        
        let talentFrame = CGRect(x: sideInsets, y: currentY, width: nodeWidth, height: nodeHeight)
        self.talentNode.frame = talentFrame
        self.talentNode.layout()
        currentY = talentFrame.maxY + verticalSpacing
        
        let modelFrame = CGRect(x: sideInsets, y: currentY, width: nodeWidth, height: nodeHeight)
        self.modelNode.frame = modelFrame
        self.modelNode.layout()
        currentY = modelFrame.maxY + verticalSpacing
        
        let agencyFrame = CGRect(x: sideInsets, y: currentY, width: nodeWidth, height: nodeHeight)
        self.agencyNode.frame = agencyFrame
        self.agencyNode.layout()
        currentY = agencyFrame.maxY + verticalSpacing
    }
    
    func activateInput() {
        self.firstNameField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        if self.firstNameField.textField.text == nil || self.firstNameField.textField.text!.isEmpty {
            self.firstNameField.layer.addShakeAnimation()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === self.firstNameField.textField {
            self.lastNameField.textField.becomeFirstResponder()
        } else {
            let name = self.currentName
            self.signUpWithName?(name.0, name.1)
        }
        return false
    }
    
    @objc private func addPhotoPressed() {
        self.addPhoto()
    }
}
