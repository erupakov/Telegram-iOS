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

private func roundCorners(diameter: CGFloat) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    context.setFillColor(UIColor.clear.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: diameter, height: diameter)))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    return image
}

final class ChooseRoleControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let addPhoto: () -> Void
    
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    private let termsNode: ImmediateTextNode
    
    private let sectionTitleNode: ASTextNode

    private let newSeparatorNode: ASDisplayNode
    private let websiteField: TextFieldNode
    
    private let currentPhotoNode: ASImageNode
    private let addPhotoButton: HighlightableButtonNode
    private let proceedNode: SolidRoundedButtonNode
    
    private let backNode: SolidRoundedButtonNode
    private let saveNode: SolidRoundedButtonNode
    
//    let titleNode_new: ASTextNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    private let appearanceTimestamp = CACurrentMediaTime()
    
    var currentName: (String, String) {
        return ("", "")
    }
    
    var currentPhoto: UIImage? = nil {
        didSet {
            if let currentPhoto = self.currentPhoto {
                self.currentPhotoNode.image = generateImage(CGSize(width: 110.0, height: 110.0), contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.copy)
                    context.draw(currentPhoto.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.destinationOut)
                    context.draw(roundCorners(diameter: size.width).cgImage!, in: CGRect(origin: CGPoint(), size: size))
                })
            } else {
                self.currentPhotoNode.image = nil
            }
        }
    }
    
    var signUpWithName: ((String, String) -> Void)?
    var openTermsOfService: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            
            if self.inProgress != oldValue {
                if self.inProgress {
                    self.proceedNode.transitionToProgress()
//                    self.saveNode.transitionToProgress()
                } else {
//                    self.saveNode.transitionFromProgress()
                    self.proceedNode.transitionFromProgress()
                }
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, addPhoto: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.addPhoto = addPhoto
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: "Apply as a agencies & brands".uppercased(), font: Font.bold(34), textColor: .white)
        
        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isUserInteractionEnabled = false
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.attributedText = NSAttributedString(
            string: "Fill out your profile details to apply as a professional model. You can update this information anytime.",
            font: Font.regular(16.0),
            textColor: .white.withAlphaComponent(0.6),
            paragraphAlignment: .center)
        
        self.termsNode = ImmediateTextNode()
        self.termsNode.textAlignment = .center
        self.termsNode.maximumNumberOfLines = 0
        self.termsNode.displaysAsynchronously = false
        let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.termsNode.attributedText = parseMarkdownIntoAttributedString(strings.Login_TermsOfServiceLabel.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        self.sectionTitleNode = ASTextNode()
        self.sectionTitleNode.isUserInteractionEnabled = false
        self.sectionTitleNode.displaysAsynchronously = false
        self.sectionTitleNode.attributedText = NSAttributedString(string: "Your personal data".uppercased(), font: Font.bold(20.0), textColor: .white, paragraphAlignment: .natural)
        
        newSeparatorNode = ASDisplayNode()
        newSeparatorNode.isLayerBacked = true
        newSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.websiteField = TextFieldNode()
        self.websiteField.textField.font = Font.regular(20.0)
        self.websiteField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.websiteField.textField.textAlignment = .natural
        self.websiteField.textField.attributedPlaceholder = NSAttributedString(string: "Enter name your website", font: self.websiteField.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
        self.websiteField.textField.autocapitalizationType = .none
        self.websiteField.textField.autocorrectionType = .no
        self.websiteField.textField.keyboardType = .URL
        self.websiteField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.websiteField.textField.tintColor = theme.list.itemAccentColor
        self.websiteField.borderWidth = 1.0
        self.websiteField.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
        self.websiteField.cornerRadius = 11.0
        self.websiteField.clipsToBounds = true
        self.websiteField.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        
        self.currentPhotoNode = ASImageNode()
        self.currentPhotoNode.isUserInteractionEnabled = false
        self.currentPhotoNode.displaysAsynchronously = false
        self.currentPhotoNode.displayWithoutProcessing = true
        
        self.addPhotoButton = HighlightableButtonNode()
        let iconColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        self.addPhotoButton.setImage(
            generateTintedImage(image: UIImage(bundleImageName: "Avatar/AddAvatarIconLarge"),
                                color: iconColor),
            for: .normal)
        self.addPhotoButton.setBackgroundImage(generateFilledCircleImage(diameter: 110.0, color: self.theme.list.itemAccentColor.withAlphaComponent(0.1), strokeColor: nil, strokeWidth: nil, backgroundColor: nil), for: .normal)
        
        let backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        let borderColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        self.addPhotoButton.setBackgroundImage(generateFilledCircleImage(diameter: 110.0, color: backgroundColor, strokeColor: borderColor, strokeWidth: 1.0, backgroundColor: nil), for: .normal)
                
        self.addPhotoButton.addSubnode(self.currentPhotoNode)
        self.addPhotoButton.allowsGroupOpacity = true
        
        self.proceedNode = SolidRoundedButtonNode(title: self.strings.Login_Continue, theme: SolidRoundedButtonTheme(theme: self.theme), height: 50.0, cornerRadius: 11.0, gloss: false)
        self.proceedNode.progressType = .embedded
        
//        self.titleNode_new = ASTextNode()
//        self.titleNode_new.attributedText = NSAttributedString(string: "Apply as a agencies & brands".uppercased(), attributes: [
//            .font: UIFont.boldSystemFont(ofSize: 34),
//            .foregroundColor: UIColor.white
//        ])
        
        let backButtonTheme = SolidRoundedButtonTheme(
            backgroundColor: UIColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.0),
            foregroundColor: .white
        )
        self.backNode = SolidRoundedButtonNode(
            title: "← Back",
            theme: backButtonTheme,
            height: 50.0,
            cornerRadius: 11.0,
            gloss: false
        )
//        self.backNode.progressType = .none
        
        let saveButtonTheme = SolidRoundedButtonTheme(
            backgroundColor: UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0),
            foregroundColor: .white
        )
        self.saveNode = SolidRoundedButtonNode(
            title: "Save",
            theme: saveButtonTheme,
            height: 50.0,
            cornerRadius: 11.0,
            gloss: false
        )
        self.saveNode.progressType = .embedded
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        self.addSubnode(self.sectionTitleNode)
        self.addSubnode(newSeparatorNode)

        self.addSubnode(self.websiteField)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.termsNode)
        self.termsNode.isHidden = true
        self.addSubnode(self.addPhotoButton)
        self.addSubnode(self.proceedNode)
        self.addSubnode(self.proceedNode)
        
        self.addSubnode(self.backNode)
        self.addSubnode(self.saveNode)
        
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
            print("ok 🍿")
            if let strongSelf = self {
                let name = strongSelf.currentName
                strongSelf.signUpWithName?(name.0, name.1)
            }
        }
        self.saveNode.pressed = { [weak self] in
            print("Save button pressed")
            if let strongSelf = self {
                let name = strongSelf.currentName
                strongSelf.signUpWithName?(name.0, name.1)
            }
        }
    }
    
    func updateData(firstName: String, lastName: String, hasTermsOfService: Bool) {
        self.termsNode.isHidden = !hasTermsOfService
       
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let previousInputHeight = self.layoutArguments?.0.inputHeight ?? 0.0
        let newInputHeight = layout.inputHeight ?? 0.0
        
        self.layoutArguments = (layout, navigationBarHeight)
        
        var layout = layout
        if CACurrentMediaTime() - self.appearanceTimestamp < 2.0, newInputHeight < previousInputHeight {
            layout = layout.withUpdatedInputHeight(previousInputHeight)
        }
        
        let maximumWidth: CGFloat = min(430.0, layout.size.width)
        
        var insets = layout.insets(options: [.statusBar])
        if let inputHeight = layout.inputHeight {
            insets.bottom = max(inputHeight, layout.standardInputHeight)
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth-40, height: .greatestFiniteMagnitude))
//        let titleOriginY: CGFloat = 40.0
//        let titleFrame = CGRect(
//            origin: CGPoint(x: 40, y: titleOriginY + 100),
//            size: titleSize
//        )
//        self.titleNode_new.frame = titleFrame
        
        let additionalBottomInset: CGFloat = layout.size.width > 320.0 ? 90.0 : 10.0
                
        self.titleNode.attributedText = NSAttributedString(string: "Apply as a agencies & brands".uppercased(), font: Font.bold(34), textColor: .white, paragraphAlignment: .center)
//        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let fieldHeight: CGFloat = 54.0
        
        let sideInset: CGFloat = 24.0
//        let innerInset: CGFloat = 16.0
        
        let noticeSize = self.currentOptionNode.measure(CGSize(width: maximumWidth - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let termsSize = self.termsNode.updateLayout(CGSize(width: maximumWidth - 80, height: CGFloat.greatestFiniteMagnitude))
        let sectionTitleSize = self.sectionTitleNode.measure(CGSize(width: maximumWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let avatarSize: CGSize = CGSize(width: 100.0, height: 100.0)
        var items: [AuthorizationLayoutItem] = []
        
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 42.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 20.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))

        items.append(AuthorizationLayoutItem(node: self.addPhotoButton, size: avatarSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        self.currentPhotoNode.frame = CGRect(origin: CGPoint(), size: avatarSize)
        
        items.append(AuthorizationLayoutItem(node: self.sectionTitleNode, size: CGSize(width: maximumWidth - sideInset * 2.0, height: sectionTitleSize.height), spacingBefore: AuthorizationLayoutItemSpacing(weight: 32.0, maxValue: 60.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0)))
        
        items.append(AuthorizationLayoutItem(node: self.websiteField, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))

        items.append(AuthorizationLayoutItem(node: newSeparatorNode, size: CGSize(width: layout.size.width - sideInset * 2.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.termsNode, size: termsSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 48.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        if layout.size.width > 320.0 {
            self.proceedNode.isHidden = false
            
            let inset: CGFloat = 24.0
            let proceedHeight = self.proceedNode.updateLayout(width: maximumWidth - 48.0, transition: transition)
            let proceedSize = CGSize(width: maximumWidth - 48.0, height: proceedHeight)
            transition.updateFrame(node: self.proceedNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0), y: layout.size.height - insets.bottom - proceedSize.height - inset), size: proceedSize))
        } else {
            insets.top = navigationBarHeight
            self.proceedNode.isHidden = true
        }
        
        let buttonWidth = (maximumWidth - 48.0 - 10.0) / 2.0 // 10.0 is the spacing between buttons
        let buttonHeight: CGFloat = 50.0
        let bottomInset: CGFloat = 24.0

        // Save Button
//        let saveButtonSize = CGSize(width: buttonWidth, height: buttonHeight)
        let saveButtonFrame = CGRect(
            x: floorToScreenPixels((layout.size.width - maximumWidth + 48.0) / 2.0) + buttonWidth + 10.0,
            y: layout.size.height - insets.bottom - buttonHeight - bottomInset,
            width: buttonWidth,
            height: buttonHeight
        )
        transition.updateFrame(node: self.saveNode, frame: saveButtonFrame)

        // Back Button
//        let backButtonSize = CGSize(width: buttonWidth, height: buttonHeight)
        let backButtonFrame = CGRect(
            x: floorToScreenPixels((layout.size.width - maximumWidth + 48.0) / 2.0),
            y: layout.size.height - insets.bottom - buttonHeight - bottomInset,
            width: buttonWidth,
            height: buttonHeight
        )
        transition.updateFrame(node: self.backNode, frame: backButtonFrame)

        // Hide the old proceedNode
//        self.proceedNode.isHidden = true
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - additionalBottomInset)), items: items, transition: transition, failIfDoesNotFit: false)
    }
    
    func activateInput() {
        
    }
    
    func animateError() {
       
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
//        if textField === self.firstNameField.textField {
//            self.lastNameField.textField.becomeFirstResponder()
//        } else {
//            let name = self.currentName
//            self.signUpWithName?(name.0, name.1)
//        }
        return false
    }
    
    @objc private func addPhotoPressed() {
        self.addPhoto()
    }
}
