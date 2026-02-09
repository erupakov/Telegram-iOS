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
import GalleryUI

public final class ProfileScreenController: TelegramBaseController {
    
    private var controllerNode: ProfileScreenNode {
        return self.displayNode as! ProfileScreenNode
    }
    
    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?
    
    private var model: ProfileModel
    private var userProfileData: UserProfileData? = nil
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let supportBackground = MetaDisposable()
    private let getFullUserDisposable = MetaDisposable()
    private var peerDisposable: MetaDisposable?
    
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
        self.supportBackground.dispose()
        self.getFullUserDisposable.dispose()
        self.peerDisposable?.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateNavigation() {
        self.statusBar.statusBarStyle = .White

        let editButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Contact List/EditActionIcon"), color: .white)
        let editButton = UIBarButtonItem(image: editButtonImg, style: .plain, target: self, action: #selector(self.showMenu))
        
        self.navigationItem.rightBarButtonItems = [editButton]
    }
    
    @objc func showMenu() {
        let presentationData = self.presentationData
        let barHeight: CGFloat = 44.0
        let screenWidth = self.view.bounds.width
        
        if self.contextSourceNode.supernode == nil {
            self.view.addSubnode(self.contextSourceNode)
        }
        
        self.contextSourceNode.frame = CGRect(x: screenWidth - 50, y: 50, width: 40, height: barHeight)
        self.contextSourceNode.isUserInteractionEnabled = false
        
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: "Edit Profile", icon: { _ in return nil }, action: { [weak self] _, f in
            f(.default)
            self?.editProfile()
        })))
        
        items.append(.action(ContextMenuActionItem(text: "Change Profile Background", icon: { _ in return nil }, action: { [weak self] _, f in
            f(.default)
            self?.changeProfileBackground()
        })))
        
        items.append(.action(ContextMenuActionItem(text: "Edit Appearance", icon: { _ in return nil }, action: { [weak self] _, f in
            f(.default)
            self?.editAppearance()
        })))
        items.append(.action(ContextMenuActionItem(text: "Edit Social Links", icon: { _ in return nil }, action: { [weak self] _, f in
            f(.default)
            self?.editSocialLinks()
        })))
        items.append(.action(ContextMenuActionItem(text: "Manage Work Experience", icon: { _ in return nil }, action: { [weak self] _, f in
            f(.default)
            self?.editWorkExperience()
        })))

        let contextController = ContextController(
            presentationData: presentationData,
            source: .reference(MenuSource(controller: self, sourceNode: self.contextSourceNode)),
            items: .single(ContextController.Items(content: .list(items)))
        )
        
        self.present(contextController, in: .window(.root))
    }
    
    func uploadPhotoToCloud(context: AccountContext, image: UIImage) -> Signal<Int64?, NoError> {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            return .single(nil)
        }
        
        return context.engine.engineDivo.uploadedPhoto(resource: data)
    }
    
    private func changeProfileBackground() {
        
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        let theme = self.presentationData.theme
        
        let supportPeer = Promise<String?>()
        
        presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: theme, present: { c, a in
            self.view.endEditing(true)
            self.present(c, in: .window(.root), with: a)
        }, openCurrent: nil, completion: { image in
            let _ = self.uploadPhotoToCloud(context: self.context, image: image).start(next: { id in
                if let id = id {
                    print("⛳️", id)
                    supportPeer.set(self.context.engine.profileEngine.updateProfileBackground(backgroundId: id))
                    self.supportBackground.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { peerId in
                        print("🔕", peerId ?? "")
                        self.showAlert(text: "Profile Background changed")
                        self.getUserProfile()
                    }))
                }
            })
        }, videoCompletion: { _, _, _ in
        })
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
    
    private func editProfile() {
        let controller = EditProfileController(context: self.context, model: self.model, updatePhoto: { [weak self] image in
            self?.controllerNode.currentPhoto = image
            self?.controllerNode.addPhotoToCollection()
        })
        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
    }
    
    private func editAppearance() {
        let controller = ProfileParametersController(context: self.context, userProfileData: userProfileData)
        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
    }
    
    private func editSocialLinks() {
        let controller = EditSocialLinksController(context: context, userProfileData: userProfileData)
        if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
    }
    private func editWorkExperience() {
        let controller = WorkExperienceController(context: context, model: model, peer: peer)
        if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
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
            },
            openEditLink: {
                self.editSocialLinks()
            },
            openGallery: { [weak self] index in
                self?.openGallery(at: index)
            }
        )
        
        self.displayNodeDidLoad()
    }
    
    private func openGallery(at index: Int) {
        let photos: [TelegramPeerPhoto] = self.controllerNode.localPhotos.compactMap { item in
            switch item {
            case let .telegram(photo): return photo
            default: return nil
            }
        }
        
        guard !photos.isEmpty else { return }
        
        let groupingKey = Int64.random(in: Int64.min...Int64.max)
        let totalCount = UInt32(photos.count)
        let commonTimestamp = Int32(Date().timeIntervalSince1970)
        
        var messages: [Message] = []
        for (i, photo) in photos.enumerated() {
            let fakeMsgId = MessageId(
                peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)),
                namespace: Namespaces.Message.Local,
                id: Int32(i + 1)
            )
            
            let message = Message(
                stableId: UInt32(i + 1),
                stableVersion: 0,
                id: fakeMsgId,
                globallyUniqueId: nil,
                groupingKey: groupingKey,
                groupInfo: MessageGroupInfo(stableId: totalCount),
                threadId: nil,
                timestamp: commonTimestamp,
                flags: [],
                tags: [],
                globalTags: [],
                localTags: [],
                customTags: [],
                forwardInfo: nil,
                author: nil,
                text: "",
                attributes: [],
                media: [photo.image],
                peers: SimpleDictionary(),
                associatedMessages: SimpleDictionary(),
                associatedMessageIds: [],
                associatedMedia: [:],
                associatedThreadInfo: nil,
                associatedStories: [:]
            )
            
            messages.append(message)
        }
        
        let startMessageId = messages[max(0, min(index, messages.count - 1))].id
        
        let source: GalleryControllerItemSource = .custom(
            messages: .single((messages, Int32(totalCount), false)),
            messageId: startMessageId,
            loadMore: nil
        )
        
        let controller = GalleryController(
            context: self.context,
            source: source,
            invertItemOrder: true,
            replaceRootController: { _, _ in },
            baseNavigationController: self.navigationController as? NavigationController
        )
        
        controller.centralItemUpdated = { [weak controller] messageId in
            guard let controller = controller else { return }
            controller.navigationItem.titleView = nil
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                controller.title = "\(index + 1) из \(totalCount)"
            }
        }
        
        let _ = (controller.ready.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak controller] _ in
            Queue.mainQueue().after(0.15) {
                guard let controller = controller else { return }
                UIView.transition(with: controller.view, duration: 0.2, options: .transitionCrossDissolve, animations: {
                    controller.navigationItem.titleView = nil
                    if let index = messages.firstIndex(where: { $0.id == startMessageId }) {
                        controller.title = "\(index + 1) \(self.presentationData.strings.Common_of) \(totalCount)"
                    }
                }, completion: nil)
            }
        })
        
        controller.temporaryDoNotWaitForReady = true
        
        self.present(controller, in: .window(.root))
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
            self.model.biography = userProfile?.about ?? ""
            self.controllerNode.getUpdates(userProfile?.about ?? "", userProfile?.physicalParams, userProfile?.gender)
            self.controllerNode.reloadSocialMedia(userProfile?.socialLinks)
            self.controllerNode.reloadBackground(userProfile?.backgroundImage)
        }))
        
        peerDisposable = MetaDisposable()
        let signal: Signal<Peer?, NoError> = Signal { subscriber in
            let disposable = MetaDisposable()
            let transactionSignal = self.context.account.postbox.transaction { transaction in
                let peerId = self.context.account.peerId
                return transaction.getPeer(peerId)
            }
            disposable.set(transactionSignal.start(next: { peer in
                subscriber.putNext(peer)
                subscriber.putCompletion()
            }))
            return disposable
        }
        peerDisposable?.set(signal.start(next: { [weak self] peer in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.model.name = (peer as? TelegramUser)?.firstName ?? ""
                self.model.lastName = (peer as? TelegramUser)?.lastName ?? ""
                
                let fullName = self.model.name + " " + (self.model.lastName ?? "")
                self.controllerNode.updateNameLabel(fullName)
            }
        }))
    }
    
}

final class MenuSource: ContextReferenceContentSource {
    let controller: ViewController
    let sourceNode: ContextReferenceContentNode

    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
