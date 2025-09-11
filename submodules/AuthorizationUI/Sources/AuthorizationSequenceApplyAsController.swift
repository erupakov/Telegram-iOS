import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import LegacyComponents
import ProgressNavigationButtonNode
import ImageCompression
import LegacyMediaPickerUI
import Postbox
import TextFormat
import MoreButtonNode
import ContextUI
import CountrySelectionUI

final class AuthorizationSequenceApplyAsController: ViewController {
    private var controllerNode: ChooseRoleControllerNode {
        return self.displayNode as! ChooseRoleControllerNode
    }
    
    private var validLayout: ContainerViewLayout?
    
    private let moreButtonNode: MoreButtonNode
    
    private let presentationData: PresentationData
    
    private let typeOfRole: String
    
    private let back: () -> Void
    
    var initialName: (String, String) = ("", "")
    private var termsOfService: UnauthorizedAccountTermsOfService?
    
    var signUpWithName: ((String, String, AuthorizationModelInfo, Data?, Any?, TGVideoEditAdjustments?, Bool) -> Void)?
    
    var openUrl: ((String) -> Void)?
    
    var avatarAsset: Any?
    var avatarAdjustments: TGVideoEditAdjustments?
    
    var announceSignUp = true
    
    private let hapticFeedback = HapticFeedback()
    private var isFirstAppearance = true
    
    var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    init(presentationData: PresentationData, back: @escaping () -> Void, typeOfRole: String) {
        self.presentationData = presentationData
        self.back = back
        
        self.typeOfRole = typeOfRole
        
        self.moreButtonNode = MoreButtonNode(theme: self.presentationData.theme)
        self.moreButtonNode.iconNode.enqueueState(.more, animated: false)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Login_CancelSignUpConfirmation, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Login_CancelPhoneVerificationContinue, action: {
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Login_CancelPhoneVerificationStop, action: {
                back()
            })]), in: .window(.root))
        }
        
        self.moreButtonNode.action = { [weak self] _, gesture in
            if let strongSelf = self {
                strongSelf.morePressed(node: strongSelf.moreButtonNode.contextSourceNode, gesture: gesture)
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Login_CancelSignUpConfirmation, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Login_CancelPhoneVerificationContinue, action: {
        }), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Login_CancelPhoneVerificationStop, action: { [weak self] in
            self?.back()
        })]), in: .window(.root))
    }
    
    @objc private func moreButtonPressed() {
        self.moreButtonNode.buttonPressed()
    }
    
    @objc private func morePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
        let presentationData = self.presentationData
        
        let announceSignUp = self.announceSignUp
        var items: [ContextMenuItem] = []
        
        let nop: ((ContextMenuActionItem.Action) -> Void)? = nil
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Login_Announce_Info, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: nop)))
        items.append(.separator)
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Login_Announce_Notify, icon: { theme in
            if !announceSignUp {
                return nil
            }
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
        }, iconPosition: .left, action: { [weak self] _, a in
            a(.default)
          
            self?.announceSignUp = true
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Login_Announce_DontNotify, icon: { theme in
            if announceSignUp {
                return nil
            }
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
        }, iconPosition: .left, action: { [weak self] _, a in
            a(.default)

            self?.announceSignUp = false
        })))
        
        
        let contextController = ContextController(presentationData: self.presentationData, source: .reference(AuthorizationContextReferenceContentSource(controller: self, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.present(contextController, in: .window(.root))
    }
    
    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }
    }
    
    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        
        let theme = self.presentationData.theme
        self.displayNode = ChooseRoleControllerNode(theme: theme, strings: self.presentationData.strings, typeOfRole: typeOfRole, addPhoto: { [weak self] in
            presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: theme, present: { c, a in
                self?.view.endEditing(true)
                self?.present(c, in: .window(.root), with: a)
            }, openCurrent: nil, completion: { image in
                self?.controllerNode.currentPhoto = image
                self?.avatarAsset = nil
                self?.avatarAdjustments = nil
            }, videoCompletion: { image, asset, adjustments in
                self?.controllerNode.currentPhoto = image
                self?.avatarAsset = asset
                self?.avatarAdjustments = adjustments
            })
        })
        self.displayNodeDidLoad()
        
//        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        self.controllerNode.signUpWithName = { [weak self] modelInfo in
            self?.nextPressed(modelInfo: modelInfo)
        }
        
        self.controllerNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme, displayCodes: false)
                controller.completeWithCountryCode = { _, countryId, name in
                    
                    if let strongSelf = self {
                        strongSelf.controllerNode.updateCountry(countryId: countryId, countryName: name)
                    }
                }
                controller.dismissed = {
//                    self?.controllerNode.activateInput()
                }
                strongSelf.push(controller)
            }
        }
        
        self.controllerNode.back = { [weak self] in
            self?.back()
        }
        
        self.controllerNode.openTermsOfService = { [weak self] in
            guard let strongSelf = self, let termsOfService = strongSelf.termsOfService else {
                return
            }
            strongSelf.view.endEditing(true)

            let presentAlertImpl: () -> Void = {
                guard let strongSelf = self else {
                    return
                }
                var dismissImpl: (() -> Void)?
                let alertTheme = AlertControllerTheme(presentationData: strongSelf.presentationData)
                let attributedText = stringWithAppliedEntities(termsOfService.text, entities: termsOfService.entities, baseColor: alertTheme.primaryColor, linkColor: alertTheme.accentColor, baseFont: Font.regular(13.0), linkFont: Font.regular(13.0), boldFont: Font.semibold(13.0), italicFont: Font.italic(13.0), boldItalicFont: Font.semiboldItalic(13.0), fixedFont: Font.regular(13.0), blockQuoteFont: Font.regular(13.0), message: nil)
                let contentNode = TextAlertContentNode(theme: alertTheme, title: NSAttributedString(string: strongSelf.presentationData.strings.Login_TermsOfServiceHeader, font: Font.medium(17.0), textColor: alertTheme.primaryColor, paragraphAlignment: .center), text: attributedText, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                        dismissImpl?()
                    })
                ], actionLayout: .vertical, dismissOnOutsideTap: true)
                contentNode.textAttributeAction = (NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), { value in
                    if let value = value as? String {
                        strongSelf.openUrl?(value)
                    }
                })
                let controller = AlertController(theme: alertTheme, contentNode: contentNode)
                dismissImpl = { [weak controller] in
                    controller?.dismissAnimated()
                }
                strongSelf.view.endEditing(true)
                strongSelf.present(controller, in: .window(.root))
            }
            presentAlertImpl()
        }
        
        self.controllerNode.updateData(firstName: self.initialName.0, lastName: self.initialName.1, hasTermsOfService: self.termsOfService != nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
//        if let navigationController = self.navigationController as? NavigationController, let layout = self.validLayout {
//            addTemporaryKeyboardSnapshotView(navigationController: navigationController, layout: layout)
//        }
        
        self.controllerNode.activateInput()
    }
    
    func updateData(firstName: String, lastName: String, termsOfService: UnauthorizedAccountTermsOfService?) {
        if self.isNodeLoaded {
            if (firstName, lastName) != self.controllerNode.currentName || self.termsOfService != termsOfService {
                self.termsOfService = termsOfService
                self.controllerNode.updateData(firstName: firstName, lastName: lastName, hasTermsOfService: termsOfService != nil)
            }
        } else {
            self.initialName = (firstName, lastName)
            self.termsOfService = termsOfService
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let hadLayout = self.validLayout != nil
        self.validLayout = layout
        
        if !hadLayout {
            self.updateNavigationItems()
            
            if let navigationController = self.navigationController as? NavigationController {
                addTemporaryKeyboardSnapshotView(navigationController: navigationController, layout: layout, local: true)
            }
        }
        
        if isFirstAppearance {
            self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
            
            isFirstAppearance = false
        }
    }
    
    func nextPressed(modelInfo: AuthorizationModelInfo) {
        
//        self.hapticFeedback.error()
//        self.controllerNode.animateError()
        let name = modelInfo.name ?? ""
        self.signUpWithName?(name, "", modelInfo, self.controllerNode.currentPhoto.flatMap({ image in
            let tempFile = TempBox.shared.tempFile(fileName: "file")
            let result = compressImageToJPEG(image, quality: 0.7, tempFilePath: tempFile.path)
            TempBox.shared.dispose(tempFile)
            return result
        }), self.avatarAsset, self.avatarAdjustments, self.announceSignUp)
    }
}

private final class AuthorizationContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
