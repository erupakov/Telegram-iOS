import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import DivoUIKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import AvatarNode
import LocalizedPeerData

final class ModelsFeedNode: ASDisplayNode, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CardCellDelegate {
    private static let paginationSpinnerHeight: CGFloat = 60

    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData

    private let navBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(34)
        label.textColor = .black
        return label
    }()

    private var floatingAvatars: [UIImageView] = []
    private var floatingNames: [UILabel] = []
    private var wasFullyCollapsed = false
    private var wasFullyExpanded = true

    private var containerLayout: (ContainerViewLayout, CGFloat)?

    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    private var storiesCollectionView: UICollectionView!
    private var mainCollectionView: UICollectionView!

    // Реальная лента сторис через MTProto. Первый элемент всегда — ячейка «+» (всегда видима),
    // дальше идут пиры из storySubscriptions. Строится в `applyStories()`.
    private var storyItems: [StoryModel] = []
    private var storySubscriptionItems: [EngineStorySubscriptions.Item] = []
    private var storyAvatarCache: [EnginePeer.Id: UIImage] = [:]
    private var storySubscriptionsDisposable: Disposable?
    private let storyAvatarDisposables = DisposableSet()

    // Сколько аватаров сторис «улетает» в навбар при сворачивании шапки.
    private let maxNavbarStories = 3

    private var cards: [CardModel] = []

    private var tabTitles: [String] { [DivoStrings.feedSubscribed, DivoStrings.feedAllUsers, DivoStrings.feedAgencies] }
    private var selectedTabIndex = 0

    private let tabsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        return view
    }()

    private lazy var segmentedControl = DivoSegmentedControl(titles: tabTitles)

    private let segmentedControlFadeOverlay: UIView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.cgColor,
                DivoColorPalette.screenBackground.withAlphaComponent(0.0).cgColor
            ]
            gradient.locations = [0.0, 0.45] as [NSNumber]
        }
        return view
    }()

    private var loadingPlaceholderView: UIView?
    private var errorView: UIView?
    private var errorIconCenterYConstraint: NSLayoutConstraint?
    private var errorRetryBottomConstraint: NSLayoutConstraint?
    private var emptyStateView: DivoEmptyStateView?

    var showNetworkError: Bool = false {
        didSet {
            if showNetworkError && cards.isEmpty {
                hideLoadingPlaceholder()
                showErrorState()
            } else {
                hideErrorState()
            }
        }
    }

    private let paginationSpinnerView: UIView = {
        let container = UIView()
        container.isHidden = true
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .black
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }()

    var isPaginating: Bool = false {
        didSet {
            guard oldValue != isPaginating else { return }
            if isPaginating {
                mainCollectionView.contentInset.bottom = Self.paginationSpinnerHeight
                paginationSpinnerView.isHidden = false
                updatePaginationSpinnerFrame()
            } else {
                mainCollectionView.contentInset.bottom = 0
                paginationSpinnerView.isHidden = true
            }
        }
    }

    private func updatePaginationSpinnerFrame() {
        let width = mainCollectionView.bounds.width
        let lastIndex = cards.count - 1
        let y: CGFloat
        if lastIndex >= 0,
           let attrs = mainCollectionView.layoutAttributesForItem(at: IndexPath(item: lastIndex, section: 0)) {
            y = attrs.frame.maxY
        } else {
            y = mainCollectionView.contentSize.height
        }
        paginationSpinnerView.frame = CGRect(
            x: 0,
            y: y,
            width: width,
            height: Self.paginationSpinnerHeight
        )
    }

    var isLoading: Bool = false {
        didSet {
            if isLoading && cards.isEmpty {
                showLoadingPlaceholder()
                hideEmptyState()
                hideErrorState()
            } else {
                hideLoadingPlaceholder()
            }
        }
    }

    var showProfile: ((CardModel) -> Void)?
    var showGallery: ((CardModel, Int) -> Void)?
    var loadMore: (() -> Void)?
    var onTabSelected: ((Int) -> Void)?
    var onRetry: (() -> Void)?
    var onPaginationRetry: (() -> Void)?
    var onOpenStory: ((EnginePeer.Id, [EnginePeer.Id]) -> Void)?
    var onAddStory: (() -> Void)?

    func updateCards(_ newCards: [CardModel], animated: Bool = false) {
        self.cards = newCards
        self.isPaginating = false
        if animated {
            mainCollectionView.alpha = 0
            mainCollectionView.reloadData()
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
                self.mainCollectionView.alpha = 1
            }
        } else {
            mainCollectionView.reloadData()
        }
        if !newCards.isEmpty {
            hideLoadingPlaceholder()
            hideEmptyState()
        }
    }

    func showEmptyStateIfNeeded() {
        if cards.isEmpty && !isLoading && !showNetworkError {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }

    func appendCards(_ newCards: [CardModel]) {
        guard !newCards.isEmpty else { return }
        let startIndex = cards.count

        guard mainCollectionView.window != nil else {
            cards.append(contentsOf: newCards)
            mainCollectionView.reloadData()
            updatePaginationSpinnerFrame()
            return
        }

        let indexPaths = (startIndex..<startIndex + newCards.count).map { IndexPath(item: $0, section: 0) }
        mainCollectionView.performBatchUpdates({
            self.cards.append(contentsOf: newCards)
            self.mainCollectionView.insertItems(at: indexPaths)
        }, completion: { [weak self] _ in
            self?.updatePaginationSpinnerFrame()
        })
    }
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData

        super.init()

        let storiesFlowLayout = UICollectionViewFlowLayout()
        storiesFlowLayout.scrollDirection = .horizontal
        storiesFlowLayout.minimumInteritemSpacing = 10
        storiesFlowLayout.minimumLineSpacing = 0
        storiesFlowLayout.sectionInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        storiesFlowLayout.headerReferenceSize = .zero
        storiesFlowLayout.footerReferenceSize = .zero

        self.storiesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: storiesFlowLayout)
        self.storiesCollectionView.backgroundColor = DivoColorPalette.screenBackground
        self.storiesCollectionView.dataSource = self
        self.storiesCollectionView.delegate = self
        self.storiesCollectionView.showsHorizontalScrollIndicator = false
        self.storiesCollectionView.delaysContentTouches = false
        self.storiesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            self.storiesCollectionView.contentInsetAdjustmentBehavior = .never
        }
        self.storiesCollectionView.contentInset = .zero
        self.storiesCollectionView.register(StoryCollectionViewCell.self, forCellWithReuseIdentifier: "StoryCell")

        let mainFlowLayout = UICollectionViewFlowLayout()

        self.mainCollectionView = UICollectionView(frame: .zero, collectionViewLayout: mainFlowLayout)
        self.mainCollectionView.backgroundColor = DivoColorPalette.screenBackground
        self.mainCollectionView.dataSource = self
        self.mainCollectionView.delegate = self
        self.mainCollectionView.translatesAutoresizingMaskIntoConstraints = false
        self.mainCollectionView.delaysContentTouches = false
        self.mainCollectionView.canCancelContentTouches = true
        self.mainCollectionView.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.mainCollectionView.contentInsetAdjustmentBehavior = .never
        }
        self.mainCollectionView.register(CardCollectionViewCell.self, forCellWithReuseIdentifier: "CardCell")
        self.mainCollectionView.addSubview(self.paginationSpinnerView)

        self.titleLabel.text = DivoStrings.navModels

        self.view.addSubview(self.mainCollectionView)
        self.view.addSubview(self.navBackgroundView)
        self.view.addSubview(self.storiesCollectionView)
        self.view.addSubview(self.segmentedControlFadeOverlay)
        self.view.addSubview(self.tabsContainerView)
        self.navBackgroundView.addSubview(self.titleLabel)

        // Segmented control tabs
        tabsContainerView.addSubview(segmentedControl)
        segmentedControl.onTabSelected = { [weak self] index in
            guard let self = self else { return }
            self.selectedTabIndex = index
            self.hideEmptyState()
            self.onTabSelected?(index)
        }

        self.applyStories()
        self.mainCollectionView.reloadData()

        self.didSetReady = true
        self._ready.set(true)
        self.setupStorySubscription()
        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.titleLabel.text = DivoStrings.navModels
            self.segmentedControl.updateTitles(self.tabTitles)
            if let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
            self.applyStories()
            self.mainCollectionView.reloadData()
        }
    }

    deinit {
        self.storySubscriptionsDisposable?.dispose()
        self.storyAvatarDisposables.dispose()
    }

    // MARK: - Stories (MTProto)

    // Подписка на ленту сторис. Сервер часто отдаёт пусто — тогда в трее остаётся только «+».
    private func setupStorySubscription() {
        self.storySubscriptionsDisposable = (self.context.engine.messages.storySubscriptions(isHidden: false)
        |> deliverOnMainQueue).startStrict(next: { [weak self] subscriptions in
            guard let self = self else { return }
            var items: [EngineStorySubscriptions.Item] = []
            // Свои сторис (если есть) — первым пиром после «+».
            if let accountItem = subscriptions.accountItem, accountItem.storyCount > 0 {
                items.append(accountItem)
            }
            items.append(contentsOf: subscriptions.items)
            self.storySubscriptionItems = items
            self.loadStoryAvatars(for: items)
            self.applyStories()
        })
    }

    // Аватары пиров грузятся через AvatarNode и кладутся в кэш; при готовности — точечное обновление
    // (без полной перестройки трея, чтобы не мигало при потоковой загрузке).
    private func loadStoryAvatars(for items: [EngineStorySubscriptions.Item]) {
        for item in items {
            let peerId = item.peer.id
            guard self.storyAvatarCache[peerId] == nil else { continue }
            let signal = peerAvatarCompleteImage(account: self.context.account, peer: item.peer, size: CGSize(width: 60.0, height: 60.0))
            let disposable = (signal
            |> deliverOnMainQueue).startStrict(next: { [weak self] image in
                guard let self = self, let image = image else { return }
                self.storyAvatarCache[peerId] = image
                self.updateStoryAvatar(peerId: peerId, image: image)
            })
            self.storyAvatarDisposables.add(disposable)
        }
    }

    // Обновляет аватар одной ячейки/floating-вью на месте — индексы storyItems и floatingAvatars совпадают.
    private func updateStoryAvatar(peerId: EnginePeer.Id, image: UIImage) {
        guard let index = storyItems.firstIndex(where: { $0.peerId == peerId }) else { return }
        let old = storyItems[index]
        storyItems[index] = StoryModel(name: old.name, avatar: image, isLive: old.isLive, isAdd: old.isAdd, peerId: old.peerId, hasUnseen: old.hasUnseen)
        if index < floatingAvatars.count {
            floatingAvatars[index].image = image
        }
        if let cell = storiesCollectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? StoryCollectionViewCell {
            cell.configure(with: storyItems[index])
        }
    }

    // Собирает модель трея: всегда «+» первым, затем пиры сторис. Перестраивает трей и floating-аватары.
    private func applyStories() {
        var models: [StoryModel] = [
            StoryModel(name: DivoStrings.addStory, avatar: nil, isLive: false, isAdd: true)
        ]
        let ownPeerId = self.context.account.peerId
        for item in storySubscriptionItems {
            let isOwn = item.peer.id == ownPeerId
            models.append(StoryModel(
                name: isOwn ? DivoStrings.yourStory : item.peer.compactDisplayTitle,
                avatar: storyAvatarCache[item.peer.id],
                isLive: item.hasLiveItems,
                isAdd: false,
                peerId: item.peer.id,
                hasUnseen: item.hasUnseen
            ))
        }
        self.storyItems = models
        self.storiesCollectionView.reloadData()
        self.rebuildFloatingViews()
        self.updateHeaderLayout()
    }

    // Floating-аватары шапки строятся из актуального storyItems (count динамический).
    private func rebuildFloatingViews() {
        for view in floatingAvatars { view.removeFromSuperview() }
        for view in floatingNames { view.removeFromSuperview() }
        floatingAvatars.removeAll()
        floatingNames.removeAll()

        for story in storyItems {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.layer.masksToBounds = true
            iv.layer.borderColor = DivoColorPalette.cardBackground.cgColor
            iv.layer.borderWidth = 0
            iv.backgroundColor = DivoColorPalette.avatarPlaceholderCool
            iv.alpha = 0
            if let isAdd = story.isAdd, isAdd {
                iv.backgroundColor = DivoColorPalette.cardBackground
                iv.contentMode = .center
                let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                iv.image = UIImage(systemName: "plus", withConfiguration: config)
                iv.tintColor = DivoColorPalette.primaryText
            } else if let img = story.avatar {
                iv.image = img
            }
            floatingAvatars.append(iv)

            let label = UILabel()
            label.text = story.name
            label.font = Font.regular(12.0)
            label.textAlignment = .center
            label.alpha = 0
            floatingNames.append(label)
        }

        for av in floatingAvatars { self.view.addSubview(av) }
        for lbl in floatingNames { self.view.addSubview(lbl) }

        // Динамические оверлеи должны остаться над floating-аватарами.
        if let placeholder = loadingPlaceholderView { self.view.bringSubviewToFront(placeholder) }
        if let error = errorView { self.view.bringSubviewToFront(error) }
        snackbar.bringToFront()
    }

    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    private let storiesHeight: CGFloat = 90
    private let tabsHeight: CGFloat = 32
    private let feedTopInset: CGFloat = 10
    private let fadeOverlayHeight: CGFloat = 50

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)

        if let emptyStateView = self.emptyStateView {
            let topOffset = navigationBarHeight + storiesHeight + tabsHeight
            emptyStateView.frame = CGRect(x: 0, y: topOffset, width: layout.size.width, height: layout.size.height - topOffset)
        }

        let insets = layout.insets(options: [.input])
        let safeAreaInsets = layout.safeInsets

        self.mainCollectionView.frame = CGRect(origin: .zero, size: layout.size)

        if #available(iOS 11.0, *) {
            self.storiesCollectionView.contentInsetAdjustmentBehavior = .never
        }
        self.storiesCollectionView.contentInset = .zero
        self.storiesCollectionView.scrollIndicatorInsets = .zero

        let segmentHPadding: CGFloat = 16 + layout.safeInsets.left
        let segmentWidth = layout.size.width - segmentHPadding * 2
        let segmentHeight = tabsHeight
        segmentedControl.frame = CGRect(x: segmentHPadding, y: 4, width: segmentWidth, height: segmentHeight)

        let headerHeight = navigationBarHeight + storiesHeight + tabsHeight

        if let mainFlowLayout = self.mainCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cardHPadding: CGFloat = 16
            mainFlowLayout.sectionInset = UIEdgeInsets(top: headerHeight + 8,
                                                       left: safeAreaInsets.left + cardHPadding,
                                                       bottom: insets.bottom + 16,
                                                       right: safeAreaInsets.right + cardHPadding)

            let cardWidth = layout.size.width - safeAreaInsets.left - safeAreaInsets.right - cardHPadding * 2
            mainFlowLayout.itemSize = CGSize(width: cardWidth, height: 512)
            mainFlowLayout.minimumLineSpacing = 10
        }

        self.mainCollectionView.contentInset = UIEdgeInsets(
            top: feedTopInset,
            left: 0,
            bottom: isPaginating ? Self.paginationSpinnerHeight : 0,
            right: 0
        )
        if isPaginating {
            updatePaginationSpinnerFrame()
        }

        updateHeaderLayout()
        layoutLoadingPlaceholder()
        layoutErrorState()
        snackbar.updateBottomInset(layout.intrinsicInsets.bottom + 16)
    }

    private func updateHeaderLayout() {
        guard let (layout, navigationBarHeight) = containerLayout else { return }

        // White background behind navbar area
        navBackgroundView.frame = CGRect(x: 0, y: 0, width: layout.size.width, height: navigationBarHeight)

        titleLabel.sizeToFit()
        let titleX: CGFloat = 16 + layout.safeInsets.left
        let titleY: CGFloat = navigationBarHeight - titleLabel.frame.height - 10
        let titleH: CGFloat = ceil(titleLabel.frame.height) + 6 // +4pt top / +2pt bottom for CJK
        titleLabel.frame = CGRect(x: titleX, y: titleY - 4, width: ceil(titleLabel.frame.width), height: titleH)

        let scrollOffset = max(mainCollectionView.contentOffset.y, 0)
        let p = min(scrollOffset / storiesHeight, 1.0)

        // --- Stories collection: fade out, floating avatars replace ---
        storiesCollectionView.transform = .identity
        storiesCollectionView.frame = CGRect(
            x: 0,
            y: navigationBarHeight - scrollOffset,
            width: layout.size.width,
            height: storiesHeight
        )
        storiesCollectionView.alpha = max(1 - p * 20, 0)  // gone by 5%

        // --- Two-phase floating avatar animation ---
        // Phase 1 (p 0→0.5): all 5 shrink to ~82%, spacing 10→0, names fade, cluster together
        // Phase 2 (p 0.5→1.0): avatars 0,4 fade out, remaining 3 fly to navbar

        let phase1 = min(p / 0.5, 1.0)          // 0→1 during first half
        let phase2 = max((p - 0.5) / 0.5, 0.0)  // 0→1 during second half

        let cellWidth: CGFloat = 70
        let origSpacing: CGFloat = 10
        let leftInset: CGFloat = 15
        let fullSize: CGFloat = 60
        let count = CGFloat(floatingAvatars.count)

        // Phase 1: shrink and cluster
        let phase1Size = fullSize * (1 - phase1 * 0.18)          // 60 → ~49
        let phase1Spacing = origSpacing * (1 - phase1)            // 10 → 0
        let phase1CellW = phase1Size + phase1Spacing
        let phase1TotalW = count * phase1Size + (count - 1) * phase1Spacing

        // Keep centered around original center
        let origTotalW = count * (cellWidth + origSpacing) - origSpacing
        let origCenterX = leftInset + origTotalW / 2
        let phase1StartX = origCenterX - phase1TotalW / 2
        let phase1Y = navigationBarHeight  // top of stories area

        // Phase 2 endpoints: 3 avatars in navbar
        let navSize: CGFloat = 28
        let navOverlap: CGFloat = 8
        let navBaseX = titleLabel.frame.maxX + 12
        let navY = navigationBarHeight - navSize - 17

        // «+» (индекс 0) всегда долетает до навбара и остаётся видимой — как кнопка добавления в чатах.
        // За ней — первые до maxNavbarStories пиров сторис.
        var survivors: Set<Int> = floatingAvatars.isEmpty ? [] : [0]
        if floatingAvatars.count > 1 {
            survivors.formUnion((1..<floatingAvatars.count).prefix(maxNavbarStories))
        }

        let floatingVisible = min(max((p - 0.05) * 20, 0), 1.0)  // visible after 5%, full by 10%

        var survivorIdx = 0
        for (i, av) in floatingAvatars.enumerated() {
            let isSurvivor = survivors.contains(i)

            // Phase 1 position (all 5 clustered)
            let p1X = phase1StartX + CGFloat(i) * phase1CellW
            let p1Y = phase1Y
            let p1Size = phase1Size

            if phase2 <= 0 {
                // Pure phase 1
                av.frame = CGRect(x: p1X, y: p1Y, width: p1Size, height: p1Size)
                av.layer.cornerRadius = p1Size / 2
                av.alpha = floatingVisible
                av.layer.borderWidth = 0
            } else if isSurvivor {
                // Phase 2: interpolate from clustered position to navbar
                let endX = navBaseX + CGFloat(survivorIdx) * (navSize - navOverlap)
                let curX = p1X + (endX - p1X) * phase2
                let curY = p1Y + (navY - p1Y) * phase2
                let curSize = p1Size + (navSize - p1Size) * phase2

                av.frame = CGRect(x: curX, y: curY, width: curSize, height: curSize)
                av.layer.cornerRadius = curSize / 2
                av.alpha = 1
                av.layer.borderWidth = min(phase2 * 3, 1.5)
                survivorIdx += 1
            } else {
                // Phase 2: non-survivors fade out in place
                av.frame = CGRect(x: p1X, y: p1Y, width: p1Size, height: p1Size)
                av.layer.cornerRadius = p1Size / 2
                av.alpha = max(1 - phase2 * 3, 0)  // fade out quickly
                av.layer.borderWidth = 0
            }
        }

        // Names: fade out during phase 1
        for (i, lbl) in floatingNames.enumerated() {
            let p1X = phase1StartX + CGFloat(i) * phase1CellW
            let avatarBottom = floatingAvatars[i].frame.maxY
            lbl.frame = CGRect(x: p1X - 5, y: avatarBottom + 4, width: phase1Size + 10, height: 14)
            lbl.alpha = floatingVisible * max(1 - phase1 * 2.5, 0)  // gone by 40% of phase1 (~20% total)
        }

        // --- Haptic feedback at endpoints ---
        if p >= 1.0 && !wasFullyCollapsed {
            wasFullyCollapsed = true
            wasFullyExpanded = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else if p <= 0.0 && !wasFullyExpanded {
            wasFullyExpanded = true
            wasFullyCollapsed = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else if p > 0.0 && p < 1.0 {
            wasFullyCollapsed = false
            wasFullyExpanded = false
        }

        // --- Tabs: stick to navbar bottom ---
        let tabsY = max(navigationBarHeight, navigationBarHeight + storiesHeight - scrollOffset)
        tabsContainerView.frame = CGRect(
            x: 0,
            y: tabsY,
            width: layout.size.width,
            height: tabsHeight
        )

        // --- Fade overlay: under tabs ---
        self.segmentedControlFadeOverlay.frame = CGRect(
            x: 0,
            y: tabsY + tabsHeight,
            width: layout.size.width,
            height: fadeOverlayHeight
        )
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === storiesCollectionView {
            return storyItems.count
        } else if collectionView === mainCollectionView {
            return cards.count
        }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if collectionView === storiesCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StoryCell", for: indexPath) as? StoryCollectionViewCell else {
                fatalError("Unable to dequeue StoryCollectionViewCell")
            }
            cell.configure(with: storyItems[indexPath.item])
            return cell

        } else if collectionView === mainCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CardCell", for: indexPath) as? CardCollectionViewCell else {
                fatalError("Unable to dequeue CardCollectionViewCell")
            }

            let card = cards[indexPath.item]
            cell.configure(with: card, delegate: self)

            return cell
        }

        return UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        if collectionView === storiesCollectionView {
            return CGSize(width: 70, height: 90)

        } else if collectionView === mainCollectionView {
            if let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout {
                return flowLayout.itemSize
            }
        }

        return .zero
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === storiesCollectionView {
            guard indexPath.item < storyItems.count else { return }
            let story = storyItems[indexPath.item]
            if story.isAdd == true {
                onAddStory?()
            } else if let peerId = story.peerId {
                onOpenStory?(peerId, storySubscriptionItems.map { $0.peer.id })
            }
        } else if collectionView === mainCollectionView {
            guard indexPath.item < cards.count else { return }
            showProfile?(cards[indexPath.item])
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === mainCollectionView else { return }

        updateHeaderLayout()

        if !cards.isEmpty {
            let threshold: CGFloat = 500
            let contentOffsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let frameHeight = scrollView.frame.height
            if contentOffsetY + frameHeight + threshold > contentHeight {
                loadMore?()
            }
        }
    }

    private func cardIndex(forUserId userId: Int) -> Int? {
        cards.firstIndex(where: { $0.userId == userId })
    }

    private func cardIndex(forFeedId feedId: Int) -> Int? {
        cards.firstIndex(where: { $0.feedId == feedId })
    }

    func cardCell(_ cell: CardCollectionViewCell, didTapSaveForUserId userId: Int, isSaved: Bool) {
        guard let idx = cardIndex(forUserId: userId) else { return }

        let removeFromFeed = !isSaved && self.selectedTabIndex == 0
        var removedCard: CardModel?

        self.cards[idx].isFollowed = isSaved
        self.cards[idx].savesCount = max(0, self.cards[idx].savesCount + (isSaved ? 1 : -1))

        if removeFromFeed {
            removedCard = self.cards[idx]
            self.cards.remove(at: idx)
            self.mainCollectionView.deleteItems(at: [IndexPath(item: idx, section: 0)])
        }

        let path = isSaved ? "/follower/follow" : "/follower/unfollow"
        let body = FollowRequest(id: userId)

        Task { @MainActor in
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
            } catch {
                if removeFromFeed, var card = removedCard {
                    card.isFollowed = true
                    card.savesCount = max(0, card.savesCount + 1)
                    let insertIdx = min(idx, self.cards.count)
                    self.cards.insert(card, at: insertIdx)
                    self.mainCollectionView.insertItems(at: [IndexPath(item: insertIdx, section: 0)])
                } else if let currentIdx = self.cardIndex(forUserId: userId) {
                    self.cards[currentIdx].isFollowed = !isSaved
                    self.cards[currentIdx].savesCount = max(0, self.cards[currentIdx].savesCount + (isSaved ? -1 : 1))
                    let ip = IndexPath(item: currentIdx, section: 0)
                    if let cell = self.mainCollectionView.cellForItem(at: ip) as? CardCollectionViewCell {
                        cell.rollbackSave(isSaved: !isSaved, savesCount: self.cards[currentIdx].savesCount)
                    }
                }
            }
        }
    }

    func cardCell(_ cell: CardCollectionViewCell, didTapLikeForFeedId feedId: Int, isLiked: Bool) {
        guard let idx = cardIndex(forFeedId: feedId) else { return }
        self.cards[idx].isLiked = isLiked
        self.cards[idx].likesCount = max(0, self.cards[idx].likesCount + (isLiked ? 1 : -1))

        let path = isLiked ? "/feedline/like" : "/feedline/unlike"
        // FollowRequest reused: like API expects same {id} body format
        let body = FollowRequest(id: feedId)

        Task { @MainActor in
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
            } catch {
                if let currentIdx = self.cardIndex(forFeedId: feedId) {
                    self.cards[currentIdx].isLiked = !isLiked
                    self.cards[currentIdx].likesCount = max(0, self.cards[currentIdx].likesCount + (isLiked ? -1 : 1))
                    let ip = IndexPath(item: currentIdx, section: 0)
                    if let cell = self.mainCollectionView.cellForItem(at: ip) as? CardCollectionViewCell {
                        cell.rollbackLike(isLiked: !isLiked, likesCount: self.cards[currentIdx].likesCount)
                    }
                }
            }
        }
    }

    func cardCell(_ cell: CardCollectionViewCell, didTapShareForUserId userId: Int) {
        guard let indexPath = mainCollectionView.indexPath(for: cell) else { return }
        let idx = indexPath.item
        guard idx < self.cards.count else { return }
        let card = self.cards[idx]

        let shareURL = URL(string: "\(DivoConfig.shareBaseURL)/profile/\(userId)")!
        let shareItem = DivoShareItemSource(
            url: shareURL,
            title: card.name,
            subtitle: card.role ?? "",
            image: cell.coverImage
        )
        let activityVC = UIActivityViewController(activityItems: [shareItem], applicationActivities: nil)
        controller?.view.window?.rootViewController?.present(activityVC, animated: true)
    }

    func cardCell(_ cell: CardCollectionViewCell, didTapPreviewAtIndex index: Int) {
        guard let indexPath = mainCollectionView.indexPath(for: cell) else { return }
        let idx = indexPath.item
        guard idx < cards.count else { return }
        showGallery?(cards[idx], index)
    }

    // MARK: - Loading Placeholder (Skeleton Shimmer)

    private func showLoadingPlaceholder() {
        guard loadingPlaceholderView == nil else { return }

        let placeholder = UIView()
        placeholder.backgroundColor = .white
        placeholder.clipsToBounds = true
        placeholder.layer.cornerRadius = 32 // TODO: DS alignment — не в шкале Radius

        let cardShimmer = ShimmerView()
        cardShimmer.layer.cornerRadius = 0
        cardShimmer.layer.masksToBounds = true
        cardShimmer.tag = 100
        placeholder.addSubview(cardShimmer)

        // Name line (top-left)
        let nameLine = ShimmerView()
        nameLine.layer.cornerRadius = 6 // TODO: DS alignment — не в шкале Radius
        nameLine.layer.masksToBounds = true
        nameLine.tag = 101
        placeholder.addSubview(nameLine)

        // Badge line (below name)
        let badgeLine = ShimmerView()
        badgeLine.layer.cornerRadius = 6 // TODO: DS alignment — не в шкале Radius
        badgeLine.layer.masksToBounds = true
        badgeLine.tag = 102
        placeholder.addSubview(badgeLine)

        // Stat pills (top-right)
        for i in 0..<3 {
            let stat = ShimmerView()
            stat.layer.cornerRadius = 14 // TODO: DS alignment — не в шкале Radius
            stat.layer.masksToBounds = true
            stat.tag = 110 + i
            placeholder.addSubview(stat)
        }

        // Preview images (bottom)
        for i in 0..<4 {
            let pv = ShimmerView()
            pv.layer.cornerRadius = DivoDesignTokens.Radius.s
            pv.layer.masksToBounds = true
            pv.tag = 120 + i
            placeholder.addSubview(pv)
        }

        self.view.addSubview(placeholder)
        loadingPlaceholderView = placeholder

        layoutLoadingPlaceholder()

        placeholder.subviews.compactMap { $0 as? ShimmerView }.forEach { $0.startShimmer() }

        snackbar.bringToFront()
    }

    private func hideLoadingPlaceholder() {
        guard let placeholder = loadingPlaceholderView else { return }
        UIView.animate(withDuration: 0.25, animations: {
            placeholder.alpha = 0
        }, completion: { _ in
            placeholder.subviews.compactMap { $0 as? ShimmerView }.forEach { $0.stopShimmer() }
            placeholder.removeFromSuperview()
        })
        loadingPlaceholderView = nil
    }

    // MARK: - Error State

    private func showErrorState() {
        guard errorView == nil else { return }

        let container = UIView()
        container.backgroundColor = DivoColorPalette.screenBackground

        let iconView = UIImageView(image: DivoImage.faceSearchError)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = DivoStrings.feedLoadErrorTitle.uppercased()
        titleLabel.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? Font.bold(20)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = DivoStrings.feedLoadErrorSubtitle
        subtitleLabel.font = Font.regular(14)
        subtitleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)

        let retryButton = UIButton(type: .custom)
        retryButton.setTitle(DivoStrings.retry, for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = Font.helveticaNeue(20)
        retryButton.backgroundColor = DivoColorPalette.accent
        retryButton.layer.cornerRadius = 28
        retryButton.addDivoPressState(.primary)
        retryButton.addTarget(self, action: #selector(errorRetryTapped), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(retryButton)

        let iconCenterY = iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -60)
        let retryBottom = retryButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconCenterY,

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),

            retryButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            retryButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
            retryButton.heightAnchor.constraint(equalToConstant: 56),
            retryBottom
        ])

        errorIconCenterYConstraint = iconCenterY
        errorRetryBottomConstraint = retryBottom

        self.view.addSubview(container)
        errorView = container

        layoutErrorState()

        container.alpha = 0
        UIView.animate(withDuration: 0.3) { container.alpha = 1 }
    }

    private func hideErrorState() {
        guard let error = errorView else { return }
        errorView = nil
        errorIconCenterYConstraint = nil
        errorRetryBottomConstraint = nil
        UIView.animate(withDuration: 0.2, animations: {
            error.alpha = 0
        }, completion: { _ in
            error.removeFromSuperview()
        })
    }

    private func layoutErrorState() {
        guard let error = errorView,
              let (layout, navigationBarHeight) = containerLayout else { return }
        let topOffset = navigationBarHeight + storiesHeight + tabsHeight
        let bottomInset = layout.intrinsicInsets.bottom
        error.frame = CGRect(x: 0, y: topOffset, width: layout.size.width, height: layout.size.height - topOffset)

        errorIconCenterYConstraint?.constant = -(bottomInset / 2) - 60
        errorRetryBottomConstraint?.constant = -bottomInset - 24
    }

    @objc private func errorRetryTapped() {
        onRetry?()
    }

    func showPaginationError() {
        isPaginating = false
        showSnackbar(
            message: DivoStrings.feedPaginationError,
            style: .error,
            retryAction: { [weak self] in
                self?.hideSnackbar(animated: true)
                self?.onPaginationRetry?()
            },
            persistent: true
        )
    }



    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        let bottomInset = (containerLayout?.0.intrinsicInsets.bottom ?? 0) + 16
        snackbar.show(
            in: self.view,
            message: message,
            style: style,
            bottomInset: bottomInset,
            retryTitle: retryAction != nil ? DivoStrings.retry : nil,
            retryAction: retryAction,
            persistent: persistent
        )
    }

    func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }

    private func layoutLoadingPlaceholder() {
        guard let placeholder = loadingPlaceholderView,
              let (layout, navigationBarHeight) = containerLayout else { return }

        let topOffset = navigationBarHeight + storiesHeight + tabsHeight + 8 + feedTopInset
        let cardHPadding: CGFloat = 16
        let width = layout.size.width - layout.safeInsets.left - layout.safeInsets.right - cardHPadding * 2
        placeholder.frame = CGRect(x: layout.safeInsets.left + cardHPadding, y: topOffset, width: width, height: 512)

        let w = placeholder.bounds.width
        let h = placeholder.bounds.height

        // Card background
        if let cardShimmer = placeholder.viewWithTag(100) {
            cardShimmer.frame = placeholder.bounds
        }
        // Name (top-left)
        if let name = placeholder.viewWithTag(101) {
            name.frame = CGRect(x: 15, y: 15, width: w * 0.5, height: 22)
        }
        // Badge (below name)
        if let badge = placeholder.viewWithTag(102) {
            badge.frame = CGRect(x: 15, y: 45, width: w * 0.35, height: 18)
        }
        // Stat pills (top-right)
        let statX = w - 15 - 70
        for i in 0..<3 {
            if let stat = placeholder.viewWithTag(110 + i) {
                stat.frame = CGRect(x: statX, y: 15 + CGFloat(i) * 36, width: 70, height: 28)
            }
        }
        // Preview images (bottom)
        let pvY = h - 15 - 100
        let pvSize: CGFloat = 100
        let pvSpacing: CGFloat = 5
        for i in 0..<4 {
            if let pv = placeholder.viewWithTag(120 + i) {
                pv.frame = CGRect(x: 15 + CGFloat(i) * (pvSize + pvSpacing), y: pvY, width: pvSize, height: pvSize)
            }
        }
    }

    // MARK: - Empty State

    private func showEmptyState() {
        guard emptyStateView == nil else { return }

        let config: DivoEmptyStateView.Configuration

        switch selectedTabIndex {
        case 1:
            config = .init(
                style: .smallOnTinted(icon: DivoImage.emptyModelsAgency),
                title: DivoStrings.noNewTalentsTitle,
                subtitle: DivoStrings.noNewTalentsSubtitle
            )
        case 2:
            config = .init(
                style: .smallOnTinted(icon: DivoImage.emptyModelsAgency),
                title: DivoStrings.noAgenciesTitle,
                subtitle: DivoStrings.noAgenciesSubtitle
            )
        default:
            config = .init(
                style: .smallOnTinted(icon: DivoImage.emptyModelsAgency),
                title: DivoStrings.noModelsTitle,
                subtitle: DivoStrings.noModelsSubtitle
            )
        }

        let emptyView = DivoEmptyStateView()
        emptyView.backgroundColor = DivoColorPalette.screenBackground
        emptyView.configure(config)

        self.view.insertSubview(emptyView, belowSubview: self.segmentedControlFadeOverlay)
        emptyStateView = emptyView

        if let (layout, navigationBarHeight) = containerLayout {
            let topOffset = navigationBarHeight + storiesHeight + tabsHeight
            emptyView.frame = CGRect(x: 0, y: topOffset, width: layout.size.width, height: layout.size.height - topOffset)
        }

        emptyView.animateAppearance()
    }

    private func hideEmptyState() {
        guard let empty = emptyStateView else { return }
        emptyStateView = nil
        UIView.animate(withDuration: 0.2, animations: {
            empty.alpha = 0
        }, completion: { _ in
            empty.removeFromSuperview()
        })
    }
}
