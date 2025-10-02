import Display
import UIKit
import AsyncDisplayKit
import UIKit
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

final class CreateEventNode: ASDisplayNode, UITextFieldDelegate {
    
    private let context: AccountContext
    
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
    
    private var disposable: Disposable?
    
    private let scrollNode: ASScrollNode
    
    private let currentPhotoNode: ASImageNode
    private let addPhotoButton: HighlightableButtonNode
    
    private let eventInfoLabel: ASTextNode
    
    private let nameEventLabel: ASTextNode
    private let nameEventTextField: TextFieldNode
    
    private let aboutEventLabel: ASTextNode
    private let aboutEventTextField: TextFieldNode
    
    private let eventTypeLabel: ASTextNode
    private let eventTypeTextField: TextFieldNode
    
    private let eventDateLabel: ASTextNode
    private let eventDateTextField: TextFieldNode
    
    private let eventTimeLabel: ASTextNode
    private let eventTimeTextField: TextFieldNode
    
    private let venueEventLabel: ASTextNode
    private let venueEventTextField: TextFieldNode
    
    private let parametersApplyingLabel: ASTextNode
    private let addParametersButton: ASControlNode
    
    private let applyButton: ASControlNode
    private let addPhoto: () -> Void
    var selectCountryCode: (() -> Void)?
    var scheduleTimeController: (() -> Void)?
    private var countryId: String = ""
    
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
    
    init(context: AccountContext, addPhoto: @escaping () -> Void) {
        self.context = context
        self.addPhoto = addPhoto
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.presentationDataPromise = Promise(self.presentationData)
        
        self.scrollNode = ASScrollNode()
        
        let iconColor = UIColor(red: 0.75, green: 0.48, blue: 0.33, alpha: 1.00)
        
        self.addPhotoButton = HighlightableButtonNode()
        self.addPhotoButton.setImage(
            generateTintedImage(
                image: UIImage(bundleImageName: "Avatar/AddAvatarIconLarge"),
                color: iconColor),
            for: .normal)
        
        let buttonDiameter: CGFloat = 110.0
        
        self.addPhotoButton.setBackgroundImage(
            generateFilledCircleImage(diameter: buttonDiameter,
                                      color: .white,
                                      strokeColor: iconColor,
                                      strokeWidth: 1,
                                      backgroundColor: nil),
            for: .normal
        )
        
        self.addPhotoButton.allowsGroupOpacity = true
        
        self.currentPhotoNode = ASImageNode()
        self.currentPhotoNode.isUserInteractionEnabled = false
        self.currentPhotoNode.displaysAsynchronously = false
        self.currentPhotoNode.displayWithoutProcessing = true
        
        let headerColor = UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.00)
        let labelColor = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1.00)
        let regularFont = Font.regular(16)
        let semiboldFont = Font.semibold(16)
        
        self.eventInfoLabel = ASTextNode()
        self.eventInfoLabel.attributedText = NSAttributedString(string: "Event info", font: semiboldFont, textColor: headerColor)
        
        self.nameEventLabel = ASTextNode()
        self.nameEventLabel.attributedText = NSAttributedString(string: "Name event", font: regularFont, textColor: labelColor)
        
        self.nameEventTextField = getTextFiel(title: "Enter name event")
        
        self.aboutEventLabel = ASTextNode()
        self.aboutEventLabel.attributedText = NSAttributedString(string: "About event", font: regularFont, textColor: labelColor)
        
        self.aboutEventTextField = getTextFiel(title: "Description event", isMultiline: true)
        
        self.eventTypeLabel = ASTextNode()
        self.eventTypeLabel.attributedText = NSAttributedString(string: "Event type", font: regularFont, textColor: labelColor)
        self.eventTypeTextField = getTextFiel(title: "Choose event type")
        
        self.eventDateLabel = ASTextNode()
        self.eventDateLabel.attributedText = NSAttributedString(string: "Event Date", font: regularFont, textColor: labelColor)
        self.eventDateTextField = getTextFiel(title: "27 Jun 2025")
        
        self.eventTimeLabel = ASTextNode()
        self.eventTimeLabel.attributedText = NSAttributedString(string: "Event Time", font: regularFont, textColor: labelColor)
        self.eventTimeTextField = getTextFiel(title: "00:00")
        
        self.venueEventLabel = ASTextNode()
        self.venueEventLabel.attributedText = NSAttributedString(string: "Venue of the event", font: regularFont, textColor: labelColor)
        self.venueEventTextField = getTextFiel(title: "Choose a country")
        
        self.parametersApplyingLabel = ASTextNode()
        self.parametersApplyingLabel.attributedText = NSAttributedString(string: "Parameters for Applying", font: semiboldFont, textColor: headerColor)
        
        self.addParametersButton = ButtonWithIconNode(title: "+ Add parameters", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.addParametersButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        self.applyButton = ButtonWithIconNode(title: "Create Event", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        self.venueEventTextField.textField.delegate = self
        self.eventDateTextField.textField.delegate = self
        self.eventTimeTextField.textField.delegate = self
        
        self.backgroundColor = .white
        self.addSubnode(self.scrollNode)
        self.addPhotoButton.addSubnode(self.currentPhotoNode)
        self.scrollNode.addSubnode(self.addPhotoButton)
        self.scrollNode.addSubnode(self.eventInfoLabel)
        
        self.scrollNode.addSubnode(self.nameEventLabel)
        self.scrollNode.addSubnode(self.nameEventTextField)
        
        self.scrollNode.addSubnode(self.aboutEventLabel)
        self.scrollNode.addSubnode(self.aboutEventTextField)
        
        self.scrollNode.addSubnode(self.eventTypeLabel)
        self.scrollNode.addSubnode(self.eventTypeTextField)
        
        self.scrollNode.addSubnode(self.eventDateLabel)
        self.scrollNode.addSubnode(self.eventDateTextField)
        
        self.scrollNode.addSubnode(self.eventTimeLabel)
        self.scrollNode.addSubnode(self.eventTimeTextField)
        
        self.scrollNode.addSubnode(self.venueEventLabel)
        self.scrollNode.addSubnode(self.venueEventTextField)
        
        self.scrollNode.addSubnode(self.parametersApplyingLabel)
        self.scrollNode.addSubnode(self.addParametersButton)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        self.scrollNode.view.addGestureRecognizer(tapGesture)
        
        self.scrollNode.addSubnode(self.applyButton)
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(presentationData))
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        }).strict()
    }
    
    deinit {
        self.disposable?.dispose()
        self.presentationDataDisposable?.dispose()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.applyButton.addTarget(self, action: #selector(self.applyButtonTapped), forControlEvents: .touchUpInside)
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
        self.addParametersButton.addTarget(self, action: #selector(self.addParametersTapped), forControlEvents: .touchUpInside)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == eventDateTextField.textField || textField == eventTimeTextField.textField {
            scheduleTimeController?()
            return false
        }
        if textField == venueEventTextField.textField {
            selectCountryCode?()
            return false
        }
        return true
    }
    
    @objc private func addPhotoPressed() {
        self.addPhoto()
    }
    @objc private func applyButtonTapped() {
        print("applyButton Tapped!")
    }
    
    @objc private func addParametersTapped() {
        print("Add Parameters Tapped!")
    }
    
    func updateCountry(countryId: String, countryName: String) {
        venueEventTextField.textField.text = countryName
        self.countryId = countryId
    }
    
    func updateTime(_ timestamp: Int32) {
        
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "d MMM yyyy"
        let dateString = dateFormatter.string(from: date)
        dateFormatter.dateFormat = "HH:mm"
        let timeString = dateFormatter.string(from: date)
        
        eventDateTextField.textField.text = dateString
        eventTimeTextField.textField.text = timeString
    }
    
    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
    }
    
    @objc private func dismissKeyboard() {
        self.view.endEditing(true)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber else {
            return
        }

        let keyboardHeight = keyboardFrame.cgRectValue.height

        var currentInsets = self.scrollNode.view.contentInset
        
        currentInsets.bottom = keyboardHeight
        
        UIView.animate(withDuration: duration.doubleValue, delay: 0.0, options: UIView.AnimationOptions(rawValue: curve.uintValue << 16), animations: {
            self.scrollNode.view.contentInset = currentInsets
            self.scrollNode.view.scrollIndicatorInsets = currentInsets
        }, completion: nil)
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber else {
            return
        }

        var currentInsets = self.scrollNode.view.contentInset
        currentInsets.bottom = 0
        
        UIView.animate(withDuration: duration.doubleValue, delay: 0.0, options: UIView.AnimationOptions(rawValue: curve.uintValue << 16), animations: {
            self.scrollNode.view.contentInset = currentInsets
            self.scrollNode.view.scrollIndicatorInsets = currentInsets
        }, completion: nil)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
        let avatarSize: CGSize = CGSize(width: 100.0, height: 100.0)
        
        let avatarX: CGFloat = floor((layout.size.width - avatarSize.width) / 2.0)
        self.addPhotoButton.frame = CGRect(origin: CGPoint(x: avatarX, y: 20), size: avatarSize)
        self.currentPhotoNode.frame = CGRect(origin: CGPoint(), size: avatarSize)
        
        let topInset: CGFloat = navigationBarHeight
        
        let sidePadding: CGFloat = 16.0
        let sectionSpacing: CGFloat = 24.0
        let itemSpacing: CGFloat = 12.0
        let itemHeight: CGFloat = 48.0
        let halfItemSpacing: CGFloat = 6.0
        
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset))
        
        var currentY: CGFloat = 140.0
        
        let eventInfoBySize = self.eventInfoLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.eventInfoLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: eventInfoBySize)
        currentY += eventInfoBySize.height + sectionSpacing
        
        let nameEventLabelSize = self.nameEventLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.nameEventLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: nameEventLabelSize)
        currentY += nameEventLabelSize.height + halfItemSpacing
        
        self.nameEventTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        let aboutEventLabelSize = self.aboutEventLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.aboutEventLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: aboutEventLabelSize)
        currentY += aboutEventLabelSize.height + halfItemSpacing
        
        let aboutEventHeight: CGFloat = 100.0
        self.aboutEventTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: aboutEventHeight))
        currentY += aboutEventHeight + sectionSpacing
        
        let eventTypeLabelSize = self.eventTypeLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.eventTypeLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: eventTypeLabelSize)
        currentY += eventTypeLabelSize.height + halfItemSpacing
        
        self.eventTypeTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        let dateWidth: CGFloat = floor((layout.size.width - sidePadding * 3) / 2.0)
        
        let eventDateLabelSize = self.eventDateLabel.measure(CGSize(width: dateWidth, height: .greatestFiniteMagnitude))
        self.eventDateLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: eventDateLabelSize)
        
        let eventTimeLabelSize = self.eventTimeLabel.measure(CGSize(width: dateWidth, height: .greatestFiniteMagnitude))
        self.eventTimeLabel.frame = CGRect(origin: CGPoint(x: sidePadding * 2 + dateWidth, y: currentY), size: eventTimeLabelSize)
        currentY += eventDateLabelSize.height + halfItemSpacing
        
        self.eventDateTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: dateWidth, height: itemHeight))
        self.eventTimeTextField.frame = CGRect(origin: CGPoint(x: sidePadding * 2 + dateWidth, y: currentY), size: CGSize(width: dateWidth, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        let venueEventLabelSize = self.venueEventLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.venueEventLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: venueEventLabelSize)
        currentY += venueEventLabelSize.height + halfItemSpacing
        
        self.venueEventTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: layout.size.width - sidePadding * 2, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        let parametersApplyingLabelSize = self.parametersApplyingLabel.measure(CGSize(width: layout.size.width - sidePadding * 2, height: .greatestFiniteMagnitude))
        self.parametersApplyingLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: parametersApplyingLabelSize)
        currentY += parametersApplyingLabelSize.height + itemSpacing
        
        let addParamsButtonWidth: CGFloat = 150.0
        let addParamsButtonHeight: CGFloat = 35.0
        
        self.addParametersButton.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: addParamsButtonWidth, height: addParamsButtonHeight))
        currentY += addParamsButtonHeight + sectionSpacing
        
        let buttonWidth = layout.size.width - sidePadding * 2
        let buttonHeight: CGFloat = 50.0
        
        self.applyButton.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: buttonWidth, height: buttonHeight))
        
        currentY += buttonHeight + sectionSpacing
        
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY + 20.0)
        
        self.readyValue = true
    }
}

private func getTextFiel(title: String, isMultiline: Bool = false) -> TextFieldNode {
    let field = TextFieldNode()
    
    field.textField.font = Font.regular(16.0)
    field.textField.textColor = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1.0)
    field.textField.textAlignment = .natural
    field.textField.attributedPlaceholder = NSAttributedString(string: title, font: field.textField.font, textColor: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6))
    field.textField.autocapitalizationType = .none
    field.textField.autocorrectionType = .no
    field.textField.keyboardType = .default
    field.borderWidth = 1.0
    field.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
    field.cornerRadius = 11.0
    field.clipsToBounds = true
    field.backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1.00)
    
    if isMultiline {
        field.padding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    } else {
        field.padding = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
    
    return field
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
