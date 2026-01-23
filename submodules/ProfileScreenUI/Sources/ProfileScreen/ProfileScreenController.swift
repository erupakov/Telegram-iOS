import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import TelegramBaseController
import LegacyMediaPickerUI
import Postbox
import MapResourceToAvatarSizes
import ContextUI

public final class ProfileScreenController: TelegramBaseController {
    
    private var controllerNode: ProfileScreenNode {
        return self.displayNode as! ProfileScreenNode
    }
    
    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?
    
    private let model: ProfileModel
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let createWorkExperienceDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true
    private let peer: Peer?
    
    public init(context: AccountContext, model: ProfileModel, peer: Peer? = nil) {
        self.context = context
        self.model = model
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.peer = peer
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
        
        super.init(context: context, navigationBarPresentationData: navigationBarData, mediaAccessoryPanelVisibility: .none, locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        updateNavigation()
    }
    
    deinit {
        self.supportPeerDisposable.dispose()
        self.createWorkExperienceDisposable.dispose()
    }
    
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateNavigation() {
        self.statusBar.statusBarStyle = .White

        
        let editButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Contact List/EditActionIcon"), color: .white)
        let editButton = UIBarButtonItem(image: editButtonImg, style: .plain, target: self, action: #selector(self.editPressed))
        
        self.navigationItem.rightBarButtonItems = [editButton]
    }
    
    @objc private func editPressed() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit Profile", style: .default, handler: { _ in
            let controller = EditProfileController(context: self.context, model: self.model)
            
            if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
                navigationController.pushViewController(controller)
            }
        }))
        alert.addAction(UIAlertAction(title: "Edit  Appearance", style: .default, handler: { _ in
            let controller = ProfileParametersController(context: self.context, model: self.model)
            
            if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
                navigationController.pushViewController(controller)
            }
        }))
        alert.addAction(UIAlertAction(title: "Change Profile Background", style: .default, handler: { _ in }))
        alert.addAction(UIAlertAction(title: "Edit Social Links", style: .default, handler: { _ in
            let controller = EditSocialLinksController(context: self.context, model: self.model)
            
            if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
                navigationController.pushViewController(controller)
            }
        }))
        alert.addAction(UIAlertAction(title: "Manage Work Experience", style: .default, handler: { _ in
            let controller = WorkExperienceController(context: self.context, model: self.model, peer: self.peer)
            
            if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
                navigationController.pushViewController(controller)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = self.navigationItem.rightBarButtonItem
        }
        
        self.present(alert, animated: true)
    }
    
    @objc private func backPressed() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func likePressed() {
        print("Like button pressed")
    }
    
    @objc private func sharePressed() {
        print("Share button pressed")
    }
    
    @objc private func bookmarkPressed() {
        print("Bookmark button pressed")
    }
    
    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        let theme = self.presentationData.theme
        
        self.displayNode = ProfileScreenNode(
            controller: self,
            context: self.context,
            presentationData: self.presentationData,
            model: model,
            addPhoto: { [weak self] in
                presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: theme, present: { c, a in
                    self?.view.endEditing(true)
                    self?.present(c, in: .window(.root), with: a)
                }, openCurrent: nil, completion: { image in
                    self?.controllerNode.currentPhoto = image
                    self?.controllerNode.toggleSpinner(active: true)
                    
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
                            self?.controllerNode.toggleSpinner(active: false)
                            self?.controllerNode.addPhotoToCollection()
                        }
                    }, error: { error in
                        self?.controllerNode.toggleSpinner(active: false)
                    })
                }, videoCompletion: { _, _, _ in
                })
            })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
