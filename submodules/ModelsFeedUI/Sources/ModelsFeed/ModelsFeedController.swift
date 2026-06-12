import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import DivoCore
import DivoUIKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import AppBundle
import LocalizedPeerData
import ContextUI
import TelegramBaseController
import ProfileScreenUI
import DivoGallery
import StoryContainerScreen

public final class ModelsFeedController: TelegramBaseController {
    private var controllerNode: ModelsFeedNode {
        return self.displayNode as! ModelsFeedNode
    }

    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private let context: AccountContext

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    private let peerViewDisposable = MetaDisposable()

    private var isEmpty: Bool?

    private struct TabState {
        var cards: [CardModel] = []
        var offset: Int = 0
        var isLoading: Bool = false
        var hasMore: Bool = true
        var isLoaded: Bool = false
        var hasPaginationError: Bool = false
    }

    private var tabStates: [TabState] = [TabState(), TabState(), TabState()]
    private var selectedTabIndex: Int = 0
    private let feedlinePageSize = 16
    private var tokenChangeObserver: NSObjectProtocol?
    private var roleChangeObserver: NSObjectProtocol?

    private let createActionDisposable = MetaDisposable()
    private let clearDisposable = MetaDisposable()
    private let openStoryProgressDisposable = MetaDisposable()

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let navTheme = NavigationBarTheme(overallDarkAppearance: true, buttonColor: .black, disabledButtonColor: DivoColorPalette.navBarDisabledButtonColor, primaryTextColor: .white, backgroundColor: .clear, opaqueBackgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(theme: navTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))

        let icon: UIImage = DivoImage.iconModels
        self.tabBarItem.title = DivoStrings.tabModels
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon

        updateNavigation()

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
            }
        }).strict()

        self.tokenChangeObserver = NotificationCenter.default.addObserver(
            forName: DivoConfig.tokenDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.tabStates = [TabState(), TabState(), TabState()]
            self.loadFeedline(tabIndex: self.selectedTabIndex, reset: true)
        }
        // DIVO: роль сменилась (рефреш с сервера на cold-start / change-role) БЕЗ смены токена → тоже
        // перезагружаем ленту (контент зависит от роли: agency vs model). roleDidChangeNotification
        // постится только на реальное изменение.
        self.roleChangeObserver = NotificationCenter.default.addObserver(
            forName: DivoConfig.roleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.tabStates = [TabState(), TabState(), TabState()]
            self.loadFeedline(tabIndex: self.selectedTabIndex, reset: true)
        }
        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.tabBarItem.title = DivoStrings.tabModels
            self.tabStates = [TabState(), TabState(), TabState()]
            self.loadFeedline(tabIndex: self.selectedTabIndex, reset: true)
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
    }

    private func updateNavigation() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        let searchImage = Self.makeCircleIcon(systemName: "magnifyingglass")
        let searchButton = UIBarButtonItem(image: searchImage, style: .plain, target: self, action: #selector(self.searchPressed))
        self.navigationItem.rightBarButtonItems = [searchButton]

        self.navigationItem.titleView = UIView()
    }

    private static func makeCircleIcon(systemName: String) -> UIImage? {
        let circleSize: CGFloat = 40
        let padding: CGFloat = 8 // for shadow
        let total = circleSize + padding * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: total, height: total))
        return renderer.image { ctx in
            let gc = ctx.cgContext
            gc.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: DivoColorPalette.shadow.withAlphaComponent(0.1).cgColor)
            gc.setFillColor(UIColor.white.cgColor)
            gc.fillEllipse(in: CGRect(x: padding, y: padding, width: circleSize, height: circleSize))
            gc.setShadow(offset: .zero, blur: 0)
            let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            if let icon = UIImage(systemName: systemName, withConfiguration: config)?.withTintColor(.black, renderingMode: .alwaysOriginal) {
                let iconX = padding + (circleSize - icon.size.width) / 2
                let iconY = padding + (circleSize - icon.size.height) / 2
                icon.draw(at: CGPoint(x: iconX, y: iconY))
            }
        }.withRenderingMode(.alwaysOriginal)
    }

    private var lastContentOffset: CGPoint = .zero

    public func updateContentOffset(offset: CGPoint) {
    }

    @objc private func searchPressed() {
        let searchController = ModelsSearchController(context: self.context)
    
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.pushViewController(searchController, animated: true)
        } else {
            (self.context.sharedContext.mainWindow?.viewController as? NavigationController)?.pushViewController(searchController, animated: true)
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func showProfile(_ model: CardModel) {
        let profileModel = ProfileModel(
            name: model.name,
            age: model.age,
            location: model.country ?? "",
            isVerified: false,
            likesCount: "\(model.likesCount)",
            viewsCount: "\(model.viewsCount)",
            savesCount: "\(model.savesCount)",
            biography: "",
            socialMediaHandles: [],
            galleryImageURLs: [],
            userId: model.userId,
            role: model.role,
            mainImageURL: model.mainImageURL,
            avatarImageURL: model.avatarImageURL,
            feedId: model.feedId
        )
        let detailController = PublicProfileScreenController(context: context, model: profileModel)
        if let nav = self.navigationController as? NavigationController {
            nav.pushViewController(detailController, animated: true)
        } else {
            (self.navigationController as? NavigationController)?.pushViewController(detailController, animated: true)
        }
    }

    private func openGallery(_ model: CardModel, initialIndex: Int) {
        var allURLs: [URL] = []
        if let mainURL = model.mainImageURL {
            allURLs.append(mainURL)
        }
        allURLs.append(contentsOf: model.previewImageURLs)

        guard !allURLs.isEmpty else { return }

        let photos: [UserPhoto] = allURLs.enumerated().map { index, url in
            let file = UserFile(
                fileName: url.lastPathComponent,
                fullUrl: url.absoluteString,
                fileExtension: url.pathExtension,
                fileUuid: nil
            )
            return UserPhoto(id: index, photo: file, likesCount: nil, isLikedByUser: false, preview: nil)
        }

        // Preview images start after main image, so offset by 1
        let galleryIndex = model.mainImageURL != nil ? initialIndex + 1 : initialIndex
        let clampedIndex = min(galleryIndex, photos.count - 1)

        let galleryController = ProfileGalleryController(
            context: self.context,
            photos: photos,
            initialIndex: clampedIndex,
            isOwnProfile: false
        )
        if let nav = self.navigationController as? NavigationController {
            nav.pushViewController(galleryController, animated: true)
        }
    }

    // Открытие полноэкранного вьюера сторис пира (тап по аватару в трее).
    // singlePeer: false — вьюер берёт all-stories контекст (как трей в чатах). Через singlePeer: true
    // своя сторис не открывалась: per-peer контент сервер не отдаёт, а all-stories уже содержит итемы.
    private func openStory(peerId: EnginePeer.Id, order: [EnginePeer.Id]) {
        StoryContainerScreen.openPeerStoriesCustom(
            context: self.context,
            peerId: peerId,
            isHidden: false,
            initialOrder: order,
            singlePeer: false,
            parentController: self,
            transitionIn: { nil },
            transitionOut: { _ in nil },
            setFocusedItem: { _ in },
            // ВАЖНО: сигнал открытия презентует вьюер только когда его подписали — стартуем здесь.
            // Пустой setProgress = вьюер не открывается (сигнал не запущен).
            setProgress: { [weak self] signal in
                self?.openStoryProgressDisposable.set(signal.startStrict())
            }
        )
    }

    // Открытие камеры/композера сторис (тап по «+»).
    private func openStoryComposer() {
        guard let rootController = self.context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface else {
            return
        }
        // animateIn() обязателен — без него камера создаётся, но не показывается (чёрный экран). Как в чат-листе.
        let coordinator = rootController.openStoryCamera(
            mode: .photo,
            customTarget: nil,
            resumeLiveStream: false,
            transitionIn: nil,
            transitionedIn: {},
            transitionOut: { _, _ in return nil }
        )
        coordinator?.animateIn()
    }

    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.peerViewDisposable.dispose()
        self.clearDisposable.dispose()
        self.openStoryProgressDisposable.dispose()
        if let observer = self.tokenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = self.roleChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override public func loadDisplayNode() {
        self.displayNode = ModelsFeedNode(controller: self, context: self.context, presentationData: self.presentationData)
        self.controllerNode.showProfile = { [weak self] model in
            self?.showProfile(model)
        }
        self.controllerNode.showGallery = { [weak self] model, index in
            self?.openGallery(model, initialIndex: index)
        }
        self.controllerNode.loadMore = { [weak self] in
            self?.loadNextPage()
        }
        self.controllerNode.onTabSelected = { [weak self] index in
            self?.switchToTab(index)
        }
        self.controllerNode.onRetry = { [weak self] in
            guard let self = self else { return }
            self.controllerNode.showNetworkError = false
            self.loadFeedline(tabIndex: self.selectedTabIndex, reset: true)
        }
        self.controllerNode.onPaginationRetry = { [weak self] in
            guard let self = self else { return }
            self.tabStates[self.selectedTabIndex].hasPaginationError = false
            self.loadNextPage()
        }
        self.controllerNode.onOpenStory = { [weak self] peerId, order in
            self?.openStory(peerId: peerId, order: order)
        }
        self.controllerNode.onAddStory = { [weak self] in
            self?.openStoryComposer()
        }

        self.displayNodeDidLoad()
        self._ready.set(.single(true))
        loadFeedline(tabIndex: 0, reset: true)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let state = tabStates[selectedTabIndex]
        if !state.isLoaded && !state.isLoading {
            loadFeedline(tabIndex: selectedTabIndex, reset: true)
        }
    }

    private func switchToTab(_ index: Int) {
        guard index != selectedTabIndex else { return }
        selectedTabIndex = index
        tabStates[index].hasPaginationError = false
        let state = tabStates[index]
        controllerNode.hideSnackbar(animated: false)
        controllerNode.updateCards(state.cards, animated: true)
        controllerNode.showNetworkError = false
        controllerNode.isPaginating = false

        if state.isLoading {
            controllerNode.isLoading = true
        } else if !state.isLoaded {
            loadFeedline(tabIndex: index, reset: true)
        } else {
            controllerNode.isLoading = false
            controllerNode.showEmptyStateIfNeeded()
        }
    }

    private func loadNextPage() {
        let index = selectedTabIndex
        let state = tabStates[index]
        guard !state.isLoading, state.hasMore, !state.hasPaginationError else { return }
        loadFeedline(tabIndex: index, reset: false)
    }

    private func requestBody(tabIndex: Int, offset: Int, limit: Int) -> FeedlineListRequest {
        let role: String
        switch tabIndex {
        case 0: role = DivoConfig.UserRole.model.rawValue
        case 1: role = DivoConfig.UserRole.newFace.rawValue
        case 2: role = DivoConfig.UserRole.agency.rawValue
        default: role = DivoConfig.UserRole.model.rawValue
        }
        return FeedlineListRequest(offset: offset, limit: limit, role: role, withoutNfts: true)
    }

    private let maxAutoFetches = 3

    private func loadFeedline(tabIndex: Int, reset: Bool, autoFetchCount: Int = 0) {
        guard !tabStates[tabIndex].isLoading else { return }
        tabStates[tabIndex].isLoading = true

        let isCurrentTab = tabIndex == selectedTabIndex
        if isCurrentTab {
            if reset {
                controllerNode.isLoading = true
                controllerNode.isPaginating = false
            } else if !tabStates[tabIndex].cards.isEmpty {
                controllerNode.isPaginating = true
            }
        }

        if reset {
            tabStates[tabIndex].offset = 0
            tabStates[tabIndex].hasMore = true
            tabStates[tabIndex].hasPaginationError = false
        }

        let offset = tabStates[tabIndex].offset
        let limit = feedlinePageSize
        let body = requestBody(tabIndex: tabIndex, offset: offset, limit: limit)

        Task { [weak self] in
            do {
                let response: FeedlineResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/list",
                    method: "POST",
                    body: body
                )
                let isSubscribedTab = tabIndex == 0
                let profileItems = response.data.items.filter { $0.entity == "users" }
                let cards = profileItems.map { Self.mapCard($0, isFollowed: isSubscribedTab) }
                await MainActor.run {
                    guard let self else { return }
                    if reset {
                        self.tabStates[tabIndex].cards = cards
                    } else {
                        self.tabStates[tabIndex].cards.append(contentsOf: cards)
                    }
                    let totalReceived = response.data.items.count
                    self.tabStates[tabIndex].offset = offset + totalReceived
                    self.tabStates[tabIndex].hasMore = totalReceived >= limit
                    self.tabStates[tabIndex].isLoading = false
                    self.tabStates[tabIndex].isLoaded = true
                    self.tabStates[tabIndex].hasPaginationError = false

                    let isResetCascade = reset || autoFetchCount > 0
                    let willAutoFetch = isResetCascade
                        && cards.count < limit
                        && self.tabStates[tabIndex].hasMore
                        && autoFetchCount < self.maxAutoFetches

                    if tabIndex == self.selectedTabIndex {
                        if reset {
                            self.controllerNode.updateCards(self.tabStates[tabIndex].cards, animated: true)
                        } else {
                            self.controllerNode.appendCards(cards)
                        }
                        if !willAutoFetch || !self.tabStates[tabIndex].cards.isEmpty {
                            self.controllerNode.isLoading = false
                        }
                        self.controllerNode.isPaginating = false
                        self.controllerNode.showNetworkError = false
                    }

                    if willAutoFetch {
                        self.loadFeedline(tabIndex: tabIndex, reset: false, autoFetchCount: autoFetchCount + 1)
                        return
                    }

                    if tabIndex == self.selectedTabIndex {
                        self.controllerNode.isLoading = false
                        self.controllerNode.showEmptyStateIfNeeded()
                    }
                }
            } catch {
                print("[DivoAPI] feedline/list error (tab \(tabIndex)): \(error)")
                await MainActor.run {
                    guard let self else { return }
                    self.tabStates[tabIndex].isLoading = false
                    if !reset {
                        self.tabStates[tabIndex].hasPaginationError = true
                    }
                    if tabIndex == self.selectedTabIndex {
                        self.controllerNode.isLoading = false
                        self.controllerNode.isPaginating = false
                        if reset {
                            self.controllerNode.showNetworkError = true
                        } else {
                            self.controllerNode.showPaginationError()
                        }
                    }
                }
            }
        }
    }

    private static func mapCard(_ item: FeedlineItem, isFollowed: Bool = false) -> CardModel {
        let mainURL = item.files.first.flatMap { URL(string: $0.fullUrl) }
        let avatarURL = item.searchImage.flatMap { URL(string: $0.fullUrl) }
        let previewURLs = item.files.dropFirst().compactMap { URL(string: $0.fullUrl) }
        let flag = CountryHelper.emojiFlag(for: item.user.countryCode ?? item.user.city?.countryCode)
        return CardModel(
            name: item.title ?? item.user.fullName ?? "",
            userId: item.user.id,
            role: item.user.role,
            roleLabel: item.user.roleLabel,
            mainImageURL: mainURL,
            avatarImageURL: avatarURL,
            previewImageURLs: previewURLs,
            likesCount: item.likesCount,
            isFavorite: item.isFavoriteByUser,
            isFollowed: isFollowed,
            feedId: item.feedId,
            isLiked: item.isLikedByUser,
            age: item.user.age,
            country: item.user.countryName ?? item.user.city?.countryName,
            countryFlag: flag.isEmpty ? nil : flag
        )
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
