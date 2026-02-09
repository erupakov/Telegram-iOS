import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import MessageUI
import TelegramPresentationData
import AccountContext
import ShareController
import AlertUI
import PresentationDataUtils
import SearchUI
import LegacyMediaPickerUI
import CountrySelectionUI
import ChatScheduleTimeController
import Postbox

public class ProfileParametersController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    
    private var createEventNode: ProfileParametersNode {
        return self.displayNode as! ProfileParametersNode
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var userProfileData: UserProfileData?
    
    public init(context: AccountContext, userProfileData: UserProfileData?) {
        self.context = context
        self.userProfileData = userProfileData
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let darkNavigationTheme = NavigationBarTheme(
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)

        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))
        
        super.init(navigationBarPresentationData: navigationBarData)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = "Your parameters"
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        }).strict()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        let theme = self.presentationData.theme
        
        self.displayNode = ProfileParametersNode(context: self.context, userProfileData: userProfileData, addPhoto: { [weak self] in
            presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: theme, present: { c, a in
                self?.view.endEditing(true)
                self?.present(c, in: .window(.root), with: a)
            }, openCurrent: nil, completion: { image in
//                self?.createEventNode.currentPhoto = image
//                self?.avatarAsset = nil
//                self?.avatarAdjustments = nil
            }, videoCompletion: { image, asset, adjustments in
//                self?.createEventNode.currentPhoto = image
//                self?.avatarAsset = asset
//                self?.avatarAdjustments = adjustments
            })
        })
        
        self.createEventNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
        }
        self.createEventNode.openGenderPicker = { [weak self] in
            self?.openGenderPicker()
        }
        
        self.displayNodeDidLoad()
    }
    
    private func showAlert(text: String) {
        
        let alertController = textAlertController(
            context: context, title: nil,
            text: text, actions: [
                TextAlertAction(type: .genericAction, title: "Ok", action: {
                    print("ok")
                })
            ])
        present(alertController, in: .window(.root))
    }
    
    private func openGenderPicker() {
        let presentationData = self.presentationData
        
        let controller = ActionSheetController(presentationData: presentationData)
        
        let dismissAction = ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak controller] in
            controller?.dismissAnimated()
        })
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Male", color: .accent, action: { [weak self] in
                    self?.createEventNode.currentGender = .male
                    controller.dismissAnimated()
                }),
                ActionSheetButtonItem(title: "Female", color: .accent, action: { [weak self] in
                    self?.createEventNode.currentGender = .female
                    controller.dismissAnimated()
                })
            ]),
            ActionSheetItemGroup(items: [dismissAction])
        ])
        
        self.present(controller, in: .window(.root))
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.createEventNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
}
