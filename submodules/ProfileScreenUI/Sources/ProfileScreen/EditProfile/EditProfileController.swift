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
import MapResourceToAvatarSizes

public class EditProfileController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    
    private var createEventNode: EditProfileNode {
        return self.displayNode as! EditProfileNode
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let model: ProfileModel
    private let updatePhoto: (UIImage?) -> Void
    
    public init(context: AccountContext, model: ProfileModel, updatePhoto: @escaping (UIImage?) -> Void) {
        self.context = context
        self.model = model
        self.updatePhoto = updatePhoto
        
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
        
        self.title = "My Profile"
        
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
        
        self.displayNode = EditProfileNode(
            context: self.context,
            model: model,
            addPhoto: { [weak self] in
                presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: theme, present: { c, a in
                    self?.view.endEditing(true)
                    self?.present(c, in: .window(.root), with: a)
                }, openCurrent: nil, completion: { image in
                    self?.createEventNode.currentPhoto = image
                    self?.createEventNode.toggleSpinner(active: true)
                    self?.updatePhoto(image)
                    let tempFile = TempBox.shared.tempFile(fileName: "avatar.jpg")
                    guard let data = image.jpegData(compressionQuality: 0.9), let context = self?.context else { return }
                    try? data.write(to: URL(fileURLWithPath: tempFile.path))
                    
                    let resource = LocalFileReferenceMediaResource(localFilePath: tempFile.path, randomId: Int64.random(in: Int64.min ... Int64.max))
                    
                    let uploadedPeerPhoto = context.engine.peers.uploadedPeerPhoto(resource: resource)
                    let postbox = context.account.postbox
                    let signal = context.engine.peers.updatePeerPhoto(
                        peerId: context.account.peerId,
                        photo: uploadedPeerPhoto,
                        video: nil,
                        videoStartTimestamp: nil,
                        markup: nil,
                        mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
                        }
                    )
                    
                    let _ = (signal |> deliverOnMainQueue).start(next: { status in
                        if case .complete = status {
                            self?.createEventNode.toggleSpinner(active: false)
                        }
                    }, error: { error in
                        self?.createEventNode.toggleSpinner(active: false)
                    })
                }, videoCompletion: { _, _, _ in
                })
            })
        
        self.createEventNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
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
