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
import TelegramCore

private enum TypeOfRole: String {
    case talent = "TALENT"
    case model = "MODEL"
    case agencies = "AGENCIES"
}

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

private func getTextFiel(title: String) -> TextFieldNode {
    let field = TextFieldNode()
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = .white.withAlphaComponent(0.6)
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.4))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    //    field.textField.keyboardType = .URL
    field.borderWidth = 1.0
    field.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.4).cgColor
    field.cornerRadius = 11.0
    field.clipsToBounds = true
    field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    
    return field
}

final class ChooseRoleControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let typeOfRole: TypeOfRole
    private let addPhoto: () -> Void
    
    private let titleNode: ASTextNode
    private let currentOptionNode: ASTextNode
    
    private let sectionTitleNode: ASTextNode
    
    private let nameAgency: TextFieldNode
    private let chooseCountryField: TextFieldNode
    private var countryId: String = ""
    private let chooseGenderField: TextFieldNode
    private let chooseAgencyField: TextFieldNode
    private let websiteField: TextFieldNode
    
    private let ageSliderNode: AgeSliderNode
    
    private var activeTextField: UITextField?
    
    private let currentPhotoNode: ASImageNode
    private let addPhotoButton: HighlightableButtonNode
    
    private let backNode: ButtonWithIconNode
    private let saveNode: ButtonWithIconNode
    
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
    
    var signUpWithName: ((AuthorizationModelInfo) -> Void)?
    var selectCountryCode: (() -> Void)?
    var openTermsOfService: (() -> Void)?
    var back: (() -> Void)?
    
    var inProgress: Bool = false
    
    init(theme: PresentationTheme, strings: PresentationStrings, typeOfRole: String, addPhoto: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.addPhoto = addPhoto
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.typeOfRole = TypeOfRole(rawValue: typeOfRole) ?? .model
        
        var titleText = ""
        var nameAgencyText = ""
        
        switch self.typeOfRole {
        case .talent:
            titleText = "Apply as \n a new talent"
            nameAgencyText = "Full Name"
            
        case .model:
            titleText = "Apply as a \n Professional Model"
            nameAgencyText = "Full Name"
            
        case .agencies:
            titleText = "Apply as a \n agencies & brands"
            nameAgencyText = "Name Agency"
        }
        
        self.titleNode.attributedText = Font.helveticaNeue(titleText.uppercased(), 34)
        self.currentOptionNode = ASTextNode()
        self.currentOptionNode.isUserInteractionEnabled = false
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.attributedText = NSAttributedString(
            string: "Fill out your profile details to apply as a professional model. You can update this information anytime.",
            font: Font.regular(16.0),
            textColor: .white.withAlphaComponent(0.6),
            paragraphAlignment: .center)
        
        self.sectionTitleNode = ASTextNode()
        self.sectionTitleNode.isUserInteractionEnabled = false
        self.sectionTitleNode.displaysAsynchronously = false
        self.sectionTitleNode.attributedText = Font.helveticaNeue("Your personal data".uppercased(), 20, alignment: .left)
        
        self.nameAgency = getTextFiel(title: nameAgencyText)
        self.websiteField = getTextFiel(title: "Enter name your website")
        self.chooseCountryField = getTextFiel(title: "Choose a country")
        self.chooseGenderField = getTextFiel(title: "Select a Gender")
        self.chooseAgencyField = getTextFiel(title: "Choose agency name")
        
        self.ageSliderNode = AgeSliderNode()
        
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
        
        let backIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"),
                                           color: .white)
        
        let imageSize: CGSize = CGSize(width: 24, height: 24)
        self.backNode = ButtonWithIconNode(title: "Back", icon: backIcon, theme: theme, spacing: 10, imageSize: imageSize)
        self.backNode.backgroundColor = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.14)
        
        self.saveNode = ButtonWithIconNode(title: "Save", icon: nil, theme: theme, spacing: 10, imageSize: imageSize)
        self.saveNode.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.nameAgency.textField.delegate = self
        self.websiteField.textField.delegate = self
        self.chooseCountryField.textField.delegate = self
        self.chooseGenderField.textField.delegate = self
        self.chooseAgencyField.textField.delegate = self
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tapGesture)
        
        self.addSubnode(self.sectionTitleNode)
        
        self.addSubnode(self.websiteField)
        self.addSubnode(self.chooseCountryField)
        
        if self.typeOfRole != .agencies {
            self.addSubnode(self.ageSliderNode)
        }
        self.addSubnode(self.chooseGenderField)
        self.addSubnode(self.chooseAgencyField)
        self.addSubnode(self.nameAgency)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.addPhotoButton)
        
        self.addSubnode(self.backNode)
        self.addSubnode(self.saveNode)
        
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
        self.backNode.addTarget(self, action: #selector(self.backButtonPressed), forControlEvents: .touchUpInside)
        
        self.saveNode.addTarget(self, action: #selector(self.saveButtonPressed), forControlEvents: .touchUpInside)
    }
    
    func updateData(firstName: String, lastName: String, hasTermsOfService: Bool) {
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func updateCountry(countryId: String, countryName: String) {
        chooseCountryField.textField.text = countryName
        self.countryId = countryId
//        if let (layout, navigationHeight) = self.layoutArguments {
//            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
//        }
        
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
        
        let additionalBottomInset: CGFloat = layout.size.width > 320.0 ? 90.0 : 10.0
        
        let fieldHeight: CGFloat = 40.0
        
        let sideInset: CGFloat = 24.0
        
        let noticeSize = self.currentOptionNode.measure(CGSize(width: maximumWidth - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let sectionTitleSize = self.sectionTitleNode.measure(CGSize(width: maximumWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let avatarSize: CGSize = CGSize(width: 100.0, height: 100.0)
        var items: [AuthorizationLayoutItem] = []
        
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10, maxValue: 10), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 20.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.addPhotoButton, size: avatarSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        self.currentPhotoNode.frame = CGRect(origin: CGPoint(), size: avatarSize)
        
        items.append(AuthorizationLayoutItem(node: self.sectionTitleNode, size: CGSize(width: maximumWidth - sideInset * 2.0, height: sectionTitleSize.height), spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 20.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0, maxValue: 0)))
        
        
        if typeOfRole == .agencies {
            items.append(AuthorizationLayoutItem(node: self.nameAgency, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.chooseCountryField, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 12, maxValue: 12), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            
            items.append(AuthorizationLayoutItem(node: self.websiteField, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        }
        
        if typeOfRole == .talent {
            items.append(AuthorizationLayoutItem(node: self.nameAgency, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.chooseGenderField, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 12, maxValue: 12), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            
            items.append(AuthorizationLayoutItem(node: self.chooseCountryField, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            
            let ageSliderHeight: CGFloat = 60.0
            
            items.append(AuthorizationLayoutItem(node: self.ageSliderNode, size: CGSize(width: maximumWidth, height: ageSliderHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 20.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        }
        
        if typeOfRole == .model {
            items.append(AuthorizationLayoutItem(node: self.nameAgency, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.chooseGenderField, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 12, maxValue: 12), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            
            items.append(AuthorizationLayoutItem(node: self.chooseCountryField, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.chooseAgencyField, size: CGSize(width: maximumWidth - sideInset * 2.0, height: fieldHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 16.0, maxValue: 16.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            
            let ageSliderHeight: CGFloat = 60.0
            
            items.append(AuthorizationLayoutItem(node: self.ageSliderNode, size: CGSize(width: maximumWidth, height: ageSliderHeight), spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 20.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        }
        
        let buttonWidth = (maximumWidth - 48.0 - 10.0) / 2.0
        let buttonHeight: CGFloat = 50.0
        let bottomInset: CGFloat = 24.0
        
        let saveButtonFrame = CGRect(
            x: floorToScreenPixels((layout.size.width - maximumWidth + 48.0) / 2.0) + buttonWidth + 10.0,
            y: layout.size.height - insets.bottom - buttonHeight - bottomInset,
            width: buttonWidth,
            height: buttonHeight
        )
        transition.updateFrame(node: self.saveNode, frame: saveButtonFrame)
        
        let backButtonFrame = CGRect(
            x: floorToScreenPixels((layout.size.width - maximumWidth + 48.0) / 2.0),
            y: layout.size.height - insets.bottom - buttonHeight - bottomInset,
            width: buttonWidth,
            height: buttonHeight
        )
        transition.updateFrame(node: self.backNode, frame: backButtonFrame)
        
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
    
    @objc private func backButtonPressed() {
        back?()
    }
    
    @objc private func saveButtonPressed() {
        print("Save button pressed!")
        let typeId: Int32 = typeOfRole == .talent ? 1 : typeOfRole == .model ? 2 : 3
        let modelInfo = AuthorizationModelInfo(
            typeId: typeId,
            gender: 2,//chooseGenderField
            age: Int32(ageSliderNode.slider.value.rounded()),
            name: nameAgency.textField.text,
            agencyName: chooseAgencyField.textField.text,
            countryCode: countryId,
            url: websiteField.textField.text)
        signUpWithName?(modelInfo)
    }
    
    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.activeTextField = textField
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.activeTextField = nil
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == chooseCountryField.textField {
            selectCountryCode?()
            return false
        } else {
            return true
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let activeTextField = self.activeTextField else {
            return
        }
        
        let textFieldFrameInView = self.view.convert(activeTextField.bounds, from: activeTextField)
        let bottomOfTextField = textFieldFrameInView.maxY
        let keyboardTopY = self.view.frame.size.height - keyboardFrame.height
        
        let offset: CGFloat
        if bottomOfTextField > keyboardTopY {
            offset = bottomOfTextField - keyboardTopY + 20
        } else {
            offset = 0
        }
        
        if offset > 0 {
            UIView.animate(withDuration: animationDuration, animations: {
                self.view.transform = CGAffineTransform(translationX: 0, y: -offset)
            })
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: animationDuration, animations: {
            self.view.transform = .identity
        })
    }
}
