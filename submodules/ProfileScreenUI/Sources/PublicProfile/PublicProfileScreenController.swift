import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
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
import EventsUI
import DivoUIKit
import FaceSearchUI
import DivoGallery
import StoryContainerScreen

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
    private let openChatDisposable = MetaDisposable()
    private var isOpeningChat = false
    private let storyStateDisposable = MetaDisposable()
    private let storyListStateDisposable = MetaDisposable()
    private let openStoryProgressDisposable = MetaDisposable()
    // Teamgram-peer экрана: свой — account.peerId, чужой — по telegramId из /user/{id}
    private var storyPeerId: EnginePeer.Id?
    private var expiringStoryList: PeerExpiringStoryListContext?
    
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true
    private let peer: Peer?
    
    private let contextSourceNode = ContextReferenceContentNode()
    
    private var galleryLoaded: Bool = false
    private var profileLoaded: Bool = false

    private var containerLayout: (ContainerViewLayout, CGFloat)?

    private weak var activeGalleryController: ProfileGalleryController?

    private var isMyProfile: Bool
    private var isMyRoleAgency: Bool

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

    private var isUploadFromFAB: Bool = false

    private var similarProfilesIsLoading: Bool = false

    private struct EngagementTotals {
        let likes: Int
        let views: Int
        let saves: Int
    }
    
    public init(context: AccountContext, model: ProfileModel, peer: Peer? = nil) {
        self.context = context
        self.model = model
        self.isMyProfile = model.isMyProfile
        self.isMyRoleAgency = DivoConfig.currentUserRole == .agency
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.peer = peer

        super.init(context: context, navigationBarPresentationData: nil)

        divoTrack(.profileOpened(
            targetUserId: Int64(model.userId ?? 0),
            source: model.isMyProfile ? "my_profile" : "other_profile"
        ))

        // Подписываемся на уведомление о смене статуса отклика
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleEventAppliedStatusChanged(_:)),
            name: DivoConfig.divoEventAppliedStatusChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleEventDataUpdated(_:)),
            name: DivoConfig.divoEventDataUpdated,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleEventDeleted(_:)),
            name: DivoConfig.divoEventDeleted,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleGlobalEventCreated),
            name: DivoConfig.divoEventCreated,
            object: nil
        )
    }
    
    deinit {
        self.supportPeerDisposable.dispose()
        self.createWorkExperienceDisposable.dispose()
        self.openChatDisposable.dispose()
        self.storyStateDisposable.dispose()
        self.storyListStateDisposable.dispose()
        self.openStoryProgressDisposable.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func navigateToCreateEvent() {
        let createEventController = CreateEventController(context: self.context)
        
        createEventController.onEventCreated = { [weak self] in
            self?.loadEvents()
        }
        
        self.push(createEventController)
    }
    
    private func navigateToEditEvent(eventId: Int) {
        // Открываем CreateEventController в режиме редактирования
        let editEventController = CreateEventController(context: self.context, mode: .edit(eventId: eventId))
        
        // Обновляем список событий после успешного сохранения
        editEventController.onEventCreated = { [weak self] in
            self?.loadEvents()
        }
        
        self.push(editEventController)
    }

    @available(iOS 14, *)
    private func navigateToAddPhoto() {
        divoTrack(.profileMediaUploadTapped(mediaType: "photo", targetUserId: Int(model.userId ?? 0)))
        self.pickerPurpose = .photo
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        picker.view.tintColor = DivoColorPalette.accent
        self.present(picker, animated: true)
    }

    @available(iOS 14, *)
    private func navigateToAddVideo() {
        divoTrack(.profileMediaUploadTapped(mediaType: "video", targetUserId: Int(model.userId ?? 0)))
        self.pickerPurpose = .video
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        picker.view.tintColor = DivoColorPalette.accent
        self.present(picker, animated: true)
    }

    private func navigateToEditProfile(selectedIndex: Int = 0) {
        divoTrack(.profileEditOpened)
        let editProfileController = EditProfileController(
            context: self.context, 
            presentationData: self.presentationData, 
            userDetailData: userDetailModel, 
            selectedIndex: selectedIndex
        )
        editProfileController.delegate = self
        self.push(editProfileController)
    }
    
    private func navigateToChangeBackground() {
        divoTrack(.profileMediaUploadTapped(mediaType: "background", targetUserId: Int(model.userId ?? 0)))
        self.pickerPurpose = .background

        if #available(iOS 14, *) {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1

            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            picker.view.tintColor = DivoColorPalette.accent
            self.present(picker, animated: true)
        }
    }
    
    private func navigateToEditSocialLinks() {
        divoTrack(.socialLinksOpened)

        let tiktok = userDetailModel?.model?.tiktokUrl ?? ""
        let youtube = userDetailModel?.model?.youtubeUrl ?? ""
        let instagram = userDetailModel?.model?.instagramUrl ?? ""
        let website = userDetailModel?.model?.websiteUrl ?? ""

        let linksData = LinksData(
            tiktokUrl: self.controllerNode.extractHandle(from: tiktok),
            youtubeUrl: self.controllerNode.extractHandle(from: youtube),
            telegramUrl: nil,
            instagramUrl: self.controllerNode.extractHandle(from: instagram),
            websiteUrl: self.controllerNode.extractHandle(from: website)
        )
        // У агентства соцсети живут в /user-social-network, а не в model.*Url
        let isAgency = userDetailModel?.role == "agency_employee"
        let socialLinksController = EditSocialLinksController(
            context: self.context,
            presentationData: self.presentationData,
            linksData: linksData,
            agencyNetworks: isAgency ? (userDetailModel?.userSocialNetworks ?? []) : nil
        )
        socialLinksController.delegate = self
        self.push(socialLinksController)
    }
    
    private func navigateToManageExperience() {
        divoTrack(.workHistoryOpened(targetUserId: Int(model.userId ?? 0)))
        let historyController = WorkExperienceController(context: self.context, model: self.model)
        self.push(historyController)
    }

    private func navigateToAddWorkExperience() {
        divoTrack(.workHistoryCreateOpened)
        let controller = AddWorkExperienceController(context: self.context)
        controller.delegate = self
        self.push(controller)
    }

    private func navigateToAddModel() {
        let addRosterController = AddRosterModelController(context: self.context)
        
        let nav = UINavigationController(rootViewController: addRosterController)
        nav.setNavigationBarHidden(true, animated: false)
        
        addRosterController.onModelAdded = { [weak self, weak nav] selectedUser in
            guard let self = self, let nav = nav else { return }
            
            let confirmationController = RosterApplyConfirmationController(
                context: self.context,
                userId: selectedUser.id
            )
            
            confirmationController.onConfirmSuccess = { [weak self, weak nav] name in
                guard let self = self else { return }
                nav?.dismiss(animated: true)
                self.loadModels()
                guard let name = name else { return }
                self.controllerNode.showSnackbar(
                    message: DivoStrings.addModelSuccess(name),
                    style: .success
                )
            }
            nav.pushViewController(confirmationController, animated: true)
        }
        
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 24
            }
        }
        
        self.present(nav, animated: true)
    }

    private func deleteModelFromAgency(_ recordId: Int?) {
        guard let recordId = recordId, let agencyId = self.userDetailModel?.agency?.id else { return }
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/\(agencyId)/models/\(recordId)",
                    method: "DELETE"
                )
                
                await MainActor.run {
                    self.controllerNode.showSnackbar(
                        message: DivoStrings.modelSuccessDelete,
                        style: .success
                    )
                    self.loadModels()
                }
            } catch {
                await MainActor.run {
                    self.controllerNode.showSnackbar(
                        message: DivoStrings.genericError,
                        style: .error
                    )
                }
            }
        }
    }

    override public func loadDisplayNode() {
        self.displayNode = PublicProfileScreenNode(
            controller: self,
            context: self.context,
            presentationData: self.presentationData,
            model: model,
            isMyRoleAgency: self.isMyRoleAgency
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

        self.controllerNode.onGalleryItemTapped = { [weak self] tab, itemIndex in
            self?.openFullScreenGallery(tab: tab, itemIndex: itemIndex)
        }

        self.controllerNode.onEditLinksTapped = { [weak self] in
            self?.navigateToEditSocialLinks()
        }

        self.controllerNode.onAddEventTapped = { [weak self] in
            self?.navigateToCreateEvent()
        }
        
        self.controllerNode.onEventButtonTapped = { [weak self] eventId in
            if self?.isMyProfile == true {
                self?.navigateToEditEvent(eventId: eventId)
            } else {
                self?.onEventApplyTapped(eventId: eventId)
            }
        }

        self.controllerNode.onEventDeleteButtonTapped = { [weak self] eventId in
            if self?.isMyProfile == true {
                self?.deleteEvent(eventId: eventId)
            }
        }

        self.controllerNode.onSocialLinkTapped = { [weak self] url in
            self?.openSocialLink(url)
        }

        self.controllerNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.controllerNode.onAddWorkExperienceTapped = { [weak self] in
            self?.navigateToAddWorkExperience()
        }

        self.controllerNode.onGridShareTapped = { [weak self] item, image in
            self?.handleGridShare(item: item, image: image)
        }

        self.controllerNode.onSendDMTapped = { [weak self] in
            self?.openDirectMessage()
        }

        self.controllerNode.onFaceScanTapped = { [weak self] in
            self?.openFaceScanForCurrentProfile()
        }

        self.controllerNode.onReportProfileTapped = { [weak self] in
            self?.presentReportReasons()
        }

        self.controllerNode.onBlockTapped = { [weak self] in
            self?.presentBlockConfirmation()
        }

        self.controllerNode.storiesButtonTapped = { [weak self] in
            self?.openStoryComposer()
        }

        self.controllerNode.onAvatarTapped = { [weak self] in
            self?.openProfileStories()
        }

        self.controllerNode.onEditProfileTapped = { [weak self] index in
            self?.navigateToEditProfile(selectedIndex: index)
        }

        self.controllerNode.onChangeBackgroundTapped = { [weak self] in
            self?.navigateToChangeBackground()
        }

        self.controllerNode.onEditSocialLinksTapped = { [weak self] in
            self?.navigateToEditSocialLinks()
        }

        self.controllerNode.onManageWorkExperienceTapped = { [weak self] in
            self?.navigateToManageExperience()
        }

        self.controllerNode.onAddModelTapped = { [weak self] in
            self?.navigateToAddModel()
        }

        self.controllerNode.onCreateEventTapped = { [weak self] in
            self?.navigateToCreateEvent()
        }

        self.controllerNode.onAddPhotoTapped = { [weak self] fromFAB in
            self?.isUploadFromFAB = fromFAB
            if #available(iOS 14, *) {
                self?.navigateToAddPhoto()
            }
        }
        
        self.controllerNode.onAddVideoTapped = {[weak self] fromFAB in
            self?.isUploadFromFAB = fromFAB
            if #available(iOS 14, *) {
                self?.navigateToAddVideo()
            }
        }

        self.controllerNode.onSimilarProfileTapped = { [weak self] user in
            self?.openSimilarModelScreen(for: user)
        }

        self.controllerNode.onModelAgencyTapped = { [weak self] user in
            self?.openModelAgencyScreen(for: user)
        }

        self.controllerNode.onEventTapped = { [weak self] event in
            self?.openEventDetailScreen(for: event)
        }

        self.controllerNode.onModelDeleteTapped = { [weak self] recordId in
            self?.deleteModelFromAgency(recordId)
        }

        self.displayNodeDidLoad()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
    }

    /// Резолвит teamgram-peer по DIVO telegramId: сперва из Postbox, иначе users.getUsers.
    /// teamgram не валидирует access_hash, поэтому 0 проходит.
    private func resolveTeamgramPeer(telegramId: Int) -> (peerId: PeerId, peer: Signal<EnginePeer?, NoError>) {
        let context = self.context
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64(telegramId)))
        let signal: Signal<EnginePeer?, NoError> = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
            if let peer = peer {
                return .single(peer)
            }
            return context.engine.peers.updatedRemotePeer(peer: .user(id: Int64(telegramId), accessHash: 0))
            |> map { peer -> EnginePeer? in EnginePeer(peer) }
            |> `catch` { _ -> Signal<EnginePeer?, NoError> in .single(nil) }
        }
        return (peerId, signal)
    }

    private func openDirectMessage() {
        guard !self.isOpeningChat, let telegramId = self.userDetailModel?.telegramId else { return }
        self.isOpeningChat = true

        divoTrack(.directMessageStarted(
            sourceUserId: DivoConfig.currentDivoUserId ?? 0,
            targetUserId: Int64(model.userId ?? 0)
        ))

        self.openChatDisposable.set((self.resolveTeamgramPeer(telegramId: telegramId).peer
        |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
            guard let self = self else { return }
            self.isOpeningChat = false
            guard let peer = peer else {
                divoLog("openDirectMessage: не удалось получить peer для telegramId=\(telegramId)", level: .error)
                self.controllerNode.showSnackbar(message: DivoStrings.failedToOpenChat, style: .error)
                return
            }
            guard let navigationController = self.navigationController as? NavigationController else { return }
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: self.context,
                chatLocation: .peer(peer)
            ))
        }))
    }

    private func openStoryComposer() {
        guard let rootController = self.context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface else {
            return
        }
        // animateIn() обязателен — без него камера создаётся, но не показывается (чёрный экран). Как в ModelsFeed.
        // customTarget форсит цель: без него proceedWithStoryUpload подменяет transitionOut на полёт
        // в трей чат-листа, и кружок «улетает» в координаты экрана под профилем
        let coordinator = rootController.openStoryCamera(
            mode: .photo,
            customTarget: .myStories,
            resumeLiveStream: false,
            transitionIn: nil,
            transitionedIn: {},
            transitionOut: { [weak self] target, _ in
                // target == nil — закрытие камеры без постинга, лететь в аватарку не нужно
                guard target != nil, let targetView = self?.controllerNode.storyTransitionTargetView() else {
                    return nil
                }
                return StoryCameraTransitionOut(
                    destinationView: targetView,
                    destinationRect: targetView.bounds,
                    destinationCornerRadius: targetView.bounds.width / 2.0
                )
            }
        )
        coordinator?.animateIn()
    }

    private func openProfileStories() {
        guard let peerId = self.storyPeerId else { return }
        StoryContainerScreen.openPeerStoriesCustom(
            context: self.context,
            peerId: peerId,
            isHidden: false,
            singlePeer: true,
            parentController: self,
            transitionIn: { nil },
            transitionOut: { _ in nil },
            setFocusedItem: { _ in },
            // Сигнал открытия презентует вьюер только когда его подписали — пустой setProgress = вьюер не откроется
            setProgress: { [weak self] signal in
                self?.openStoryProgressDisposable.set(signal.startStrict())
            }
        )
    }

    private func setupStoryRing() {
        if self.isMyProfile {
            self.storyPeerId = self.context.account.peerId
            // Свои сторис — из accountItem, как трей в ленте (ModelsFeedNode)
            self.storyStateDisposable.set((self.context.engine.messages.storySubscriptions(isHidden: false)
            |> deliverOnMainQueue).startStrict(next: { [weak self] subscriptions in
                guard let self = self else { return }
                let item = subscriptions.accountItem
                self.controllerNode.updateStoryRing(hasStories: (item?.storyCount ?? 0) > 0, hasUnseen: item?.hasUnseen ?? false)
            }))
        } else if let telegramId = self.userDetailModel?.telegramId {
            let resolved = self.resolveTeamgramPeer(telegramId: telegramId)
            let peerId = resolved.peerId
            self.storyPeerId = peerId
            self.storyStateDisposable.set((resolved.peer
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                guard let self = self, peer != nil else { return }
                // Кольцо — из реальных сторис (getPeerStories), как PeerInfo. user.stories_max_id
                // не годится: teamgram не сбрасывает его после истечения сторис, кольцо вело в пустоту
                let storyList = PeerExpiringStoryListContext(account: self.context.account, peerId: peerId)
                self.expiringStoryList = storyList
                self.storyListStateDisposable.set((storyList.state
                |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                    guard let self = self else { return }
                    self.controllerNode.updateStoryRing(hasStories: !state.items.isEmpty, hasUnseen: state.hasUnseen)
                }))
            }))
        }
    }

    private func handleGridShare(item: UserDetail?, image: UIImage?) {
        guard let item = item else { return }
        let shareURL = URL(string: "\(DivoConfig.shareBaseURL)/profile/\(item.id)")!
        let shareItem = DivoShareItemSource(
            url: shareURL,
            title: item.fullName ?? "",
            subtitle: item.roleLabel ?? "",
            image: image
        )
        let activityVC = UIActivityViewController(activityItems: [shareItem], applicationActivities: nil)
        self.view.window?.rootViewController?.present(activityVC, animated: true)
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
                    // Шиммер остаётся, скролл/свайп залочены (см.
                    // applyScreenPhase для .failed). Сверху persistent-снекбар
                    // с Retry — единственный путь юзера выйти из failed-стейта.
                    self.controllerNode.markProfileDetailFailed()
                    self.controllerNode.showSnackbar(
                        message: DivoStrings.serverUnavailable,
                        style: .error,
                        retryAction: { [weak self] in
                            guard let self = self else { return }
                            self.controllerNode.hideSnackbar(animated: true)
                            self.controllerNode.resetToInitialLoading()
                            self.profileLoaded = false  // сбрасываем guard, чтобы перезапрос пошёл
                            self.loadInitialData()
                        },
                        persistent: true
                    )
                    return
                }
                self.userDetailModel = detail
                self.controllerNode.updateWithUserDetail(detail, self.isMyProfile)
                self.userID = detail.id
                self.userRole = Role(apiRole: detail.role)
                self.setupStoryRing()
                if let eng = engagement {
                    self.controllerNode.updateEngagementStats(
                        likes: eng.likes,
                        views: eng.views,
                        saves: eng.saves,
                        isLiked: detail.isLikedByUser ?? false,
                        isSaved: detail.isFollowed ?? false
                    )
                }
                self.loadGalleryPage(userId: self.userID, offset: 0)
                self.loadVideoGalleryPage(userId: self.userID, offset: 0)
                if !isMyProfile && userRole != .agency {
                    self.loadSimilarProfiles(photoId: detail.avatar?.photoId)
                }
            }
        }
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
            divoLog("[ENGAGEMENT TOTALS] Error: \(error)", level: .error)
            return nil
        }
    }

    // MARK: - Face Scan

    private func openFaceScanForCurrentProfile() {
        guard let url = self.model.mainImageURL else {
            self.controllerNode.showSnackbar(
                message: DivoStrings.faceRecognitionProfilePhotoLoadFailed,
                style: .error
            )
            return
        }

        FaceSearchPhotoLoader.loadProfilePhoto(
            url: url,
            host: self.view.window?.rootViewController?.view
        ) { [weak self] image in
            guard let self else { return }
            guard let image else {
                self.controllerNode.showSnackbar(
                    message: DivoStrings.faceRecognitionProfilePhotoLoadFailed,
                    style: .error,
                    retryAction: { [weak self] in self?.openFaceScanForCurrentProfile() },
                    persistent: true
                )
                return
            }
            let controller = FaceSearchController(context: self.context, image: image)
            controller.onOpenProfile = { [weak self] result in
                guard let self else { return }
                let next = PublicProfileScreenController(context: self.context, model: ProfileModel(faceSearchResult: result))
                (self.navigationController as? NavigationController)?.pushViewController(next, animated: true)
            }
            (self.navigationController as? NavigationController)?.pushViewController(controller, animated: true)
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
            return DivoStrings.noInternetConnection
        }
        return DivoStrings.genericError
    }

    // Метод для лайка профиля
    func toggleLikeProfile(userId: Int, isLiked: Bool, completion: @escaping (Bool) -> Void) {
        let path = isLiked ? "/feedline/like" : "/feedline/unlike"
        let body = FollowRequest(id: userId)
        
        Task { @MainActor in
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
                completion(true)
            } catch {
                divoLog("[LIKE] Error toggling like for user \(userId): \(error)", level: .error)
                completion(false)
            }
        }
    }
    
    // Метод для подписки/сохранения профиля
    func toggleSaveProfile(userId: Int, isSaved: Bool, completion: @escaping (Bool) -> Void) {
        let path = isSaved ? "/follower/follow" : "/follower/unfollow"
        let body = FollowRequest(id: userId)
        
        Task { @MainActor in
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
                completion(true)
            } catch {
                divoLog("[SAVE/FOLLOW] Error toggling save for user \(userId): \(error)", level: .error)
                completion(false)
            }
        }
    }

    @objc private func handleEventAppliedStatusChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let eventId = userInfo["eventId"] as? Int,
              let isApplied = userInfo["isApplied"] as? Bool else { return }
        
        // Точечно перерисовываем ячейку в Ноде профиля (кэш вкладки обновится автоматически, так как он лежит внутри Node)
        self.controllerNode.updateEventLocally(eventId: eventId, isApplied: isApplied)
    }
}

// MARK: - Helpers
extension PublicProfileScreenController {
    /// Отделяет «нет интернета» от прочих ошибок API. Используется error-ветками
    /// табов, чтобы выбрать соответствующий текст в `ProfileTabErrorView`.
    fileprivate func isNetworkError(_ error: Error) -> Bool {
        if let apiError = error as? DivoAPIError, case .noInternetConnection = apiError {
            return true
        }
        return false
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
                let isNetwork = self.isNetworkError(error)
                await MainActor.run {
                    self.controllerNode.setGalleryLoading(false)
                    // Только на первой странице переводим photoPhase в .failed:
                    // иначе пагинационная ошибка спрячет уже отрендеренный grid.
                    if offset == 0 {
                        self.controllerNode.markPhotoGalleryFailed(networkError: isNetwork)
                    }
                    self.activeGalleryController?.finishLoadingWithoutNewData()
                }
            }
        }
    }

    // Открытие галереи на полный экран
    private func openFullScreenGallery(tab: ProfileTab, itemIndex: Int) {
        divoLog("[GALLERY] Opening full-screen gallery, tab=\(tab), itemIndex=\(itemIndex)")

        guard itemIndex >= 0 else { return }
        let galleryController: ProfileGalleryController

        switch tab {
        case .photo:
            guard !currentGalleryPhotos.isEmpty, itemIndex < currentGalleryPhotos.count else { return }

            galleryController = ProfileGalleryController(
                context: self.context,
                photos: currentGalleryPhotos,
                initialIndex: itemIndex,
                isVideoGallery: false,
                isOwnProfile: self.isMyProfile
            )
        case .video:
            guard !currentGalleryVideos.isEmpty, itemIndex < currentGalleryVideos.count else { return }

            galleryController = ProfileGalleryController(
                context: self.context,
                videos: currentGalleryVideos,
                initialIndex: itemIndex,
                isVideoGallery: true,
                isOwnProfile: self.isMyProfile
            )
        case .models, .channels, .events:
            return
        }

        galleryController.requestMoreData = { [weak self] in
            guard let self = self else { return }
            switch tab {
            case .photo: self.controllerNode.loadNextGalleryPage()
            case .video: self.controllerNode.loadNextVideoGalleryPage()
            case .models, .channels, .events: break
            }
        }

        galleryController.onDeletePublication = { [weak self] deletedId in
            guard let self = self else { return }
            switch tab {
            case .photo:
                self.currentGalleryPhotos.removeAll { $0.id == deletedId }
                self.controllerNode.removePhoto(withId: deletedId)
            case .video:
                self.currentGalleryVideos.removeAll { $0.id == deletedId }
                self.controllerNode.removeVideo(withId: deletedId)
            case .models, .channels, .events: break
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

        let body = GalleryListRequest(offset: offset, limit: 6, userId: userId, type: "video")
        
        Task {
            do {
                let response: UserVideoGalleryResponse = try await DivoAPIClient.shared.request(
                    path: "/publication/list",
                    method: "POST",
                    body: body
                )
                
                await MainActor.run {
                    let videoItems = response.data.items

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
                let isNetwork = self.isNetworkError(error)
                await MainActor.run {
                    controllerNode.videoGalleryRequestDidFail(offset: offset)
                    controllerNode.setVideoGalleryLoading(false)
                    // Только на первой странице переводим videoPhase в .failed —
                    // pagination-ошибка не должна прятать уже отрендеренный grid.
                    if offset == 0 {
                        self.controllerNode.markVideoGalleryFailed(networkError: isNetwork)
                    }
                    self.activeGalleryController?.finishLoadingWithoutNewData()
                }
            }
        }
    }
}

// Загрузка каналов — реальных данных пока нет (нужна интеграция с Telegram MTProto API),
// показываем пустое состояние, как на остальных вкладках.
extension PublicProfileScreenController {
    func loadTelegramChannels() {
        DispatchQueue.main.async { [weak self] in
            self?.controllerNode.updateChannelsList([])
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
                let models = items.compactMap { item -> ModelItem? in
                    guard let userId = item.userId else { return nil }
                    let roleLabel = Role(apiRole: item.role).title
                    return ModelItem(
                        recordId: item.id,
                        userId: userId,
                        name: item.name ?? DivoStrings.noName,
                        role: roleLabel,
                        isPremium: item.isPremium ?? false,
                        customAvatarURL: item.photo?.fullUrl
                    )
                }
                self.controllerNode.updateModelsList(models)
            } catch {
                divoLog("[MODELS] Error: \(error)", level: .error)
                let isNetwork = self.isNetworkError(error)
                self.controllerNode.markModelsFailed(networkError: isNetwork)
            }
        }
    }
}

// Загрузка событий через feedline/search (event/list недоступен для всех ролей)
extension PublicProfileScreenController {
    func loadEvents() {
        self.controllerNode.startLoadEventsList()
        
        let body = EventListRequest(offset: 0, limit: 30, creatorId: userID)
        Task {
            do {
                let response: EventListResponse = try await DivoAPIClient.shared.request(
                    path: "/event/list",
                    method: "POST",
                    body: body
                )

                let items = response.data.items

                if items.isEmpty {
                    await MainActor.run {
                        self.controllerNode.updateEventsList([])
                    }
                    return
                }

                // EventListItem уже содержит все поля для карточки в списке
                // (title/date/address/files), отдельный /event/{id} per item не нужен.
                let eventDataArray: [EventItem] = items.map { item in
                    let (formattedDate, formattedTime) = self.formatEventDateAndTime(dateString: item.date)

                    let city = item.address?.city?.name ?? DivoStrings.unknownCity
                    let flag = self.emojiFlag(from: item.address?.city?.countryCode)

                    let avatarUrl = item.files?.first?.fullUrl
                    let finalAvatarUrl = avatarUrl != nil ? CDNURLHelper.convertToCDNURL(avatarUrl!)?.absoluteString : nil

                    return EventItem(
                        name: item.title ?? DivoStrings.eventFallbackName,
                        data: formattedDate,
                        time: formattedTime,
                        countryFlag: flag,
                        city: city,
                        customAvatarURL: finalAvatarUrl,
                        originalDate: item.date,
                        eventId: item.id,
                        isApplied: item.isApplied,
                        isMyRoleAgency: self.isMyRoleAgency
                    )
                }

                let sortedEvents = eventDataArray.sorted { event1, event2 in
                    guard let date1 = self.parseEventDate(event1.originalDate),
                          let date2 = self.parseEventDate(event2.originalDate) else {
                        return false
                    }
                    return date1 > date2
                }

                await MainActor.run {
                    self.controllerNode.updateEventsList(sortedEvents)
                }

            } catch {
                divoLog("[EVENTS] Error: \(error)", level: .error)
                let isNetwork = self.isNetworkError(error)
                await MainActor.run {
                    self.controllerNode.markEventsFailed(networkError: isNetwork)
                }
            }
        }
    }


    private func deleteEvent(eventId: Int) {
        Task {
            do {
                let _: DeleteEventResponse = try await DivoAPIClient.shared.request(
                    path: "/event/\(eventId)",
                    method: "DELETE"
                )
            } catch {
                await MainActor.run {
                    self.controllerNode.showSnackbar(
                        message: DivoStrings.failedToDelete,
                        style: .error
                    )
                }
                return
            }
            
            await MainActor.run {
                self.loadEvents()
            }
        }
    }
    
    private func formatEventDateAndTime(dateString: String?) -> (date: String, time: String) {
        guard let dateString = dateString else {
            return (DivoStrings.tbd, DivoStrings.tbd)
        }

        let serverFormatter = DateFormatter()
        serverFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = serverFormatter.date(from: dateString) else {
            return (dateString, "")
        }

        let languageCode = Locale.preferredLanguages.first?
            .components(separatedBy: "-")
            .first?
            .lowercased() ?? "en"
        let localeIdentifierByLanguage: [String: String] = [
            "ru": "ru_RU",
            "en": "en_US",
            "pt": "pt_PT",
            "es": "es_ES",
            "zh": "zh_CN"
        ]
        let locale = Locale(identifier: localeIdentifierByLanguage[languageCode] ?? "en_US")

        let dateUIFormatter = DateFormatter()
        dateUIFormatter.locale = locale
        dateUIFormatter.dateFormat = "LLLL d"
        let rawFormattedDate = dateUIFormatter.string(from: date)
        let formattedDate: String = {
            guard let first = rawFormattedDate.first else { return rawFormattedDate }
            return String(first).uppercased(with: locale) + rawFormattedDate.dropFirst()
        }()

        let timeUIFormatter = DateFormatter()
        timeUIFormatter.locale = locale
        switch languageCode {
        case "en":
            timeUIFormatter.dateFormat = "h:mm a"
        case "zh":
            timeUIFormatter.dateFormat = "a h:mm"
        case "ru", "pt", "es":
            timeUIFormatter.dateFormat = "HH:mm"
        default:
            timeUIFormatter.dateFormat = "HH:mm"
        }
        let formattedTime = timeUIFormatter.string(from: date)

        return (formattedDate, formattedTime)
    }
    
    private func parseEventDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else {
            return nil
        }

        let serverFormatter = DateFormatter()
        serverFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFormatter.locale = Locale(identifier: "en_US_POSIX")

        return serverFormatter.date(from: dateString)
    }
    
    private func emojiFlag(from countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2 else { return "🌍" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }
}

// Загрузка лайков, просмотров и созраненок
extension PublicProfileScreenController {
    
    private func presentInteractionSheet(type: InteractionListType) {
        let tabName: String
        switch type {
        case .likes: tabName = "likes"
        case .views: tabName = "views"
        case .saves: tabName = "saves"
        }
        divoTrack(.engagementTabViewed(tabName: tabName, targetUserId: Int(model.userId ?? 0)))

        let sheetVC = InteractionListViewController(type: type, isMyProfile: isMyProfile)
        sheetVC.onUserTapped = { [weak self] user in
            sheetVC.dismiss(animated: true) {
                self?.openModelScreen(for: user)
            }
        }
        
        sheetVC.requestData = { [weak self] offset, search, completion in
            self?.loadInteractionData(type: type, offset: offset, search: search, completion: completion)
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

    private func openModelScreen(for user: InteractionUser) {
        let mainImageURL = user.avatarUrl
            .flatMap { CDNURLHelper.convertToCDNURL($0) }

        let profileModel = ProfileModel(
            name: user.name,
            age: 0,
            location: "",
            isVerified: false,
            likesCount: "0",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            userId: user.id,
            role: user.role,
            mainImageURL: mainImageURL,
            avatarImageURL: mainImageURL
        )
        let detailController = PublicProfileScreenController(context: self.context, model: profileModel)
        (self.navigationController as? NavigationController)?.pushViewController(detailController, animated: true)
    }

    private func openSimilarModelScreen(for user: SimilarProfileItem) {
        let profileModel = ProfileModel(
            name: user.name ?? "",
            age: 0,
            location: "",
            isVerified: false,
            likesCount: "0",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            userId: user.id,
            role: "",
            mainImageURL: user.avatarURL,
            avatarImageURL: user.avatarURL
        )
        let detailController = PublicProfileScreenController(context: self.context, model: profileModel)
        (self.navigationController as? NavigationController)?.pushViewController(detailController, animated: true)
    }

    private func openModelAgencyScreen(for user: ModelItem) {
        let mainImageURL = user.customAvatarURL
            .flatMap { CDNURLHelper.convertToCDNURL($0) }
        
        let profileModel = ProfileModel(
            name: user.name,
            age: 0,
            location: "",
            isVerified: false,
            likesCount: "0",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            userId: user.userId,
            role: user.role,
            mainImageURL: mainImageURL,
            avatarImageURL: mainImageURL
        )
        let detailController = PublicProfileScreenController(context: self.context, model: profileModel)
        (self.navigationController as? NavigationController)?.pushViewController(detailController, animated: true)
    }

    // Точечный асинхронный перезапрос статуса конкретного события
    private func refreshSingleEventState(eventId: Int) {
        Task {
            do {
                let response: EventFullDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/event/\(eventId)",
                    method: "GET"
                )
                guard let detail = response.data else { return }
                
                await MainActor.run {
                    let isApplied = detail.isApplied ?? false
                    
                    // Публикуем уведомление
                    NotificationCenter.default.post(
                        name: DivoConfig.divoEventAppliedStatusChanged,
                        object: nil,
                        userInfo: [
                            "eventId": eventId,
                            "isApplied": isApplied,
                            "appliesCount": detail.appliesCount ?? 0
                        ]
                    )
                    NotificationCenter.default.post(
                        name: DivoConfig.divoEventDataUpdated,
                        object: nil,
                        userInfo: ["eventDetail": detail]
                    )
                }
            } catch {
                divoLog("refreshSingleEventState failed: \(error)", level: .error)
            }
        }
    }
    
    // Логика отклика на эвент через экран Confirmation (Задача 1)
    private func onEventApplyTapped(eventId: Int) {
        let confirmationController = EventApplyConfirmationController(
            context: self.context,
            eventId: eventId,
            eventData: nil // Будет асинхронно загружен внутри самого контроллера
        )
        
        // При успешном отклике плавно обновляем статус этой ячейки локально
        confirmationController.onApplySuccess = { [weak self] in
            guard let self = self else { return }
            self.refreshSingleEventState(eventId: eventId)
        }
        
        self.push(confirmationController)
    }
    
    // Открытие экрана деталей эвента с отслеживанием изменений (Задача 2)
    private func openEventDetailScreen(for event: EventItem) {
        guard let eventId = event.eventId else { return }
        
        let detailController = EventDetailController(context: context, eventId: eventId, isMyEvent: isMyProfile, isAgency: isMyRoleAgency)
        
        // Перехватываем изменения на детальном экране (отклик / отзыв заявки)
        detailController.onEventModified = { [weak self] in
            guard let self = self else { return }
            self.refreshSingleEventState(eventId: eventId)
        }
        
        (self.navigationController as? NavigationController)?.pushViewController(detailController, animated: true)
    }
    
    private func loadInteractionData(type: InteractionListType, offset: Int, search: String? = nil, completion: @escaping (Result<InteractionPage, Error>) -> Void) {
        guard self.userID != -1 else { return }

        let limit = 20
        Task {
            do {
                var path = isMyProfile ? "/user/engagement?offset=\(offset)&limit=\(limit)" : "/user/engagement?offset=\(offset)&limit=\(limit)&userId=\(self.userID)"
                if let search, !search.isEmpty, let encoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    path += "&search=\(encoded)"
                }
                let response: UserEngagementResponse = try await DivoAPIClient.shared.request(path: path, method: "GET")

                var apiItems: [EngagementItem] = []
                var totalCount = 0

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
                        name: item.fullName ?? DivoStrings.noName,
                        role: item.roleLabel ?? item.role ?? DivoStrings.roleFallbackUser,
                        avatarUrl: finalAvatarUrl,
                        isPremium: false
                    )
                }

                let hasMore = (offset + apiItems.count) < totalCount

                await MainActor.run {
                    completion(.success(InteractionPage(users: mappedUsers, hasMore: hasMore)))
                }

            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }

    @objc private func handleEventDataUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let detail = userInfo["eventDetail"] as? EventFullDetailData else { return }
        
        let updatedItem = self.mapDetailToEventItem(detail)
        
        self.controllerNode.updateEventDataLocally(updatedItem)
    }
    
    @objc private func handleEventDeleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let eventId = userInfo["eventId"] as? Int else { return }
        
        self.controllerNode.removeEventLocally(eventId: eventId)
    }
    
    private func mapDetailToEventItem(_ detail: EventFullDetailData) -> EventItem {
        let (formattedDate, formattedTime) = self.formatEventDateAndTime(dateString: detail.date)
        let city = detail.address?.city?.name ?? DivoStrings.unknownCity
        let flag = self.emojiFlag(from: detail.address?.city?.countryCode)
        let avatarUrl = detail.files?.first?.fullUrl
        let finalAvatarUrl = avatarUrl != nil ? CDNURLHelper.convertToCDNURL(avatarUrl!)?.absoluteString : nil
        
        return EventItem(
            name: detail.title ?? DivoStrings.eventFallbackName,
            data: formattedDate,
            time: formattedTime,
            countryFlag: flag,
            city: city,
            customAvatarURL: finalAvatarUrl,
            originalDate: detail.date,
            eventId: detail.id,
            isApplied: detail.isApplied,
            isMyRoleAgency: self.isMyRoleAgency
        )
    }

    @objc private func handleGlobalEventCreated() {
        if self.isMyProfile {
            self.loadEvents()
        }
    }
}

extension PublicProfileScreenController: EditSocialLinksDelegate {
    func didUpdateSocialLinksData() {
        self.profileLoaded = false
        self.loadInitialData()

        self.controllerNode.showSnackbar(
            message: DivoStrings.socialLinksUpdated,
            style: .success
        )
    }
}

extension PublicProfileScreenController: EditProfileDelegate {
    func didUpdateProfileData() {
        self.profileLoaded = false
        self.loadInitialData()

        self.controllerNode.showSnackbar(
            message: DivoStrings.profileUpdated,
            style: .success
        )
    }
}

extension PublicProfileScreenController: AddWorkExperienceDelegate {
    func didUpdateWorkExperience(isEdit: Bool) {
        self.profileLoaded = false
        self.loadInitialData()

        self.controllerNode.showSnackbar(
            message: isEdit ? DivoStrings.workHistoryUpdated : DivoStrings.workHistoryCreate,
            style: .success
        )
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
            if self.isUploadFromFAB {
                self.controllerNode.showUploadOverlay(isPhoto: true)
            } else {
                self.controllerNode.showUploadStatusView(isPhoto: true)
            }
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    guard let self = self, let uiImage = image as? UIImage else { return }
                    self.uploadAndAddPhoto(uiImage)
                }
            }
        case .video:
            if self.isUploadFromFAB {
                self.controllerNode.showUploadOverlay(isPhoto: false)
            } else {
                self.controllerNode.showUploadStatusView(isPhoto: false)
            }
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

                divoTrack(.profileMediaUploaded(mediaType: "photo", targetUserId: Int(model.userId ?? 0)))

                await MainActor.run {
                    if let newPhoto = addResponse.data {
                        self.controllerNode.finishPhotoUpload(photo: newPhoto)
                        self.currentGalleryPhotos.insert(newPhoto, at: 0)
                    } else {
                        self.controllerNode.cancelPhotoUpload()
                        self.galleryLoaded = false
                        self.getUserGalleryProfile()
                    }
                    if self.isUploadFromFAB {
                        self.controllerNode.hideUploadOverlay()
                    } else {
                        self.controllerNode.hideUploadStatusView(isPhoto: true)
                    }
                }

            } catch {
                await MainActor.run {
                    self.controllerNode.cancelPhotoUpload()
                    if self.isUploadFromFAB {
                        self.controllerNode.hideUploadOverlay()
                    } else {
                        self.controllerNode.hideUploadStatusView(isPhoto: true)
                    }
                    self.controllerNode.showSnackbar(
                        message: Self.userFacingMessage(from: error),
                        style: .error
                    )
                }
            }
        }
    }

    private func uploadAndAddVideo(_ videoURL: URL) {
        guard let videoData = try? Data(contentsOf: videoURL) else {
            divoLog("[UPLOAD VIDEO] Failed to read video data", level: .error)
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
                
                divoLog("[UPLOAD VIDEO] File uploaded successfully, uuid: \(fileUuid)")
                
                // FIXME DIVO: заменить хардкод-метаданные на пользовательский ввод (title, description, type)
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

                divoTrack(.profileMediaUploaded(mediaType: "video", targetUserId: Int(model.userId ?? 0)))

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
                if self.isUploadFromFAB {
                    self.controllerNode.hideUploadOverlay()
                } else {
                    self.controllerNode.hideUploadStatusView(isPhoto: false)
                }

                try? FileManager.default.removeItem(at: videoURL)

            } catch {
                await MainActor.run {
                    self.controllerNode.cancelVideoUpload()
                    if self.isUploadFromFAB {
                        self.controllerNode.hideUploadOverlay()
                    } else {
                        self.controllerNode.hideUploadStatusView(isPhoto: false)
                    }
                    self.controllerNode.showSnackbar(
                        message: Self.userFacingMessage(from: error),
                        style: .error
                    )
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

                let request = UpdateBiographyPageRequest(
                    photo: UpdateBiographyPageRequest.AvatarUuid(uuid: fileUuid)
                )
                let _: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )

                self.debugLog("[DivoAPI] Background updated successfully")

                divoTrack(.profileBackgroundChanged)
                divoTrack(.profileMediaUploaded(mediaType: "background", targetUserId: Int(model.userId ?? 0)))

                await MainActor.run {
                    self.controllerNode.setBackgroundLoading(false)
                }
            } catch {
                self.debugLog("[DivoAPI] Upload background error: \(error)")
                await MainActor.run {
                    self.controllerNode.setBackgroundLoading(false)
                    self.controllerNode.showSnackbar(
                        message: DivoStrings.errorUpdateBackground,
                        style: .error
                    )
                }
            }
        }
    }
}

extension PublicProfileScreenController {
    // Загрузка похожих профилей
    func loadSimilarProfiles(photoId: Int?) {
        guard !similarProfilesIsLoading else { return }
        
        similarProfilesIsLoading = true
        
        Task { @MainActor in
            self.controllerNode.setSimilarProfilesLoading(true)
        }
        
        let topK = 6
        let requestBody = SearchSimilarRequest(photoId: photoId, topK: topK)
        
        Task {
            do {
                let response: SearchSimilarResponse = try await DivoAPIClient.shared.request(
                    path: "/fr/searchSimilar",
                    method: "POST",
                    body: requestBody
                )
                
                await MainActor.run {
                    let items = response.results
                    let profiles = items.compactMap { item -> SimilarProfileItem? in
                        guard let userId = item?.userId else { return nil }
                        
                        let imageURL = CDNURLHelper.convertToCDNURL(item?.image)
                                                
                        return SimilarProfileItem(
                            id: userId,
                            name: item?.fullName ?? DivoStrings.noName,
                            age: item?.birthday,
                            countryCode: item?.countryCode,
                            countryName: item?.countryName,
                            avatarURL: imageURL
                        )
                    }
                    
                    self.similarProfilesIsLoading = false
                    
                    self.controllerNode.appendSimilarProfiles(profiles)
                }
            } catch {
                divoLog("[SIMILAR] Error loading similar profiles: \(error)", level: .error)
                await MainActor.run {
                    self.similarProfilesIsLoading = false
                    self.controllerNode.setSimilarProfilesLoading(false)
                }
            }
        }
    }
}

// Жалоба на профиль и блокировка пользователя (меню «…»)
extension PublicProfileScreenController {

    func presentReportReasons() {
        Task { [weak self] in
            do {
                let envelope: DivoEnvelope<[FeedReportType]> = try await DivoAPIClient.shared.request(
                    path: "/dictionary/feed-report-types"
                )
                await MainActor.run {
                    self?.showReportReasonsSheet(types: envelope.data)
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.controllerNode.showSnackbar(
                        message: DivoStrings.reportReasonsLoadFailed,
                        style: .error,
                        retryAction: { [weak self] in self?.presentReportReasons() }
                    )
                }
            }
        }
    }

    private func showReportReasonsSheet(types: [FeedReportType]) {
        let sheet = UIAlertController(title: DivoStrings.reportProfile, message: nil, preferredStyle: .actionSheet)
        for type in types {
            sheet.addAction(UIAlertAction(title: type.title, style: .default) { [weak self] _ in
                self?.sendReport(reportType: type.id)
            })
        }
        sheet.addAction(UIAlertAction(title: DivoStrings.cancel, style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        self.present(sheet, animated: true)
    }

    private func sendReport(reportType: String) {
        guard let feedId = model.feedId else { return }
        let reportedUserId = Int64(model.userId ?? 0)
        Task { [weak self] in
            do {
                let _: FeedReportResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/report",
                    method: "POST",
                    body: FeedReportRequest(feedId: feedId, reportType: reportType)
                )
                divoTrack(.userReported(targetUserId: reportedUserId, reason: reportType))
                await MainActor.run {
                    self?.controllerNode.showSnackbar(message: DivoStrings.reportSent, style: .success)
                }
            } catch {
                await MainActor.run {
                    self?.controllerNode.showSnackbar(message: DivoStrings.reportSendFailed, style: .error)
                }
            }
        }
    }

    func presentBlockConfirmation() {
        guard model.userId != nil else { return }
        let alert = UIAlertController(
            title: DivoStrings.blockUser,
            message: DivoStrings.blockUserConfirmMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: DivoStrings.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: DivoStrings.block, style: .destructive) { [weak self] _ in
            self?.blockUser()
        })
        self.present(alert, animated: true)
    }

    private func blockUser() {
        guard let userId = model.userId else { return }
        Task { [weak self] in
            do {
                let _: BlockUserResponse = try await DivoAPIClient.shared.request(
                    path: "/messenger/block-user",
                    method: "POST",
                    body: BlockUserRequest(recipientId: userId)
                )
                divoTrack(.userBlocked(targetUserId: Int64(userId)))
                await MainActor.run {
                    self?.controllerNode.showSnackbar(message: DivoStrings.userBlocked, style: .success)
                }
            } catch {
                await MainActor.run {
                    self?.controllerNode.showSnackbar(message: DivoStrings.blockUserFailed, style: .error)
                }
            }
        }
    }
}
