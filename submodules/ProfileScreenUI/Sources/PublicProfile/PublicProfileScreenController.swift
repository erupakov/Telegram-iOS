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

public final class PublicProfileScreenController: TelegramBaseController {
    
    private var controllerNode: PublicProfileScreenNode {
        return self.displayNode as! PublicProfileScreenNode
    }
    
    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?
    
    private let model: ProfileModel
    private var userProfileData: UserProfileData? = nil
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let createWorkExperienceDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true
    private let peer: Peer?
    
    private let contextSourceNode = ContextReferenceContentNode()
    
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
    }
    
    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        let theme = self.presentationData.theme
        
        self.displayNode = PublicProfileScreenNode(
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
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getUserProfile()
    }
    
    private func getUserProfile() {
        let supportPeer = Promise<UserProfileData?>()
        
        supportPeer.set(context.engine.profileEngine.getUserProfile(peer: peer))
        self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { userProfile in
            self.userProfileData = userProfile
        }))
    }
    
}
