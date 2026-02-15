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

enum TimeType {
    case start
    case end
}

final class AddWorkExperience: ASDisplayNode, UITextFieldDelegate {
    
    private let context: AccountContext
    private let createWorkExperienceDisposable = MetaDisposable()
    private var startTime: Int32 = 0
    private var endTime: Int32 = 0
    
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
    
    private let startDateLabel: ASTextNode
    private let startDateTextField: TextFieldNode
    
    private let endTimeLabel: ASTextNode
    private let endTimeTextField: TextFieldNode
    
    private let currentlyWorkingContainer: ASDisplayNode
    private let currentlyWorkingCheckbox: CheckboxNode
    private let currentlyWorkingLabel: ASTextNode
    
    private let applyButton: ASControlNode
    private let addPhoto: () -> Void
    
    var scheduleTimeController: ((TimeType) -> Void)?
    var showAlert: ((String) -> Void)?
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
        self.eventInfoLabel.attributedText = NSAttributedString(string: "Work experience info", font: semiboldFont, textColor: headerColor)
        
        self.nameEventLabel = ASTextNode()
        self.nameEventLabel.attributedText = NSAttributedString(string: "Agency name", font: regularFont, textColor: labelColor)
        
        self.nameEventTextField = getTextFiel(title: "Enter agency name")

        self.startDateLabel = ASTextNode()
        self.startDateLabel.attributedText = NSAttributedString(string: "Start date", font: regularFont, textColor: labelColor)
        self.startDateTextField = getTextFiel(title: "27 Jun 2025")
        
        self.endTimeLabel = ASTextNode()
        self.endTimeLabel.attributedText = NSAttributedString(string: "End date", font: regularFont, textColor: labelColor)
        self.endTimeTextField = getTextFiel(title: "27 Jun 2025")

        self.currentlyWorkingContainer = ASDisplayNode()
        self.currentlyWorkingContainer.isUserInteractionEnabled = true

        self.currentlyWorkingCheckbox = CheckboxNode(size: CGSize(width: 20, height: 20))

        self.currentlyWorkingLabel = ASTextNode()
        self.currentlyWorkingLabel.attributedText = NSAttributedString(
            string: "I am currently working in this role",
            font: semiboldFont,
            textColor: labelColor
        )
        self.currentlyWorkingLabel.isUserInteractionEnabled = false

        self.currentlyWorkingContainer.addSubnode(self.currentlyWorkingCheckbox)
        self.currentlyWorkingContainer.addSubnode(self.currentlyWorkingLabel)
        
        self.applyButton = ButtonWithIconNode(title: "Create New Work Experience", icon: nil, theme: presentationData.theme, spacing: 10, imageSize: CGSize(width: 24, height: 24))
        self.applyButton.backgroundColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        super.init()
        self.startDateTextField.textField.delegate = self
        self.endTimeTextField.textField.delegate = self
        
        self.backgroundColor = .white
        self.addSubnode(self.scrollNode)
        self.addPhotoButton.addSubnode(self.currentPhotoNode)
        self.scrollNode.addSubnode(self.addPhotoButton)
        self.scrollNode.addSubnode(self.eventInfoLabel)
        
        self.scrollNode.addSubnode(self.nameEventLabel)
        self.scrollNode.addSubnode(self.nameEventTextField)
        
        self.scrollNode.addSubnode(self.startDateLabel)
        self.scrollNode.addSubnode(self.startDateTextField)
        
        self.scrollNode.addSubnode(self.endTimeLabel)
        self.scrollNode.addSubnode(self.endTimeTextField)
        
        self.scrollNode.addSubnode(self.currentlyWorkingContainer)
        
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
        self.createWorkExperienceDisposable.dispose()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.applyButton.addTarget(self, action: #selector(self.applyButtonTapped), forControlEvents: .touchUpInside)
        self.addPhotoButton.addTarget(self, action: #selector(self.addPhotoPressed), forControlEvents: .touchUpInside)
        let checkboxTapGesture = UITapGestureRecognizer(target: self, action: #selector(currentlyWorkingTapped))
        self.currentlyWorkingContainer.view.addGestureRecognizer(checkboxTapGesture)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == startDateTextField.textField  {
            scheduleTimeController?(.start)
            return false
        } else if textField == endTimeTextField.textField {
            scheduleTimeController?(.end)
            return false
        }
        return true
    }
    
    @objc private func addPhotoPressed() {
        self.addPhoto()
    }
    @objc private func applyButtonTapped() {
        print("applyButton Tapped!")
        
        let agencyName = nameEventTextField.textField.text ?? ""
        
        guard startTime > 0 else {
            self.showAlert?("Please fill in the start date")
            return
        }
        
        if let currentPhoto = currentPhoto {
            let _ = uploadPhotoToCloud(context: context, image: currentPhoto).start(next: { [weak self] id in
                if let id = id {
                    self?.createWorkExperience(agencyName: agencyName, photoId: id)
                }
            })
        } else {
            createWorkExperience(agencyName: agencyName)
        }
    }
    
    private func createWorkExperience(agencyName: String, photoId: Int64? = nil) {
        let startTimestamp = TimeInterval(startTime)
        let endTimestamp = TimeInterval(endTime)
        
        let supportPeer = Promise<String?>()
        supportPeer.set(context.engine.profileEngine.createWorkExperience(
            agencyName: agencyName,
            startDate: Int32(startTimestamp),
            endDate: endTimestamp > 0 ? Int32(endTimestamp) : nil,
            photoId: photoId
        ))
        self.createWorkExperienceDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { peerId in
            print("🔕 createWorkExperienceDisposable", peerId ?? "")
            self.showAlert?("WorkExperience Added")
        }))
    }
    
    private func uploadPhotoToCloud(context: AccountContext, image: UIImage) -> Signal<Int64?, NoError> {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            return .single(nil)
        }
        
        return context.engine.engineDivo.uploadedPhoto(resource: data)
    }

    @objc private func currentlyWorkingTapped() {
        self.currentlyWorkingCheckbox.isSelected.toggle()
        endTimeLabel.isHidden = currentlyWorkingCheckbox.isSelected
        endTimeTextField.isHidden = currentlyWorkingCheckbox.isSelected
    }
    
    func updateTime(_ timestamp: Int32, type: TimeType) {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "d MMM yyyy"
        let dateString = dateFormatter.string(from: date)
        dateFormatter.dateFormat = "d MMM yyyy"
        let timeString = dateFormatter.string(from: date)
        
        switch type {
        case .start:
            startTime = timestamp
            startDateTextField.textField.text = dateString
        case .end:
            endTime = timestamp
            endTimeTextField.textField.text = timeString
        }
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
        
        let dateWidth: CGFloat = floor((layout.size.width - sidePadding * 3) / 2.0)
        
        let startDateLabelSize = self.startDateLabel.measure(CGSize(width: dateWidth, height: .greatestFiniteMagnitude))
        self.startDateLabel.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: startDateLabelSize)
        
        let endTimeLabelSize = self.endTimeLabel.measure(CGSize(width: dateWidth, height: .greatestFiniteMagnitude))
        self.endTimeLabel.frame = CGRect(origin: CGPoint(x: sidePadding * 2 + dateWidth, y: currentY), size: endTimeLabelSize)
        currentY += startDateLabelSize.height + halfItemSpacing
        
        self.startDateTextField.frame = CGRect(origin: CGPoint(x: sidePadding, y: currentY), size: CGSize(width: dateWidth, height: itemHeight))
        self.endTimeTextField.frame = CGRect(origin: CGPoint(x: sidePadding * 2 + dateWidth, y: currentY), size: CGSize(width: dateWidth, height: itemHeight))
        currentY += itemHeight + sectionSpacing
        
        let rowHeight: CGFloat = 24.0

        self.currentlyWorkingContainer.frame = CGRect(
            origin: CGPoint(x: sidePadding, y: currentY),
            size: CGSize(width: layout.size.width - sidePadding * 2, height: rowHeight)
        )

        self.currentlyWorkingCheckbox.frame = CGRect(
            origin: CGPoint(x: 0, y: (rowHeight - 20) / 2),
            size: CGSize(width: 20, height: 20)
        )

        let labelSize = self.currentlyWorkingLabel.measure(
            CGSize(width: layout.size.width - sidePadding * 2 - 32, height: rowHeight)
        )
        self.currentlyWorkingLabel.frame = CGRect(
            origin: CGPoint(x: 32, y: 0),
            size: labelSize
        )

        currentY += rowHeight + sectionSpacing
        
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
