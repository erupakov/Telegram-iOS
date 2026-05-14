import Foundation
import UIKit
import AVFoundation
import Display
import TelegramBaseController
import TelegramCore
import DivoCore
import DivoUIKit
import TelegramPresentationData
import AccountContext

public class ProfileGalleryController: TelegramBaseController {
    private var galleryNode: ProfileGalleryControllerNode {
        return self.displayNode as! ProfileGalleryControllerNode
    }
    private var presentationData: PresentationData
    private var photos: [UserPhoto]
    private var videos: [UserVideoItem]
    
    private let context: AccountContext
    private let initialIndex: Int
    private let isVideoGallery: Bool
    private let isOwnProfile: Bool
    private var isDeleting = false
    private let isLocalOnly: Bool

    public var requestMoreData: (() -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.galleryNode.requestMoreData = requestMoreData
            }
        }
    }
    
    public var onDeletePublication: ((Int) -> Void)?
    
    public init(
        context: AccountContext,
        photos: [UserPhoto] = [],
        videos: [UserVideoItem] = [],
        initialIndex: Int = 0,
        isVideoGallery: Bool = false,
        isOwnProfile: Bool = false,
        isLocalOnly: Bool = false
    ) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.photos = photos
        self.videos = videos
        self.initialIndex = initialIndex
        self.isVideoGallery = isVideoGallery
        self.isOwnProfile = isOwnProfile
        self.isLocalOnly = isLocalOnly

        super.init(context: context, navigationBarPresentationData: nil)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isVideoGallery {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.galleryNode.pauseAllVideos()
        if isVideoGallery {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ProfileGalleryControllerNode(
            context: self.context,
            presentationData: self.presentationData,
            photos: self.photos,
            videos: self.videos,
            initialIndex: self.initialIndex,
            isVideoGallery: self.isVideoGallery,
            isOwnProfile: self.isOwnProfile,
            controller: self
        )
        self.displayNode.backgroundColor = .black
        self.galleryNode.requestMoreData = self.requestMoreData
                
        self.galleryNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.galleryNode.onMenuTapped = { [weak self] in
            self?.editMenu()
        }
        
        self.displayNodeDidLoad()
    }
    
    @objc func editMenu() {
        guard let publicationId = self.galleryNode.getCurrentPublicationId() else { return }
        self.performDeletePublication(id: publicationId)
    }
    
    private func performDeletePublication(id: Int) {
        guard !isDeleting else { return }
        isDeleting = true
        
        if isLocalOnly {
            self.removeLocally(id: id)
            self.isDeleting = false
        } else {
            Task { @MainActor in
                defer { self.isDeleting = false }
                do {
                    let path = self.isVideoGallery ? "/publication/\(id)" : "/user-gallery/\(id)"
                    
                    let response: DeletePublicationResponse = try await DivoAPIClient.shared.request(
                        path: path,
                        method: "DELETE"
                    )
                    
                    if response.errors == nil {
                        self.removeLocally(id: id)
                    } else {
                        self.galleryNode.showSnackbar(
                            message: DivoStrings.failedToDelete,
                            style: .error
                        )
                    }
                } catch {
                    let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedToDelete
                    self.galleryNode.showSnackbar(
                        message: userMsg,
                        style: .error
                    )
                }
            }
        }
    }
    
    private func removeLocally(id: Int) {
        self.onDeletePublication?(id)
        
        self.galleryNode.removePublication(withId: id)
        
        if self.isVideoGallery {
            self.videos.removeAll { $0.id == id }
        } else {
            self.photos.removeAll { $0.id == id }
        }
        
        let totalCount = self.isVideoGallery ? self.videos.count : self.photos.count
        if totalCount > 0 {
            let currentIndex = min(self.galleryNode.currentIndex, totalCount - 1)
            self.title = DivoStrings.xOfY(currentIndex + 1, totalCount)
        } else {
            if let nav = self.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            } else {
                self.dismiss()
            }
        }
    }
    
    public func updateData(photos: [UserPhoto], videos: [UserVideoItem]) {
        self.photos = photos
        self.videos = videos
        
        self.galleryNode.updateData(photos: photos, videos: videos)
        
        let totalCount = self.isVideoGallery ? videos.count : photos.count
        self.title = DivoStrings.xOfY(self.galleryNode.currentIndex + 1, totalCount)
    }
    
    public func finishLoadingWithoutNewData() {
        self.galleryNode.finishLoadingWithoutNewData()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.galleryNode.containerLayoutUpdated(layout, transition: transition)
    }
}
