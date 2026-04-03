import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
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

enum MediaFormatValidator {
    static let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "webm"]
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "heic"]
    
    static func isVideo(_ ext: String?) -> Bool {
        guard let ext = ext?.lowercased() else { return false }
        return videoExtensions.contains(ext)
    }
    
    static func isImage(_ ext: String?) -> Bool {
        guard let ext = ext?.lowercased() else { return false }
        return imageExtensions.contains(ext)
    }
}

public final class PublicProfileScreenController: TelegramBaseController {

    private func debugLog(_ message: String) {
        #if DEBUG
        Logger.shared.log("PublicProfile", message)
        #endif
    }
    
    private var controllerNode: PublicProfileScreenNode {
        return self.displayNode as! PublicProfileScreenNode
    }
    
    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?
    
    private let model: ProfileModel
    private var userID: Int = -1
    private var userRole: Role = .model
    private var userDetailModel: UserDetail? = nil
    private var userProfileData: UserProfileData? = nil
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let createWorkExperienceDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true
    private let peer: Peer?
    
    private let contextSourceNode = ContextReferenceContentNode()
    
    private var galleryLoaded: Bool = false
    private var profileLoaded: Bool = false

    private var containerLayout: (ContainerViewLayout, CGFloat)?

    private weak var activeGalleryController: ProfileGalleryController?

    private var isMyProfile: Bool

    private enum PickerPurpose {
        case photo
        case video
        case background
    }

    private var pickerPurpose: PickerPurpose = .photo
    
    internal var currentGalleryPhotos: [UserPhoto] = []
    internal var currentGalleryVideos: [UserVideoItem] = []
    
    internal func clearGalleryData() {
        currentGalleryPhotos = []
        currentGalleryVideos = []
    }
    
    public init(context: AccountContext, model: ProfileModel, peer: Peer? = nil) {
        self.context = context
        self.model = model
        self.isMyProfile = model.isMyProfile
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.peer = peer
        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear
        )
        
        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))

        super.init(context: context, navigationBarPresentationData: navigationBarData)
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

        let moreButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Profile/MoreActionIcon"), color: .white)
        let moreButton = UIBarButtonItem(image: moreButtonImg, style: .plain, target: self, action: #selector(self.moreMenu))

        if isMyProfile {
            let editButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Profile/EditActionIcon"), color: .white)
            
            let editButton = UIBarButtonItem(
                image: editButtonImg,
                style: .plain,
                target: self,
                action: #selector(self.showEditMenuPressed)
            )
            
            self.navigationItem.rightBarButtonItems = [editButton, moreButton]
        } else {
            self.navigationItem.rightBarButtonItems = [moreButton]
        }
    }
    
    @objc private func showEditMenuPressed() {
        // debug: removed
        
        var items: [EditMenuViewController.MenuItem] = [
            .init(title: DivoStrings.editProfile, action: { [weak self] in
                self?.navigateToEditProfile()
            }),
            .init(title: DivoStrings.changeBackground, action: { [weak self] in
                self?.navigateToChangeBackground()
            }),
            .init(title: DivoStrings.editSocialLinksMenu, action: { [weak self] in
                self?.navigateToEditSocialLinks()
            })
        ]

        if self.userRole != .agency {
            items.append(.init(title: DivoStrings.manageWorkExperience, action: { [weak self] in
                self?.navigateToManageExperience()
            }))
        } else {
            items.append(.init(title: DivoStrings.addModel, action: { [weak self] in
                self?.navigateToAddModel()
            }))
        }

        items.append(.init(title: DivoStrings.addPhoto, action: { [weak self] in
            if #available(iOS 14, *) {
                self?.navigateToAddPhoto()
            }
        }))

        items.append(.init(title: DivoStrings.addVideo, action: { [weak self] in
            if #available(iOS 14, *) {
                self?.navigateToAddVideo()
            }
        }))
                
        var sourcePoint = CGPoint(x: UIScreen.main.bounds.width - 20, y: 90)
        
        if let (_, navigationBarHeight) = self.containerLayout {
            sourcePoint.y = navigationBarHeight
        }
        
        let menuVC = EditMenuViewController(items: items, sourcePoint: sourcePoint)
        
        self.present(menuVC, animated: false, completion: nil)
    }

    @available(iOS 14, *)
    private func navigateToAddPhoto() {
        self.pickerPurpose = .photo
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.present(picker, animated: true)
    }

    @available(iOS 14, *)
    private func navigateToAddVideo() {
        self.pickerPurpose = .video
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.present(picker, animated: true)
    }

    private func navigateToEditProfile() {
        // debug: removed
        let editProfileController = EditProfileController(context: self.context, presentationData: self.presentationData, userDetailData: userDetailModel, updatePhoto: { [weak self] image in
            self?.controllerNode.currentPhoto = image
        })
        editProfileController.delegate = self
        self.push(editProfileController)
    }
    
    private func navigateToChangeBackground() {
        self.pickerPurpose = .background

        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                guard status == .authorized || status == .limited else { return }
                DispatchQueue.main.async {
                    var configuration = PHPickerConfiguration()
                    configuration.filter = .images
                    configuration.selectionLimit = 1
                    
                    let picker = PHPickerViewController(configuration: configuration)
                    picker.delegate = self
                    self?.present(picker, animated: true)
                }
            }
        }
    }
    
    private func navigateToEditSocialLinks() {
        
        let tiktok = userDetailModel?.model?.tiktokUrl ?? ""
        let youtube = userDetailModel?.model?.youtubeUrl ?? ""
        let telegram = userDetailModel?.model?.telegramUrl ?? ""
        let instagram = userDetailModel?.model?.instagramUrl ?? ""
        let website = userDetailModel?.model?.websiteUrl ?? ""
        
        let linksData = LinksData(
            tiktokUrl: self.controllerNode.extractHandle(from: tiktok),
            youtubeUrl: self.controllerNode.extractHandle(from: youtube),
            telegramUrl: self.controllerNode.extractHandle(from: telegram),
            instagramUrl: self.controllerNode.extractHandle(from: instagram),
            websiteUrl: self.controllerNode.extractHandle(from: website)
        )
        let socialLinksController = EditSocialLinksController(context: self.context, presentationData: self.presentationData, linksData: linksData)
        socialLinksController.delegate = self
        self.push(socialLinksController)
    }
    
    private func navigateToManageExperience() {
        let historyController = WorkExperienceController(context: self.context, model: self.model)
        self.push(historyController)
    }

    private func navigateToAddModel() {
        let addModelController = AddModelController(context: self.context, presentationData: self.presentationData)
        self.push(addModelController)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PublicProfileScreenNode(
            controller: self,
            context: self.context,
            presentationData: self.presentationData,
            model: model
        )

        self.controllerNode.onLikesTapped = {[weak self] in
            self?.presentInteractionSheet(type: .likes)
        }

        self.controllerNode.onViewsTapped = { [weak self] in
            self?.presentInteractionSheet(type: .views)
        }

        self.controllerNode.onSavesTapped = {[weak self] in
            self?.presentInteractionSheet(type: .saves)
        }

        self.controllerNode.onGalleryItemTapped = { [weak self] tabIndex, itemIndex in
            self?.openFullScreenGallery(tabIndex: tabIndex, itemIndex: itemIndex)
        }

        self.controllerNode.onEditLinksTapped = { [weak self] in
            self?.navigateToEditSocialLinks()
        }
        
        self.controllerNode.onAddPhotoTapped = { [weak self] in
            if #available(iOS 14, *) {
                self?.navigateToAddPhoto()
            }
        }

         self.controllerNode.onAddVideoTapped = { [weak self] in
            if #available(iOS 14, *) {
                self?.navigateToAddVideo()
            }
        }

        self.controllerNode.onSocialLinkTapped = { [weak self] url in
            self?.openSocialLink(url)
        }

        self.controllerNode.onAddModelTapped = { [weak self] in
            self?.navigateToAddModel()
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.containerLayout = (layout, self.navigationLayout(layout: layout).navigationFrame.maxY)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !profileLoaded {
            loadInitialData()
        }
        getUserGalleryProfile()
        controllerNode.retryVisibleVideoThumbnails()
    }

    private func loadInitialData() {
        profileLoaded = true
        Task {
            async let profileResult = fetchUserProfile()
            async let engagementResult = fetchEngagementTotals()
            let (profile, engagement) = await (profileResult, engagementResult)
            await MainActor.run {
                guard let detail = profile else {
                    self.profileLoaded = false
                    self.showErrorAlert("Failed to load profile. Please try again.")
                    return
                }
                self.userDetailModel = detail
                self.controllerNode.updateWithUserDetail(detail, self.isMyProfile)
                self.userID = detail.id
                self.userRole = Role(apiRole: detail.role)
                if let eng = engagement {
                    self.controllerNode.updateEngagementStats(likes: eng.likes, views: eng.views, saves: eng.saves)
                }
                self.loadGalleryPage(userId: self.userID, offset: 0)
                self.loadVideoGalleryPage(userId: self.userID, offset: 0)
            }
        }
    }

    private struct EngagementTotals {
        let likes: Int
        let views: Int
        let saves: Int
    }

    private func fetchUserProfile() async -> UserDetail? {
        do {
            let requestPath: String
            if isMyProfile {
                requestPath = "/user/info"
            } else {
                guard let userId = model.userId else { return nil }
                requestPath = "/user/\(userId)"
            }
            let response: UserDetailResponse = try await DivoAPIClient.shared.request(
                path: requestPath
            )
            return response.data
        } catch {
            self.debugLog("[DivoAPI] getUserProfile error: \(error)")
            return nil
        }
    }

    private func fetchEngagementTotals() async -> EngagementTotals? {
        guard isMyProfile || model.userId != nil else { return nil }
        do {
            let path = isMyProfile ? "/user/engagement?offset=0&limit=1" : "/user/engagement?offset=0&limit=1&userId=\(model.userId!)"
            let response: UserEngagementResponse = try await DivoAPIClient.shared.request(
                path: path,
                method: "GET"
            )
            let likes = response.data?.liked?.pagination?.meta?.totalCount ?? response.data?.liked?.pagination?.total ?? 0
            let views = response.data?.viewed?.pagination?.meta?.totalCount ?? response.data?.viewed?.pagination?.total ?? 0
            let saves = response.data?.followed?.pagination?.meta?.totalCount ?? response.data?.followed?.pagination?.total ?? 0
            return EngagementTotals(likes: likes, views: views, saves: saves)
        } catch {
            print("❌ [ENGAGEMENT TOTALS] Error: \(error)")
            return nil
        }
    }

    private func openSocialLink(_ urlString: String) {
        var finalUrlString = urlString
        
        if !finalUrlString.lowercased().hasPrefix("http://") && !finalUrlString.lowercased().hasPrefix("https://") {
            finalUrlString = "https://" + finalUrlString
        }
        
        if let url = URL(string: finalUrlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    private func getUserGalleryProfile() {
        guard !galleryLoaded else { return }
        galleryLoaded = true
        controllerNode.resetGalleryPagination()
    }
    
    @objc func moreMenu() {

    }

    func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    private static func userFacingMessage(from error: Error) -> String {
        if case DivoAPIError.httpError(_, let body) = error, !body.isEmpty {
            if let data = body.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return message
            }
            return body
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "No internet connection. Please try again."
        }
        return "Something went wrong. Please try again."
    }
}

// MARK: - Загрузка фотографий
extension PublicProfileScreenController {
    func loadGalleryPage(userId: Int, offset: Int) {
        controllerNode.setGalleryLoading(true)

        var body: GalleryListRequest
        body = GalleryListRequest(offset: offset, limit: 6, userId: userId)

        Task {
            do {
                let response: UserGalleryResponse = try await DivoAPIClient.shared.request(
                    path: "/user-gallery/list",
                    method: "POST",
                    body: body
                )
                await MainActor.run {
                    let isMy = !self.isMyProfile ? self.model.isMyProfile : self.isMyProfile
                    
                    let existingIds = Set(self.currentGalleryPhotos.map { $0.id })
                    let newPhotos = response.data.items.filter { !existingIds.contains($0.id) }
                    
                    self.controllerNode.appendGalleryPhotos(response.data, isMyProfile: isMy)
                    self.currentGalleryPhotos.append(contentsOf: newPhotos)
                    
                    if !newPhotos.isEmpty {
                        self.activeGalleryController?.updateData(photos: self.currentGalleryPhotos, videos: self.currentGalleryVideos)
                    } else {
                        self.activeGalleryController?.finishLoadingWithoutNewData()
                    }
                }
            } catch {
                self.debugLog("[DivoAPI] user/\(userId) error: \(error)")
                controllerNode.setGalleryLoading(false)
                self.activeGalleryController?.finishLoadingWithoutNewData()
            }
        }
    }
    
    // Открытие галереи на полный экран
    private func openFullScreenGallery(tabIndex: Int, itemIndex: Int) {
        print("🖼️ [GALLERY] Opening full-screen gallery, tabIndex=\(tabIndex), itemIndex=\(itemIndex)")
        
        guard itemIndex >= 0 else { return }
        let galleryController: ProfileGalleryController
        
        if tabIndex == 0 {
            guard !currentGalleryPhotos.isEmpty, itemIndex < currentGalleryPhotos.count else { return }
            
            galleryController = ProfileGalleryController(
                context: self.context,
                photos: currentGalleryPhotos,
                initialIndex: itemIndex,
                isVideoGallery: false,
                isOwnProfile: self.isMyProfile
            )
        } else if tabIndex == 1 {
            guard !currentGalleryVideos.isEmpty, itemIndex < currentGalleryVideos.count else { return }
            
            galleryController = ProfileGalleryController(
                context: self.context,
                videos: currentGalleryVideos,
                initialIndex: itemIndex,
                isVideoGallery: true,
                isOwnProfile: self.isMyProfile
            )
        } else {
            return
        }
        
        galleryController.requestMoreData = { [weak self] in
            guard let self = self else { return }
            if tabIndex == 0 {
                self.controllerNode.loadNextGalleryPage()
            } else if tabIndex == 1 {
                self.controllerNode.loadNextVideoGalleryPage()
            }
        }
        
        galleryController.onDeletePublication = { [weak self] deletedId in
            guard let self = self else { return }
            if tabIndex == 0 {
                self.currentGalleryPhotos.removeAll { $0.id == deletedId }
                self.controllerNode.removePhoto(withId: deletedId)
                
            } else if tabIndex == 1 {
                self.currentGalleryVideos.removeAll { $0.id == deletedId }
                self.controllerNode.removeVideo(withId: deletedId)
            }
        }
        
        self.activeGalleryController = galleryController
        self.push(galleryController)
    }
}


// MARK: - Загрузка видео
extension PublicProfileScreenController {
    func loadVideoGalleryPage(userId: Int, offset: Int) {
        controllerNode.setVideoGalleryLoading(true)

        var body: GalleryListRequest
        body = GalleryListRequest(offset: offset, limit: 6, userId: userId)
        
        Task {
            do {
                let response: UserVideoGalleryResponse = try await DivoAPIClient.shared.request(
                    path: "/publication/list",
                    method: "POST",
                    body: body
                )
                
                await MainActor.run {
                    let videoItems:[UserVideoItem] = response.data.items.filter { item in
                        item.files.contains { MediaFormatValidator.isVideo($0.fileExtension) }
                    }
                    
                    let existingIds = Set(self.currentGalleryVideos.map { $0.id })
                    let newVideos = videoItems.filter { !existingIds.contains($0.id) }
                    
                    let isMy = !self.isMyProfile ? self.model.isMyProfile : self.isMyProfile
                    
                    self.controllerNode.appendVideoGalleryItems(
                        videoItems,
                        pagination: response.data.pagination.meta,
                        isMyProfile: isMy
                    )
                    self.currentGalleryVideos.append(contentsOf: newVideos)
                    
                    if !newVideos.isEmpty {
                        self.activeGalleryController?.updateData(photos: self.currentGalleryPhotos, videos: self.currentGalleryVideos)
                    } else {
                        self.activeGalleryController?.finishLoadingWithoutNewData()
                    }
                }
            } catch {
                self.debugLog("[DivoAPI] user-videos error: \(error)")
                await MainActor.run {
                    controllerNode.videoGalleryRequestDidFail(offset: offset)
                    controllerNode.setVideoGalleryLoading(false)
                    self.activeGalleryController?.finishLoadingWithoutNewData()
                }
            }
        }
    }
}

// Загрузка каналов — TODO: заменить моки на Telegram MTProto API
extension PublicProfileScreenController {
    func loadTelegramChannels() {
        let mockChannels: [ProfileChannelItem] = [
            ProfileChannelItem(peer: "vogue", title: "Vogue Inside", followersCount: 1342, isPremium: false, customAvatarURL: nil),
            ProfileChannelItem(peer: "capsule", title: "Capsule Wardrobe", followersCount: 500, isPremium: true, customAvatarURL: nil),
            ProfileChannelItem(peer: "mode_mood", title: "Mode & Mood", followersCount: 34912, isPremium: true, customAvatarURL: nil),
            ProfileChannelItem(peer: "street_luxe", title: "Street Luxe", followersCount: 176, isPremium: false, customAvatarURL: nil),
            ProfileChannelItem(peer: "trend_lab", title: "Trend Lab", followersCount: 42, isPremium: false, customAvatarURL: nil),
            ProfileChannelItem(peer: "haute_daily", title: "Haute Daily", followersCount: 5986, isPremium: false, customAvatarURL: nil),
            ProfileChannelItem(peer: "minimal_chic", title: "Minimal & Chic", followersCount: 1906, isPremium: false, customAvatarURL: nil),
            ProfileChannelItem(peer: "fashion_drops", title: "Fashion Drops", followersCount: 3091, isPremium: false, customAvatarURL: nil)
        ]
        DispatchQueue.main.async { [weak self] in
            self?.controllerNode.updateChannelsList(mockChannels)
        }
    }
}

// Загрузка моделей, состоящих в агентстве
extension PublicProfileScreenController {
    func loadModels() {
        guard let agencyId = userDetailModel?.agency?.id else {
            debugLog("❌ [MODELS] agencyId is nil")
            DispatchQueue.main.async { [weak self] in
                self?.controllerNode.updateModelsList([])
            }
            return
        }

        Task { @MainActor in
            do {
                let body = AgencyModelsListRequest(offset: 0, limit: 50)
                let response: AgencyModelsResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/\(agencyId)/models/list",
                    method: "POST",
                    body: body
                )
                let items = response.data?.items ?? []
                let models = items.map { item -> ModelItem in
                    return ModelItem(
                        name: item.name ?? "Unknown",
                        role: "Model",
                        isPremium: false,
                        customAvatarURL: item.photo?.fullUrl,
                        localAvatarName: nil
                    )
                }
                self.controllerNode.updateModelsList(models)
            } catch {
                print("❌ [MODELS] Error: \(error)")
                self.controllerNode.updateModelsList([])
            }
        }
    }
}

// Загрузка событий через feedline/search (event/list недоступен для всех ролей)
extension PublicProfileScreenController {
    func loadEvents() {
        guard let userId = model.userId else {
            controllerNode.updateEventsList([])
            return
        }

        Task { @MainActor in
            do {
                let body = FeedlineSearchEventsRequest(offset: 0, limit: 50, isEvents: true)
                let response: FeedlineResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/search",
                    method: "POST",
                    body: body
                )
                let items = response.data.items.filter { $0.user.id == userId }
                let events = items.map { item -> EventItem in
                    let desc = item.description ?? ""
                    let avatarURL: String? = item.files.first.flatMap {
                        CDNURLHelper.convertToCDNURL($0.fullUrl)?.absoluteString
                    }
                    return EventItem(
                        name: item.title,
                        data: desc,
                        time: "",
                        countryFlag: "",
                        city: "",
                        customAvatarURL: avatarURL
                    )
                }
                self.controllerNode.updateEventsList(events)
            } catch {
                print("❌ [EVENTS] Error: \(error)")
                self.controllerNode.updateEventsList([])
            }
        }
    }
}

// Загрузка лайков, просмотров и созраненок
extension PublicProfileScreenController {
    
    private func presentInteractionSheet(type: InteractionListType) {
        let sheetVC = InteractionListViewController(type: type)
        
        sheetVC.requestData = { [weak self] offset, completion in
            self?.loadInteractionData(type: type, offset: offset, completion: completion)
        }
        
        if #available(iOS 15.0, *) {
            if let sheet = sheetVC.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 24
            }
        } else {

        }
        
        self.present(sheetVC, animated: true, completion: nil)
    }
    
    private func loadInteractionData(type: InteractionListType, offset: Int, completion: @escaping ([InteractionUser], Bool) -> Void) {
        guard self.userID != -1 else { return }
        
        let limit = 20
        Task {
            do {
                let path = isMyProfile ? "/user/engagement?offset=\(offset)&limit=\(limit)" : "/user/engagement?offset=\(offset)&limit=\(limit)&userId=\(self.userID)"
                let response: UserEngagementResponse = try await DivoAPIClient.shared.request(path: path, method: "GET")
                
                var apiItems: [EngagementItem] = []
                var totalCount = 0
                
                // ИСПРАВЛЕНИЕ: Гибкое получение total
                switch type {
                case .likes:
                    apiItems = response.data?.liked?.items ?? []
                    totalCount = response.data?.liked?.pagination?.meta?.totalCount ?? response.data?.liked?.pagination?.total ?? 0
                case .views:
                    apiItems = response.data?.viewed?.items ?? []
                    totalCount = response.data?.viewed?.pagination?.meta?.totalCount ?? response.data?.viewed?.pagination?.total ?? 0
                case .saves:
                    apiItems = response.data?.followed?.items ?? []
                    totalCount = response.data?.followed?.pagination?.meta?.totalCount ?? response.data?.followed?.pagination?.total ?? 0
                }
                
                let mappedUsers = apiItems.compactMap { item -> InteractionUser? in
                    guard let id = item.id else { return nil }
                    let avatarUrl = item.avatar?.fullUrl
                    var finalAvatarUrl: String? = nil
                    if let url = avatarUrl {
                        finalAvatarUrl = CDNURLHelper.convertToCDNURL(url)?.absoluteString ?? url
                    }
                    return InteractionUser(
                        id: id,
                        name: item.fullName ?? "Unknown",
                        role: item.roleLabel ?? item.role ?? "User",
                        avatarUrl: finalAvatarUrl,
                        isPremium: false
                    )
                }
                
                let hasMore = (offset + apiItems.count) < totalCount
                
                await MainActor.run {
                    completion(mappedUsers, hasMore)
                }
                
            } catch {
                print("❌ [INTERACTIONS] Error loading data for \(type.title): \(error)")
                await MainActor.run { completion([], false) }
            }
        }
    }
}

extension PublicProfileScreenController: EditSocialLinksDelegate {
    func didUpdateSocialLinksData() {
        self.profileLoaded = false
        self.loadInitialData()
    }
}

extension PublicProfileScreenController: EditProfileDelegate {
    func didUpdateProfileData() {
        self.profileLoaded = false
        self.loadInitialData()
    }
}


// MARK: - Image Picker & Upload Logic
@available(iOS 14, *)
extension PublicProfileScreenController: PHPickerViewControllerDelegate {

    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)

        guard let result = results.first else { return }

        switch self.pickerPurpose {
        case .background:
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    guard let self = self, let uiImage = image as? UIImage else { return }
                    let normalized = uiImage.fixedOrientation()
                    DispatchQueue.main.async {
                        self.controllerNode.updateBackgroundImage(normalized)
                        self.controllerNode.setBackgroundLoading(true)
                    }
                    self.uploadAndSetBackground(normalized)
                }
            }
        case .photo:
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    guard let self = self, let uiImage = image as? UIImage else { return }
                    self.uploadAndAddPhoto(uiImage)
                }
            }
        case .video:
            if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    guard let self = self, let url = url else { return }
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_video_\(Date().timeIntervalSince1970).mov")
                    do {
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        self.uploadAndAddVideo(tempURL)
                    } catch {
                        self.debugLog("[DivoAPI] Failed to copy video: \(error)")
                    }
                }
            }
        }
    }

    private func uploadAndAddPhoto(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        Task { @MainActor in
            self.controllerNode.startPhotoUpload(image: image)
        }

        Task {
            do {
                let uploadResponse: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: imageData,
                    fileName: "photo.jpg",
                    mimeType: "image/jpeg"
                )

                guard let fileUuid = uploadResponse.data?.uuid else {
                    throw DivoAPIError.unknown
                }

                let body = AddGalleryRequest(uuid: fileUuid)

                let addResponse: AddGalleryResponse = try await DivoAPIClient.shared.request(
                    path: "/user-gallery/add",
                    method: "POST",
                    body: body
                )

                await MainActor.run {
                    if let newPhoto = addResponse.data {
                        self.controllerNode.finishPhotoUpload(photo: newPhoto)
                        self.currentGalleryPhotos.insert(newPhoto, at: 0)
                    } else {
                        self.controllerNode.cancelPhotoUpload()
                        self.galleryLoaded = false
                        self.getUserGalleryProfile()
                    }
                }

            } catch {
                await MainActor.run {
                    self.controllerNode.cancelPhotoUpload()
                    self.showErrorAlert(Self.userFacingMessage(from: error))
                }
            }
        }
    }

    private func uploadAndAddVideo(_ videoURL: URL) {
        guard let videoData = try? Data(contentsOf: videoURL) else {
            print("❌ [UPLOAD VIDEO] Failed to read video data")
            return
        }

        let thumbnail = generateVideoThumbnailSync(from: videoURL)

        Task { @MainActor in
            self.controllerNode.startVideoUpload(thumbnail: thumbnail)
        }

        Task {
            do {
                let uploadResponse: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: videoData,
                    fileName: "video.mov",
                    mimeType: "video/quicktime"
                )
                
                guard let fileUuid = uploadResponse.data?.uuid else {
                    throw DivoAPIError.unknown
                }
                
                print("🎬 [UPLOAD VIDEO] File uploaded successfully, uuid: \(fileUuid)")
                
                let body = AddPublicationRequest(
                    title: "My Video",
                    description: "Video description",
                    type: "educational",
                    files: [
                        VideoFileData(order: 0, fileUuid: fileUuid)
                    ]
                )
                
                let addResponse: AddPublicationResponse = try await DivoAPIClient.shared.request(
                    path: "/publication/create",
                    method: "POST",
                    body: body
                )
                
                await MainActor.run {
                    if let newVideo = addResponse.data {
                        let video = UserPhoto(
                            id: newVideo.id ?? 0,
                            photo: UserFile(
                                fileName: newVideo.files?.first?.fileName ?? "",
                                fullUrl: newVideo.files?.first?.fullUrl ?? "",
                                fileExtension: newVideo.files?.first?.extensionType ?? "",
                                fileUuid: newVideo.files?.first?.fileUuid ?? ""
                            ),
                            likesCount: newVideo.likesCount,
                            isLikedByUser: false,
                            preview: nil
                        )
                        self.controllerNode.finishVideoUpload(video: video)
                        self.currentGalleryVideos.insert(
                            UserVideoItem(
                                id: video.id,
                                title: "",
                                description: "",
                                type: "",
                                likesCount: 0,
                                isLikedByUser: false,
                                files: [UserVideoFile(
                                    order: nil,
                                    fileName: video.photo.fileName,
                                    fullUrl: video.photo.fullUrl,
                                    fileUuid: video.photo.fileUuid,
                                    fileExtension: video.photo.fileExtension,
                                    description: nil
                                )]
                            ),
                            at: 0
                        )
                    } else {
                        self.controllerNode.cancelVideoUpload()
                    }
                }

                try? FileManager.default.removeItem(at: videoURL)

            } catch {
                await MainActor.run {
                    self.controllerNode.cancelVideoUpload()
                    self.showErrorAlert(Self.userFacingMessage(from: error))
                }
                try? FileManager.default.removeItem(at: videoURL)
            }
        }
    }

    private func generateVideoThumbnailSync(from url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func uploadAndSetBackground(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            DispatchQueue.main.async {
                self.controllerNode.setBackgroundLoading(false)
            }
            return
        }

        Task {
            do {
                let uploadResponse: FileUploadResponse = try await DivoAPIClient.shared.upload(
                    path: "/file/upload-file",
                    fileData: imageData
                )

                guard let fileUuid = uploadResponse.data?.uuid else {
                    throw DivoAPIError.unknown
                }

                self.debugLog("[DivoAPI] Background uploaded, uuid: \(fileUuid)")

                if self.userRole == .agency {
                    let request = UpdateDescriptionAgencyRequest(
                        agencyId: self.userDetailModel?.agency?.id,
                        background: UpdateDescriptionAgencyRequest.AvatarUuid(uuid: fileUuid)
                    )
                    let _: UpdateDescriptionAgencyResponse = try await DivoAPIClient.shared.request(
                        path: "/agency/update",
                        method: "POST",
                        body: request
                    )
                } else {
                    let request = UpdateBiographyPageRequest(
                        photo: UpdateBiographyPageRequest.AvatarUuid(uuid: fileUuid)
                    )
                    let _: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
                        path: "/user/update-profile",
                        method: "POST",
                        body: request
                    )
                }

                self.debugLog("[DivoAPI] Background updated successfully")

                await MainActor.run {
                    self.controllerNode.setBackgroundLoading(false)
                }
            } catch {
                self.debugLog("[DivoAPI] Upload background error: \(error)")
                await MainActor.run {
                    self.controllerNode.setBackgroundLoading(false)

                    let alert = UIAlertController(title: "Error", message: "Failed to update background: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}
