import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import AuthenticationServices
import CodeInputView
import PhoneNumberFormat
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SolidRoundedButtonNode
import AuthorizationUtils
import TelegramStringFormatting
import TextNodeWithEntities

final class AuthorizationSequenceCodeEntryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
//    private let animationNode: AnimatedStickerNode
    private let titleNode: ImmediateTextNode
    private let titleActivateAreaNode: AccessibilityAreaNode
    private let titleIconNode: ASImageNode
    private let currentOptionNode: ImmediateTextNodeWithEntities
    private let currentOptionActivateAreaNode: AccessibilityAreaNode
    
    private let currentOptionInfoNode: ASTextNode
    private let currentOptionInfoActivateAreaNode: AccessibilityAreaNode
    private let nextOptionTitleNode: ImmediateTextNode
    private let nextOptionButtonNode: HighlightableButtonNode
    private let nextOptionArrowNode: ASImageNode
    
    private let resetTextNode: ImmediateTextNode
    private let resetNode: HighlightableButtonNode
    
    private let dividerNode: AuthorizationDividerNode
    private var signInWithAppleButton: UIControl?
    private let proceedNode: SolidRoundedButtonNode
    
    private let textField: TextFieldNode
    private let textSeparatorNode: ASDisplayNode
    private let pasteButton: HighlightableButtonNode
    
    private let codeInputView: CodeInputView
    private let errorTextNode: ImmediateTextNode
    
    private let hintButtonNode: HighlightTrackingButtonNode
    private let hintTextNode: ImmediateTextNode
    private let hintArrowNode: ASImageNode
    
    private var codeType: SentAuthorizationCodeType?
    
    private let countdownDisposable = MetaDisposable()
    private var currentTimeoutTime: Int32?
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    private var appleSignInAllowed = false
    
    private var previousCodeType: SentAuthorizationCodeType?
    private var isPrevious = false
    
    var phoneNumber: String = "" {
        didSet {
            if self.phoneNumber != oldValue {
                if let (layout, navigationHeight) = self.layoutArguments {
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                }
            }
        }
    }
    
    var email: String?
    
    var currentCode: String {
        switch self.codeType {
        case .word, .phrase:
            return self.textField.textField.text ?? ""
        default:
            return self.codeInputView.text
        }
    }
    
    var loginWithCode: ((String) -> Void)?
    var signInWithApple: (() -> Void)?
    var openFragment: ((String) -> Void)?
    var present: (ViewController, Any?) -> Void = { _, _ in }
    
    var requestNextOption: (() -> Void)?
    var requestAnotherOption: (() -> Void)?
    var requestPreviousOption: (() -> Void)?
    var updateNextEnabled: ((Bool) -> Void)?
    var reset: (() -> Void)?
    var retryReset: (() -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.codeInputView.alpha = self.inProgress ? 0.6 : 1.0
            
            switch self.codeType {
            case .word, .phrase:
                if self.inProgress != oldValue {
                    if self.inProgress {
                        self.proceedNode.transitionToProgress()
                    } else {
                        self.proceedNode.transitionFromProgress()
                    }
                }
            default:
                break
            }
        }
    }
    
    private let appearanceTimestamp = CACurrentMediaTime()
        
    init(strings: PresentationStrings, theme: PresentationTheme) {
        self.strings = strings
        self.theme = theme
        
//        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.titleActivateAreaNode = AccessibilityAreaNode()
        self.titleActivateAreaNode.accessibilityTraits = .staticText
        
        self.titleIconNode = ASImageNode()
        self.titleIconNode.isLayerBacked = true
        self.titleIconNode.displayWithoutProcessing = true
        self.titleIconNode.displaysAsynchronously = false
        
        self.currentOptionNode = ImmediateTextNodeWithEntities()
        self.currentOptionNode.balancedTextLayout = true
        self.currentOptionNode.isUserInteractionEnabled = false
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.lineSpacing = 0.1
        self.currentOptionNode.maximumNumberOfLines = 0
        self.currentOptionNode.spoilerColor = self.theme.list.itemSecondaryTextColor
        
        self.currentOptionActivateAreaNode = AccessibilityAreaNode()
        self.currentOptionActivateAreaNode.accessibilityTraits = .staticText
        
        self.currentOptionInfoNode = ASTextNode()
        self.currentOptionInfoNode.isUserInteractionEnabled = false
        self.currentOptionInfoNode.displaysAsynchronously = false
        
        self.currentOptionInfoActivateAreaNode = AccessibilityAreaNode()
        self.currentOptionInfoActivateAreaNode.accessibilityTraits = .staticText
        
        self.nextOptionTitleNode = ImmediateTextNode()
        
        self.nextOptionButtonNode = HighlightableButtonNode()
        self.nextOptionButtonNode.displaysAsynchronously = false
        let (nextOptionText, nextOptionActive) = authorizationNextOptionText(currentType: .sms(length: 5), nextType: .call, timeout: 60, strings: self.strings, primaryColor: .white, accentColor: .white)
        self.nextOptionTitleNode.attributedText = nextOptionText
        self.nextOptionButtonNode.isUserInteractionEnabled = nextOptionActive
        self.nextOptionButtonNode.accessibilityLabel = nextOptionText.string
        if nextOptionActive {
            self.nextOptionButtonNode.accessibilityTraits = [.button]
        } else {
            self.nextOptionButtonNode.accessibilityTraits = [.button, .notEnabled]
        }
        self.nextOptionButtonNode.addSubnode(self.nextOptionTitleNode)
        
        self.nextOptionArrowNode = ASImageNode()
        self.nextOptionArrowNode.displaysAsynchronously = false
        self.nextOptionArrowNode.isUserInteractionEnabled = false
        
        self.codeInputView = CodeInputView()
        self.codeInputView.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.codeInputView.textField.returnKeyType = .done
        self.codeInputView.textField.disableAutomaticKeyboardHandling = [.forward, .backward]
        if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
            self.codeInputView.textField.textContentType = .oneTimeCode
        }
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.codeInputView.textField.keyboardType = .asciiCapableNumberPad
        } else {
            self.codeInputView.textField.keyboardType = .numberPad
        }
        
        self.textSeparatorNode = ASDisplayNode()
        self.textSeparatorNode.isLayerBacked = true
        self.textSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.textField = TextFieldNode()
        self.textField.textField.font = Font.regular(20.0)
        self.textField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.textField.textField.textAlignment = .natural
        self.textField.textField.autocorrectionType = .yes
        self.textField.textField.autocorrectionType = .no
        self.textField.textField.spellCheckingType = .yes
        self.textField.textField.spellCheckingType = .no
        self.textField.textField.autocapitalizationType = .none
        self.textField.textField.keyboardType = .default
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.textField.textField.textContentType = UITextContentType(rawValue: "")
        }
        self.textField.textField.returnKeyType = .done
        self.textField.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.textField.textField.disableAutomaticKeyboardHandling = [.forward, .backward]
        self.textField.textField.tintColor = self.theme.list.itemAccentColor
        
        self.pasteButton = HighlightableButtonNode()
        
        self.errorTextNode = ImmediateTextNode()
        self.errorTextNode.alpha = 0.0
        self.errorTextNode.displaysAsynchronously = false
        self.errorTextNode.textAlignment = .center
        self.errorTextNode.isUserInteractionEnabled = false
        
        self.hintButtonNode = HighlightableButtonNode()
        self.hintButtonNode.alpha = 0.0
        self.hintButtonNode.isUserInteractionEnabled = false
        
        self.hintTextNode = ImmediateTextNode()
        self.hintTextNode.displaysAsynchronously = false
        self.hintTextNode.textAlignment = .center
        self.hintTextNode.isUserInteractionEnabled = false
        
        self.hintArrowNode = ASImageNode()
        self.hintArrowNode.displaysAsynchronously = false
        
        self.resetNode = HighlightableButtonNode()
        self.resetNode.displaysAsynchronously = false
        self.resetNode.setAttributedTitle(NSAttributedString(string: self.strings.Login_Email_CantAccess, font: Font.regular(17.0), textColor: self.theme.list.itemAccentColor, paragraphAlignment: .center), for: [])
        self.resetNode.isHidden = true
        
        self.resetTextNode = ImmediateTextNode()
        self.resetTextNode.maximumNumberOfLines = 1
        self.resetTextNode.textAlignment = .center
        self.resetTextNode.isUserInteractionEnabled = false
        self.resetTextNode.displaysAsynchronously = false
        self.resetTextNode.isHidden = true
        
        self.dividerNode = AuthorizationDividerNode(theme: self.theme, strings: self.strings)
        
        if #available(iOS 13.0, *) {
            self.signInWithAppleButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: theme.overallDarkAppearance ? .white : .black)
            self.signInWithAppleButton?.isHidden = true
            (self.signInWithAppleButton as? ASAuthorizationAppleIDButton)?.cornerRadius = 11
        }
        self.proceedNode = SolidRoundedButtonNode(title: self.strings.Login_Continue, theme: SolidRoundedButtonTheme(theme: self.theme), height: 50.0, cornerRadius: 11.0, gloss: false)
        self.proceedNode.progressType = .embedded
        self.proceedNode.isHidden = true
        self.proceedNode.iconSpacing = 4.0
        self.proceedNode.animationSize = CGSize(width: 36.0, height: 36.0)
        self.proceedNode.isEnabled = false
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.00)
        
        self.textField.textField.delegate = self
        
        self.addSubnode(self.codeInputView)
        self.addSubnode(self.textSeparatorNode)
        self.addSubnode(self.textField)
        self.addSubnode(self.pasteButton)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.titleActivateAreaNode)
        self.addSubnode(self.titleIconNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.currentOptionActivateAreaNode)
        self.addSubnode(self.currentOptionInfoNode)
        self.addSubnode(self.nextOptionButtonNode)
        self.nextOptionButtonNode.addSubnode(self.nextOptionArrowNode)
//        self.addSubnode(self.animationNode)
        self.addSubnode(self.resetNode)
        self.addSubnode(self.resetTextNode)
        self.addSubnode(self.dividerNode)
        self.addSubnode(self.errorTextNode)
        self.addSubnode(self.hintButtonNode)
        self.hintButtonNode.addSubnode(self.hintTextNode)
        self.hintButtonNode.addSubnode(self.hintArrowNode)
        self.addSubnode(self.proceedNode)
        
        self.codeInputView.updated = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.codeChanged(text: strongSelf.codeInputView.text)
        }
        
        self.textField.textField.addTarget(self, action: #selector(self.textDidChange), for: .editingChanged)
        
        self.codeInputView.longPressed = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if let code = UIPasteboard.general.string, let codeLength = strongSelf.requiredCodeLength, code.count == Int(codeLength) {
                let code = normalizeArabicNumeralString(code, type: .western)
                guard code.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789").inverted) == nil else {
                    return
                }
                
                let controller = makeContextMenuController(actions: [ContextMenuAction(content: .text(title: strongSelf.strings.Common_Paste, accessibilityLabel: strongSelf.strings.Common_Paste), action: { [weak self] in
                    self?.updateCode(code)
                })])
                
                strongSelf.present(
                    controller,
                    ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                        if let strongSelf = self {
                            return (strongSelf, strongSelf.codeInputView.frame.offsetBy(dx: 0.0, dy: -8.0), strongSelf, strongSelf.bounds)
                        } else {
                            return nil
                        }
                    })
                )
            }
        }
        
        self.nextOptionButtonNode.addTarget(self, action: #selector(self.nextOptionNodePressed), forControlEvents: .touchUpInside)
        self.proceedNode.pressed = { [weak self] in
            self?.proceedPressed()
        }
        self.signInWithAppleButton?.addTarget(self, action: #selector(self.signInWithApplePressed), for: .touchUpInside)
        self.resetNode.addTarget(self, action: #selector(self.resetPressed), forControlEvents: .touchUpInside)
        
        self.pasteButton.setTitle(strings.Login_Paste, with: Font.medium(13.0), with: theme.list.itemAccentColor, for: .normal)
        self.pasteButton.setBackgroundImage(generateStretchableFilledCircleImage(radius: 12.0, color: theme.list.itemAccentColor.withAlphaComponent(0.1)), for: .normal)
        self.pasteButton.addTarget(self, action: #selector(self.pastePressed), forControlEvents: .touchUpInside)
        
        self.hintButtonNode.addTarget(self, action: #selector(self.previousOptionNodePressed), forControlEvents: .touchUpInside)
        
        self.hintArrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: theme.list.itemAccentColor)
        self.hintArrowNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        self.nextOptionArrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: theme.list.itemAccentColor)
        
        self.updatePasteVisibility()
    }
    
    deinit {
        self.countdownDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if let signInWithAppleButton = self.signInWithAppleButton {
            self.view.addSubview(signInWithAppleButton)
        }
    }
    
    @objc private func pastePressed() {
        if let text = UIPasteboard.general.string, !text.isEmpty {
            if checkValidity(text: text, isPaste: true) {
                self.textField.textField.text = text
                self.textDidChange()
            }
        }
    }
        
    func updatePasteVisibility() {
        let text = self.textField.textField.text ?? ""
        self.pasteButton.isHidden = !text.isEmpty
    }
    
    func updateCode(_ code: String) {
        self.codeInputView.text = code
        self.codeChanged(text: code)

        if let codeLength = self.requiredCodeLength, code.count == Int(codeLength) {
            self.loginWithCode?(code)
        }
    }
    
    var requiredCodeLength: Int32? {
        if let codeType = self.codeType {
            switch codeType {
            case let .call(length):
                return length
            case let .otherSession(length):
                return length
            case let .missedCall(_, length):
                return length
            case let .sms(length):
                return length
            case let .fragment(_, length):
                return length
            default:
                return nil
            }
        } else {
            return nil
        }
    }
    
    func resetCode() {
        self.codeInputView.text = ""
    }
    
    func updateData(number: String, email: String?, codeType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?, appleSignInAllowed: Bool, previousCodeType: SentAuthorizationCodeType?, isPrevious: Bool) {
        self.codeType = codeType
        self.phoneNumber = number.replacingOccurrences(of: " ", with: "\u{00A0}").replacingOccurrences(of: "-", with: "\u{2011}")
        self.email = email
        self.previousCodeType = previousCodeType
        self.isPrevious = isPrevious
        
        var appleSignInAllowed = appleSignInAllowed
        if #available(iOS 13.0, *) {
        } else {
            appleSignInAllowed = false
        }
        self.appleSignInAllowed = appleSignInAllowed
        
        self.currentOptionNode.attributedText = authorizationCurrentOptionText(codeType, phoneNumber: self.phoneNumber, email: self.email, strings: self.strings, primaryColor: .white, accentColor: self.theme.list.itemAccentColor)
        self.currentOptionActivateAreaNode.accessibilityLabel = self.currentOptionNode.attributedText?.string ?? ""
        if case .missedCall = codeType {
            self.currentOptionInfoNode.attributedText = NSAttributedString(string: self.strings.Login_CodePhonePatternInfoText, font: Font.regular(17.0), textColor: self.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
            self.currentOptionInfoActivateAreaNode.accessibilityLabel = self.currentOptionInfoNode.attributedText?.string ?? ""
            if self.currentOptionInfoActivateAreaNode.supernode == nil {
                self.addSubnode(self.currentOptionInfoActivateAreaNode)
            }
        } else {
            self.currentOptionInfoNode.attributedText = NSAttributedString(string: "", font: Font.regular(17.0), textColor: self.theme.list.itemPrimaryTextColor)
            if self.currentOptionInfoActivateAreaNode.supernode != nil {
                self.currentOptionInfoActivateAreaNode.removeFromSupernode()
            }
        }
                
        if let timeout = timeout {
            #if DEBUG
            let timeout = min(timeout, 5)
            #endif
            self.currentTimeoutTime = timeout
            let disposable = ((Signal<Int, NoError>.single(1) |> delay(1.0, queue: Queue.mainQueue())) |> restart).startStrict(next: { [weak self] _ in
                if let strongSelf = self {
                    if let currentTimeoutTime = strongSelf.currentTimeoutTime, currentTimeoutTime > 0 {
                        strongSelf.currentTimeoutTime = currentTimeoutTime - 1
                        let (nextOptionText, nextOptionActive) = authorizationNextOptionText(currentType: codeType, nextType: nextType, previousCodeType: isPrevious ? previousCodeType : nil, timeout: strongSelf.currentTimeoutTime, strings: strongSelf.strings, primaryColor: .white, accentColor: strongSelf.theme.list.itemAccentColor)
                        strongSelf.nextOptionTitleNode.attributedText = nextOptionText
                        strongSelf.nextOptionButtonNode.isUserInteractionEnabled = nextOptionActive
                        strongSelf.nextOptionButtonNode.accessibilityLabel = nextOptionText.string
                        if nextOptionActive {
                            strongSelf.nextOptionButtonNode.accessibilityTraits = [.button]
                        } else {
                            strongSelf.nextOptionButtonNode.accessibilityTraits = [.button, .notEnabled]
                        }
                        if let layoutArguments = strongSelf.layoutArguments {
                            strongSelf.containerLayoutUpdated(layoutArguments.0, navigationBarHeight: layoutArguments.1, transition: .immediate)
                        }
                        /*if currentTimeoutTime == 1 {
                            strongSelf.requestNextOption?()
                        }*/
                    }
                }
            })
            self.countdownDisposable.set(disposable)
        } else if case let .email(_, _, _, pendingDate, _, _) = codeType, let pendingDate {
            let disposable = ((Signal<Int, NoError>.single(1) |> delay(1.0, queue: Queue.mainQueue())) |> restart).startStrict(next: { [weak self] _ in
                if let strongSelf = self {
                    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                    let interval = pendingDate - currentTime
                    if interval <= 0 {
                        strongSelf.countdownDisposable.set(nil)
                        Queue.mainQueue().after(2.0) {
                            strongSelf.retryReset?()
                        }
                    }
                    if let layoutArguments = strongSelf.layoutArguments {
                        strongSelf.containerLayoutUpdated(layoutArguments.0, navigationBarHeight: layoutArguments.1, transition: .immediate)
                    }
                }
            })
            self.countdownDisposable.set(disposable)
        } else {
            self.currentTimeoutTime = nil
            self.countdownDisposable.set(nil)
        }
        
        let (nextOptionText, nextOptionActive) = authorizationNextOptionText(currentType: codeType, nextType: nextType, previousCodeType: isPrevious ? previousCodeType : nil, timeout: self.currentTimeoutTime, strings: self.strings, primaryColor: .white, accentColor: self.theme.list.itemAccentColor)
        self.nextOptionTitleNode.attributedText = nextOptionText
        self.nextOptionButtonNode.isUserInteractionEnabled = nextOptionActive
        self.nextOptionButtonNode.accessibilityLabel = nextOptionText.string
        if nextOptionActive {
            self.nextOptionButtonNode.accessibilityTraits = [.button]
        } else {
            self.nextOptionButtonNode.accessibilityTraits = [.button, .notEnabled]
        }
        
        self.nextOptionArrowNode.isHidden = previousCodeType == nil || !isPrevious
        
        if let layoutArguments = self.layoutArguments {
            self.containerLayoutUpdated(layoutArguments.0, navigationBarHeight: layoutArguments.1, transition: .immediate)
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
            let inset: CGFloat = 24.0
            
            var insets = layout.insets(options: [])
            insets.top = layout.statusBarHeight ?? 20.0
            
            let contentBottomInset: CGFloat = 20.0
            
            let contentBounds = CGRect(
                origin: CGPoint(x: 0.0, y: insets.top),
                size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - contentBottomInset)
            )
            
        if let codeType = self.codeType {
            switch codeType {
            case .missedCall:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterMissingDigits, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
            case .email:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeEmailTitle, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
                //                animationName = "IntroLetter"
            case .sms:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeSMSTitle.uppercased(), font: Font.semibold(28.0), textColor: .white)
            case .fragment:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeFragmentTitle, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
                
                self.proceedNode.title = self.strings.Login_OpenFragment
                self.proceedNode.updateTheme(SolidRoundedButtonTheme(backgroundColor: UIColor(rgb: 0x37475a), foregroundColor: .white))
                self.proceedNode.isEnabled = true
                
                //                animationName = "IntroFragment"
                //                animationPlaybackMode = .count(3)
                self.proceedNode.animation = "anim_fragment"
            case .word:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterWordTitle, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
//                textFieldPlaceholder = self.strings.Login_EnterWordPlaceholder
            case .phrase:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterPhraseTitle, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
//                textFieldPlaceholder = self.strings.Login_EnterPhrasePlaceholder
            default:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeTelegramTitle, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
            }
        } else {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeTelegramTitle, font: Font.semibold(40.0), textColor: self.theme.list.itemPrimaryTextColor)
        }
            self.titleActivateAreaNode.accessibilityLabel = self.titleNode.attributedText?.string ?? ""
            
            let titleSize = self.titleNode.updateLayout(CGSize(width: maximumWidth, height: .greatestFiniteMagnitude))
            
            let currentOptionSize = self.currentOptionNode.updateLayout(CGSize(width: maximumWidth - 48.0, height: .greatestFiniteMagnitude))
//            let currentOptionInfoSize = self.currentOptionInfoNode.measure(CGSize(width: maximumWidth - 48.0, height: .greatestFiniteMagnitude))
            let nextOptionSize = self.nextOptionTitleNode.updateLayout(CGSize(width: maximumWidth, height: .greatestFiniteMagnitude))
            
            let codeLength: Int
            var codePrefix: String = ""
            switch self.codeType {
            case .flashCall:
                codeLength = 6
            case let .call(length):
                codeLength = Int(length)
            case let .otherSession(length):
                codeLength = Int(length)
            case let .missedCall(prefix, length):
                if prefix.hasPrefix("+") {
                    codePrefix = prefix
                } else {
                    codePrefix = InteractivePhoneFormatter().updateText("+" + prefix).1
                }
                codeLength = Int(length)
            case let .sms(length):
                codeLength = Int(length)
            case let .email(_, length, _, _, _, _):
                codeLength = Int(length)
            case let .fragment(_, length):
                codeLength = Int(length)
            case let .firebase(_, length):
                codeLength = Int(length)
            case .emailSetupRequired:
                codeLength = 6
            case .word, .phrase:
                codeLength = 0
            case .none:
                codeLength = 6
            }
            
            let codeFieldSize = self.codeInputView.update(
                theme: CodeInputView.Theme(
                    inactiveBorder: self.theme.list.itemPlainSeparatorColor.argb,
                    activeBorder: UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.6).argb,
                    succeedBorder: self.theme.list.itemDisclosureActions.constructive.fillColor.argb,
                    failedBorder: self.theme.list.itemDestructiveColor.argb,
                    foreground: UIColor.white.argb,
                    isDark: self.theme.overallDarkAppearance
                ),
                prefix: codePrefix,
                count: codeLength,
                width: maximumWidth - 28.0,
                compact: layout.size.width <= 320.0 || (layout.size.width <= 375.0 && codeLength > 5)
            )
            
            var items: [AuthorizationLayoutItem] = []
        
            switch self.codeType {
            case .email:
                items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: currentOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
                items.append(AuthorizationLayoutItem(node: self.codeInputView, size: codeFieldSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 30.0, maxValue: 30.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
            default:
                self.titleIconNode.isHidden = true
                items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: currentOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
                items.append(AuthorizationLayoutItem(node: self.codeInputView, size: codeFieldSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 30.0, maxValue: 30.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
                items.append(AuthorizationLayoutItem(node: self.nextOptionButtonNode, size: nextOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 50.0, maxValue: 120.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            }

            let _ = layoutAuthorizationItems(bounds: contentBounds, items: items, transition: transition, failIfDoesNotFit: false)
            
            let proceedHeight = self.proceedNode.updateLayout(width: maximumWidth - inset * 2.0, transition: transition)
            let proceedSize = CGSize(width: maximumWidth - inset * 2.0, height: proceedHeight)
            let proceedFrame = CGRect(
                origin: CGPoint(x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0), y: layout.size.height - (layout.inputHeight ?? 0.0) - proceedSize.height - inset),
                size: proceedSize
            )
            transition.updateFrame(node: self.proceedNode, frame: proceedFrame)

            self.titleActivateAreaNode.frame = self.titleNode.frame
            self.currentOptionActivateAreaNode.frame = self.currentOptionNode.frame
            self.currentOptionInfoActivateAreaNode.frame = self.currentOptionInfoNode.frame
        }
    
    func activateInput() {
        switch self.codeType {
        case .word, .phrase:
            self.textField.textField.becomeFirstResponder()
        default:
            let _ = self.codeInputView.becomeFirstResponder()
        }
    }
    
    func animateError() {
        switch self.codeType {
        case .word, .phrase:
            self.textField.layer.addShakeAnimation()
        default:
            self.codeInputView.layer.addShakeAnimation()
        }
    }
    
    func selectIncorrectPart() {
        switch self.codeType {
        case .word:
            self.textField.textField.selectAll(nil)
        case let .phrase(startsWith):
            if let startsWith, let fromPosition = self.textField.textField.position(from: self.textField.textField.beginningOfDocument, offset: startsWith.count + 1) {
                self.textField.textField.selectedTextRange = self.textField.textField.textRange(from: fromPosition, to: self.textField.textField.endOfDocument)
            } else {
                self.textField.textField.selectAll(nil)
            }
        default:
            break
        }
    }
    
    func animateError(text: String) {
        let errorOriginY: CGFloat
        let errorOriginOffset: CGFloat
        switch self.codeType {
        case .word, .phrase:
            self.textField.layer.addShakeAnimation()
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)
            transition.updateBackgroundColor(node: self.textSeparatorNode, color: self.theme.list.itemDestructiveColor)
            errorOriginY = self.textField.frame.maxY
            errorOriginOffset = 5.0
        default:
            self.codeInputView.animateError()
            self.codeInputView.layer.addShakeAnimation(amplitude: -30.0, duration: 0.5, count: 6, decay: true)
            errorOriginY = self.codeInputView.frame.maxY
            errorOriginOffset = 11.0
        }
        
        self.errorTextNode.attributedText = NSAttributedString(string: text, font: Font.regular(13.0), textColor: self.theme.list.itemDestructiveColor, paragraphAlignment: .center)
        
        if let (layout, _) = self.layoutArguments {
            let errorTextSize = self.errorTextNode.updateLayout(CGSize(width: layout.size.width - 48.0, height: .greatestFiniteMagnitude))
            let yOffset: CGFloat = layout.size.width > 320.0 ? errorOriginOffset + 13.0 : errorOriginOffset
            self.errorTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - errorTextSize.width) / 2.0), y: errorOriginY + yOffset), size: errorTextSize)
        }
        self.errorTextNode.alpha = 1.0
        self.errorTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        
        let previousHintAlpha = self.hintButtonNode.alpha
        self.hintButtonNode.alpha = 0.0
        self.hintButtonNode.layer.animateAlpha(from: previousHintAlpha, to: 0.0, duration: 0.1)
        
        let previousResetAlpha = self.resetNode.alpha
        if !self.resetNode.isHidden {
            self.resetNode.alpha = 0.0
            self.resetNode.layer.animateAlpha(from: previousResetAlpha, to: 0.0, duration: 0.1)
        }
        
        Queue.mainQueue().after(1.6) {
            self.errorTextNode.alpha = 0.0
            self.errorTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
            
            self.hintButtonNode.alpha = previousHintAlpha
            self.hintButtonNode.layer.animateAlpha(from: 0.0, to: previousHintAlpha, duration: 0.1)
            
            if !self.resetNode.isHidden {
                self.resetNode.alpha = previousResetAlpha
                self.resetNode.layer.animateAlpha(from: 0.0, to: previousResetAlpha, duration: 0.1)
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)
            transition.updateBackgroundColor(node: self.textSeparatorNode, color: self.theme.list.itemPlainSeparatorColor)
        }
    }
    
    func animateSuccess() {
        self.codeInputView.animateSuccess()
        
        let values: [NSNumber] = [1.0, 1.1, 1.0]
        self.codeInputView.layer.animateKeyframes(values: values, duration: 0.4, keyPath: "transform.scale")
    }
            
    @objc private func textDidChange() {
        let text = self.textField.textField.text ?? ""
        self.proceedNode.isEnabled = !text.isEmpty
        self.updateNextEnabled?(!text.isEmpty)
        
        self.updatePasteVisibility()
    }
    
    private func codeChanged(text: String) {
        self.updateNextEnabled?(!text.isEmpty)
        if let codeType = self.codeType {
            var codeLength: Int32?
            switch codeType {
                case let .call(length):
                    codeLength = length
                case let .otherSession(length):
                    codeLength = length
                case let .missedCall(_, length):
                    codeLength = length
                case let .sms(length):
                    codeLength = length
                case let .email(_, length, _, _, _, _):
                    codeLength = length
                case let .fragment(_, length):
                    codeLength = length
                case let .firebase(_, length):
                    codeLength = length
                default:
                    break
            }
            if let codeLength = codeLength, text.count == Int(codeLength) {
                self.loginWithCode?(text)
            }
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if self.inProgress {
            return false
        }
        
        if string == "\n" {
            self.proceedPressed()
            return false
        }
        
        var updated = textField.text ?? ""
        updated.replaceSubrange(updated.index(updated.startIndex, offsetBy: range.lowerBound) ..< updated.index(updated.startIndex, offsetBy: range.upperBound), with: string)
        
        if updated.isEmpty {
            return true
        } else {
            return checkValidity(text: updated, isPaste: false) && !updated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    func checkValidity(text: String, isPaste: Bool) -> Bool {
        if let codeType = self.codeType {
            switch codeType {
            case let .word(startsWith):
                if let startsWith, startsWith.count == 1, !text.isEmpty && !text.hasPrefix(startsWith) {
                    if self.errorTextNode.alpha.isZero {
                        self.animateError(text: self.strings.Login_WrongPhraseError)
                    }
                    return false
                }
            case let .phrase(startsWith):
                if let startsWith, !text.isEmpty {
                    let firstWord = text.components(separatedBy: " ").first ?? ""
                    if !firstWord.isEmpty && !startsWith.hasPrefix(firstWord) {
                        if self.errorTextNode.alpha.isZero, text.count < 4 || isPaste {
                            self.animateError(text: self.strings.Login_WrongPhraseError)
                        }
                        return false
                    }
                }
            default:
                break
            }
        }
        return true
    }
    
    @objc func nextOptionNodePressed() {
        self.requestAnotherOption?()
    }
    
    @objc func previousOptionNodePressed() {
        self.requestPreviousOption?()
    }
    
    @objc func proceedPressed() {
        switch self.codeType {
        case let .fragment(url, _):
            self.openFragment?(url)
        case .word, .phrase:
            if let text = self.textField.textField.text, !text.isEmpty {
                self.loginWithCode?(text)
            }
        default:
            break
        }
    }
    
    @objc func signInWithApplePressed() {
        self.signInWithApple?()
    }
    
    @objc func resetPressed() {
        self.reset?()
    }
}
