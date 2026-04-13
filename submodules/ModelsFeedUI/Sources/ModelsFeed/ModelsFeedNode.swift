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

final class ModelsFeedNode: ASDisplayNode, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CardCellDelegate {
    private final class PaginationShimmerCell: UICollectionViewCell {
        private let cardShimmer = ShimmerView()
        private let nameLine = ShimmerView()
        private let badgeLine = ShimmerView()
        private let stat1 = ShimmerView()
        private let stat2 = ShimmerView()
        private let stat3 = ShimmerView()
        private let preview1 = ShimmerView()
        private let preview2 = ShimmerView()
        private let preview3 = ShimmerView()
        private let preview4 = ShimmerView()

        private var allShimmers: [ShimmerView] {
            [cardShimmer, nameLine, badgeLine, stat1, stat2, stat3, preview1, preview2, preview3, preview4]
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .white
            layer.cornerRadius = 32
            layer.masksToBounds = true

            cardShimmer.layer.cornerRadius = 0
            addSubview(cardShimmer)

            for line in [nameLine, badgeLine] {
                line.layer.cornerRadius = 6
                line.layer.masksToBounds = true
                addSubview(line)
            }

            for stat in [stat1, stat2, stat3] {
                stat.layer.cornerRadius = 14
                stat.layer.masksToBounds = true
                addSubview(stat)
            }

            for pv in [preview1, preview2, preview3, preview4] {
                pv.layer.cornerRadius = 8
                pv.layer.masksToBounds = true
                addSubview(pv)
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let w = bounds.width
            let h = bounds.height
            cardShimmer.frame = bounds

            // Name + badge (top-left)
            nameLine.frame = CGRect(x: 15, y: 15, width: w * 0.5, height: 22)
            badgeLine.frame = CGRect(x: 15, y: 45, width: w * 0.35, height: 18)

            // Stats (top-right)
            let statX = w - 15 - 70
            stat1.frame = CGRect(x: statX, y: 15, width: 70, height: 28)
            stat2.frame = CGRect(x: statX, y: 51, width: 70, height: 28)
            stat3.frame = CGRect(x: statX, y: 87, width: 70, height: 28)

            // Previews (bottom)
            let pvY = h - 15 - 100
            let pvSize: CGFloat = 100
            let pvSpacing: CGFloat = 5
            preview1.frame = CGRect(x: 15, y: pvY, width: pvSize, height: pvSize)
            preview2.frame = CGRect(x: 15 + pvSize + pvSpacing, y: pvY, width: pvSize, height: pvSize)
            preview3.frame = CGRect(x: 15 + (pvSize + pvSpacing) * 2, y: pvY, width: pvSize, height: pvSize)
            preview4.frame = CGRect(x: 15 + (pvSize + pvSpacing) * 3, y: pvY, width: pvSize, height: pvSize)
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            allShimmers.forEach { $0.stopShimmer() }
        }

        func setLoading(_ isLoading: Bool) {
            allShimmers.forEach { isLoading ? $0.startShimmer() : $0.stopShimmer() }
        }
    }

    private final class PaginationRetryCell: UICollectionViewCell {
        private let retryButton: UIButton = {
            let button = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            button.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: config), for: .normal)
            button.tintColor = UIColor(white: 0.4, alpha: 1.0)
            return button
        }()

        var onRetry: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .white
            addSubview(retryButton)
            retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func retryTapped() {
            onRetry?()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            retryButton.frame = CGRect(x: (bounds.width - 50) / 2, y: (bounds.height - 50) / 2, width: 50, height: 50)
        }
    }

    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData

    private let navBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoGlassColors.screenBackground
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

    private var stories: [StoryModel] {
        [
            StoryModel(name: DivoStrings.addStory, avatarName: "Components/AddStoryAvatar", isLive: false, isAdd: true),
            StoryModel(name: "Jack D.", avatarName: "Components/image5", isLive: false, isAdd: false),
            StoryModel(name: "Joshua", avatarName: "", isLive: false, isAdd: false),
            StoryModel(name: "waggles", avatarName: "", isLive: true, isAdd: false),
            StoryModel(name: "steve.loves", avatarName: "", isLive: true, isAdd: false),
        ]
    }

    private var cards: [CardModel] = []

    private var tabTitles: [String] { [DivoStrings.feedSubscribed, DivoStrings.feedAllUsers, DivoStrings.feedAgencies] }
    private var selectedTabIndex = 0

    private let tabsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoGlassColors.screenBackground
        return view
    }()

    private let segmentedBackground: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.masksToBounds = true
        return view
    }()

    private let segmentIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = DivoGlassColors.screenBackground
        view.layer.masksToBounds = true
        return view
    }()

    private var tabButtons: [UIButton] = []

    private var loadingPlaceholderView: UIView?
    private var spinnerLoadingView: UIView?
    private var errorView: UIView?
    private var emptyStateView: UIView?

    var showNetworkError: Bool = false {
        didSet {
            if showNetworkError && cards.isEmpty {
                showLoadingPlaceholder()
                showSnackbar(
                    message: DivoStrings.serverUnavailable,
                    style: .error,
                    retryAction: { [weak self] in
                        self?.onRetry?()
                    },
                    persistent: true
                )
            } else {
                hideLoadingPlaceholder()
                hideSnackbar(animated: true)
            }
        }
    }

    var hasPaginationError: Bool = false {
        didSet {
            guard oldValue != hasPaginationError else { return }
            mainCollectionView.reloadData()
        }
    }

    var isPaginating: Bool = false {
        didSet {
            guard oldValue != isPaginating else { return }
            mainCollectionView.reloadData()
        }
    }

    var isLoading: Bool = false {
        didSet {
            if isLoading && cards.isEmpty {
                showSpinnerLoading()
                hideEmptyState()
            } else {
                hideSpinnerLoading()
            }
        }
    }

    var isSpinnerLoading: Bool = false {
        didSet {
            if isSpinnerLoading {
                showSpinnerLoading()
            } else {
                hideSpinnerLoading()
            }
        }
    }

    var showProfile: ((CardModel) -> Void)?
    var showGallery: ((CardModel, Int) -> Void)?
    var loadMore: (() -> Void)?
    var onTabSelected: ((Int) -> Void)?
    var onRetry: (() -> Void)?

    func updateCards(_ newCards: [CardModel], animated: Bool = false) {
        self.cards = newCards
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
        cards.append(contentsOf: newCards)
        let indexPaths = (startIndex..<cards.count).map { IndexPath(item: $0, section: 0) }
        mainCollectionView.performBatchUpdates {
            mainCollectionView.insertItems(at: indexPaths)
        }
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
        storiesFlowLayout.estimatedItemSize = CGSize(width: 70, height: 90)

        self.storiesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: storiesFlowLayout)
        self.storiesCollectionView.backgroundColor = DivoGlassColors.screenBackground
        self.storiesCollectionView.dataSource = self
        self.storiesCollectionView.delegate = self
        self.storiesCollectionView.showsHorizontalScrollIndicator = false
        self.storiesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            self.storiesCollectionView.contentInsetAdjustmentBehavior = .never
        }
        self.storiesCollectionView.contentInset = .zero
        self.storiesCollectionView.register(StoryCollectionViewCell.self, forCellWithReuseIdentifier: "StoryCell")

        let mainFlowLayout = UICollectionViewFlowLayout()

        self.mainCollectionView = UICollectionView(frame: .zero, collectionViewLayout: mainFlowLayout)
        self.mainCollectionView.backgroundColor = DivoGlassColors.screenBackground
        self.mainCollectionView.dataSource = self
        self.mainCollectionView.delegate = self
        self.mainCollectionView.translatesAutoresizingMaskIntoConstraints = false
        self.mainCollectionView.delaysContentTouches = false
        self.mainCollectionView.canCancelContentTouches = true
        self.mainCollectionView.showsVerticalScrollIndicator = false

        self.mainCollectionView.register(CardCollectionViewCell.self, forCellWithReuseIdentifier: "CardCell")
        self.mainCollectionView.register(PaginationShimmerCell.self, forCellWithReuseIdentifier: "PaginationShimmerCell")
        self.mainCollectionView.register(PaginationRetryCell.self, forCellWithReuseIdentifier: "PaginationRetryCell")

        self.titleLabel.text = DivoStrings.navModels

        // Create floating avatars + names for ALL stories (animate 5→3→navbar)
        for i in 0..<stories.count {
            let story = stories[i]

            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.layer.masksToBounds = true
            iv.layer.borderColor = UIColor.white.cgColor
            iv.layer.borderWidth = 0
            iv.backgroundColor = UIColor(red: 0.91, green: 0.91, blue: 0.91, alpha: 1.00)
            iv.alpha = 0
            if let isAdd = story.isAdd, isAdd {
                iv.backgroundColor = .white
                iv.contentMode = .center
                let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                iv.image = UIImage(systemName: "plus", withConfiguration: config)
                iv.tintColor = .black
            } else if let img = UIImage(named: story.avatarName) {
                iv.image = img
            }
            floatingAvatars.append(iv)

            let label = UILabel()
            label.text = story.name
            label.font = .systemFont(ofSize: 12)
            label.textAlignment = .center
            label.alpha = 0
            floatingNames.append(label)
        }

        self.view.addSubview(self.mainCollectionView)
        self.view.addSubview(self.navBackgroundView)
        self.view.addSubview(self.storiesCollectionView)
        self.view.addSubview(self.tabsContainerView)
        for av in floatingAvatars { self.view.addSubview(av) }
        for lbl in floatingNames { self.view.addSubview(lbl) }
        self.navBackgroundView.addSubview(self.titleLabel)

        // Segmented control tabs
        tabsContainerView.addSubview(segmentedBackground)
        segmentedBackground.addSubview(segmentIndicator)

        for (index, title) in tabTitles.enumerated() {
            let button = UIButton(type: .custom)
            button.setAttributedTitle(Self.tabAttributedTitle(title, active: index == 0), for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
            segmentedBackground.addSubview(button)
            tabButtons.append(button)
        }

        self.storiesCollectionView.reloadData()
        self.mainCollectionView.reloadData()

        self.didSetReady = true
        self._ready.set(true)
        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.titleLabel.text = DivoStrings.navModels
            for (index, button) in self.tabButtons.enumerated() {
                if index < self.tabTitles.count {
                    let title = self.tabTitles[index]
                    button.setAttributedTitle(Self.tabAttributedTitle(title, active: index == self.selectedTabIndex), for: .normal)
                }
            }
            if let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
            self.storiesCollectionView.reloadData()
            self.mainCollectionView.reloadData()
        }
    }

    private static func tabAttributedTitle(_ title: String, active: Bool) -> NSAttributedString {
        let font = UIFont(name: "HelveticaNeue-CondensedBold", size: 10) ?? UIFont.systemFont(ofSize: 10, weight: .bold)
        let color: UIColor = active ? .black : UIColor(white: 0.45, alpha: 1.0)
        return NSAttributedString(string: title.uppercased(), attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: 0.5
        ])
    }

    @objc private func tabButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedTabIndex else { return }
        selectedTabIndex = index

        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            self.layoutSegmentIndicator()
        }
        for button in self.tabButtons {
            let isSelected = button.tag == index
            let title = self.tabTitles[button.tag]
            let attributed = Self.tabAttributedTitle(title, active: isSelected)
            UIView.transition(with: button, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                button.setAttributedTitle(attributed, for: .normal)
            }
        }
        if let label = spinnerLoadingView?.viewWithTag(201) as? UILabel {
            label.text = loadingTextForCurrentTab()
        }
        hideEmptyState()
        onTabSelected?(index)
    }

    private func layoutSegmentIndicator() {
        guard selectedTabIndex < tabButtons.count else { return }
        let segBounds = segmentedBackground.bounds
        let tabCount = CGFloat(tabButtons.count)
        let padding: CGFloat = 2
        let segmentWidth = (segBounds.width - padding * 2) / tabCount
        let indicatorX = padding + CGFloat(selectedTabIndex) * segmentWidth

        let indicatorHeight = segBounds.height - padding * 2
        segmentIndicator.frame = CGRect(
            x: indicatorX,
            y: padding,
            width: segmentWidth,
            height: indicatorHeight
        )
        segmentIndicator.layer.cornerRadius = indicatorHeight / 2

        for (i, button) in tabButtons.enumerated() {
            button.frame = CGRect(
                x: padding + CGFloat(i) * segmentWidth,
                y: 0,
                width: segmentWidth,
                height: segBounds.height
            )
        }
    }

    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    private let storiesHeight: CGFloat = 90
    private let tabsHeight: CGFloat = 40

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
        let segmentHeight = tabsHeight - 8
        segmentedBackground.frame = CGRect(x: segmentHPadding, y: 4, width: segmentWidth, height: segmentHeight)
        segmentedBackground.layer.cornerRadius = segmentHeight / 2
        layoutSegmentIndicator()

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

        self.mainCollectionView.contentInset = .zero

        updateHeaderLayout()
        layoutLoadingPlaceholder()
        layoutSpinnerLoading()
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

        // Indices that survive to navbar: 1, 2, 3 (Jack D., Joshua, waggles)
        let survivors: Set<Int> = [1, 2, 3]

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
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === storiesCollectionView {
            return stories.count
        } else if collectionView === mainCollectionView {
            let extra = isPaginating || hasPaginationError ? 1 : 0
            return cards.count + extra
        }
        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if collectionView === storiesCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StoryCell", for: indexPath) as? StoryCollectionViewCell else {
                fatalError("Unable to dequeue StoryCollectionViewCell")
            }
            cell.configure(with: stories[indexPath.item])
            return cell

        } else if collectionView === mainCollectionView {
            if indexPath.item == cards.count {
                if hasPaginationError {
                    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PaginationRetryCell", for: indexPath) as? PaginationRetryCell else {
                        fatalError("Unable to dequeue PaginationRetryCell")
                    }
                    cell.onRetry = { [weak self] in
                        self?.loadMore?()
                    }
                    return cell
                } else {
                    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PaginationShimmerCell", for: indexPath) as? PaginationShimmerCell else {
                        fatalError("Unable to dequeue PaginationShimmerCell")
                    }
                    cell.setLoading(true)
                    return cell
                }
            }

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
            print("didSelectItemAt Story: \(stories[indexPath.item].name)")
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
                self.showSnackbar(
                    message: isSaved ? DivoStrings.subscribed : DivoStrings.unsubscribed,
                    style: .success
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
                self.showSnackbar(
                    message: isSaved ? DivoStrings.subscribeFailed : DivoStrings.unsubscribeFailed,
                    style: .error,
                    retryAction: { [weak self] in
                        guard let self, let currentIdx = self.cardIndex(forUserId: userId) else { return }
                        let ip = IndexPath(item: currentIdx, section: 0)
                        if let cell = self.mainCollectionView.cellForItem(at: ip) as? CardCollectionViewCell {
                            self.cardCell(cell, didTapSaveForUserId: userId, isSaved: isSaved)
                        }
                    }
                )
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
                self.showSnackbar(
                    message: isLiked ? DivoStrings.liked : DivoStrings.unliked,
                    style: .success
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
                self.showSnackbar(
                    message: isLiked ? DivoStrings.likeFailed : DivoStrings.unlikeFailed,
                    style: .error,
                    retryAction: { [weak self] in
                        guard let self, let currentIdx = self.cardIndex(forFeedId: feedId) else { return }
                        let ip = IndexPath(item: currentIdx, section: 0)
                        if let cell = self.mainCollectionView.cellForItem(at: ip) as? CardCollectionViewCell {
                            self.cardCell(cell, didTapLikeForFeedId: feedId, isLiked: isLiked)
                        }
                    }
                )
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
        placeholder.layer.cornerRadius = 32

        let cardShimmer = ShimmerView()
        cardShimmer.layer.cornerRadius = 0
        cardShimmer.layer.masksToBounds = true
        cardShimmer.tag = 100
        placeholder.addSubview(cardShimmer)

        // Name line (top-left)
        let nameLine = ShimmerView()
        nameLine.layer.cornerRadius = 6
        nameLine.layer.masksToBounds = true
        nameLine.tag = 101
        placeholder.addSubview(nameLine)

        // Badge line (below name)
        let badgeLine = ShimmerView()
        badgeLine.layer.cornerRadius = 6
        badgeLine.layer.masksToBounds = true
        badgeLine.tag = 102
        placeholder.addSubview(badgeLine)

        // Stat pills (top-right)
        for i in 0..<3 {
            let stat = ShimmerView()
            stat.layer.cornerRadius = 14
            stat.layer.masksToBounds = true
            stat.tag = 110 + i
            placeholder.addSubview(stat)
        }

        // Preview images (bottom)
        for i in 0..<4 {
            let pv = ShimmerView()
            pv.layer.cornerRadius = 8
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

    // MARK: - Spinner Loading

    private func loadingTextForCurrentTab() -> String {
        switch selectedTabIndex {
        case 1: return DivoStrings.loadingTalentsList
        case 2: return DivoStrings.loadingAgenciesList
        default: return DivoStrings.loadingModelsList
        }
    }

    private func showSpinnerLoading() {
        guard spinnerLoadingView == nil else { return }

        let container = UIView()
        container.backgroundColor = DivoGlassColors.screenBackground

        let spinnerView = DivoSegmentedSpinner(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        spinnerView.tag = 200
        container.addSubview(spinnerView)

        let label = UILabel()
        label.text = loadingTextForCurrentTab()
        label.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .bold)
        label.textColor = UIColor(white: 0.2, alpha: 1.0)
        label.textAlignment = .center
        label.tag = 201
        container.addSubview(label)

        self.view.addSubview(container)
        spinnerLoadingView = container

        layoutSpinnerLoading()

        spinnerView.startAnimating()
    }

    private func hideSpinnerLoading() {
        guard let spinner = spinnerLoadingView else { return }
        UIView.animate(withDuration: 0.25, animations: {
            spinner.alpha = 0
        }, completion: { _ in
            (spinner.viewWithTag(200) as? DivoSegmentedSpinner)?.stopAnimating()
            spinner.removeFromSuperview()
        })
        spinnerLoadingView = nil
    }

    private func layoutSpinnerLoading() {
        guard let spinner = spinnerLoadingView,
              let (layout, navigationBarHeight) = containerLayout else { return }
        let topOffset = navigationBarHeight + storiesHeight + tabsHeight
        spinner.frame = CGRect(x: 0, y: topOffset, width: layout.size.width, height: layout.size.height - topOffset)
        let bottomInset = layout.intrinsicInsets.bottom
        let visibleCenterY = (spinner.bounds.height - bottomInset) / 2.0
        if let icon = spinner.viewWithTag(200) {
            icon.bounds = CGRect(x: 0, y: 0, width: 32, height: 32)
            icon.center = CGPoint(x: spinner.bounds.midX, y: visibleCenterY - 12)
        }
        if let label = spinner.viewWithTag(201) as? UILabel {
            label.sizeToFit()
            label.frame = CGRect(x: 0, y: visibleCenterY + 24, width: spinner.bounds.width, height: 20)
        }
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

    private func hideSnackbar(animated: Bool) {
        snackbar.hide(animated: animated)
    }

    private func layoutLoadingPlaceholder() {
        guard let placeholder = loadingPlaceholderView,
              let (layout, navigationBarHeight) = containerLayout else { return }

        let topOffset = navigationBarHeight + storiesHeight + tabsHeight + 8
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

        let container = UIView()
        container.backgroundColor = .white
        container.alpha = 0

        let circleView = UIView()
        circleView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        circleView.layer.cornerRadius = 40
        circleView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(circleView)

        let iconLabel = UILabel()
        iconLabel.text = selectedTabIndex == 0 ? "♡" : "☰"
        iconLabel.font = .systemFont(ofSize: 32)
        iconLabel.textColor = UIColor(white: 0.4, alpha: 1.0)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        circleView.addSubview(iconLabel)

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.1, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor(white: 0.5, alpha: 1)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)

        switch selectedTabIndex {
        case 0:
            titleLabel.text = DivoStrings.noSubscriptionsYet
            subtitleLabel.text = DivoStrings.noSubscriptionsSubtitle
        case 2:
            titleLabel.text = DivoStrings.noResults
            subtitleLabel.text = DivoStrings.noResultsSubtitle
        default:
            titleLabel.text = DivoStrings.noUsersFound
            subtitleLabel.text = DivoStrings.noUsersFoundSubtitle
        }

        NSLayoutConstraint.activate([
            circleView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -50),
            circleView.widthAnchor.constraint(equalToConstant: 80),
            circleView.heightAnchor.constraint(equalToConstant: 80),

            iconLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
        ])

        self.view.addSubview(container)
        emptyStateView = container

        if let (layout, navigationBarHeight) = containerLayout {
            let topOffset = navigationBarHeight + storiesHeight + tabsHeight
            container.frame = CGRect(x: 0, y: topOffset, width: layout.size.width, height: layout.size.height - topOffset)
        }

        circleView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: []) {
            container.alpha = 1
            circleView.transform = .identity
        }
        UIView.animate(withDuration: 0.35, delay: 0.1, options: [.curveEaseOut]) {
            titleLabel.alpha = 1
            titleLabel.transform = .identity
        }
        UIView.animate(withDuration: 0.35, delay: 0.15, options: [.curveEaseOut]) {
            subtitleLabel.alpha = 1
            subtitleLabel.transform = .identity
        }
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

// MARK: - Segmented Spinner

private final class DivoSegmentedSpinner: UIView {

    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupSegments()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupSegments() {
        let count = 8
        let segmentSize = CGSize(width: 3, height: 10)
        let innerRadius: CGFloat = 5.5
        let center = CGPoint(x: 16, y: 16)
        let cornerRadius: CGFloat = 1.0
        let opacities: [CGFloat] = [1.0, 0.875, 0.75, 0.625, 0.5, 0.375, 0.25, 0.125]

        for i in 0..<count {
            let angle = CGFloat(i) * (.pi * 2.0 / CGFloat(count)) - .pi / 2.0
            let dist = innerRadius + segmentSize.height / 2.0

            let seg = CALayer()
            seg.bounds = CGRect(origin: .zero, size: segmentSize)
            seg.position = CGPoint(
                x: center.x + dist * cos(angle),
                y: center.y + dist * sin(angle)
            )
            seg.cornerRadius = cornerRadius
            seg.backgroundColor = UIColor.black.withAlphaComponent(opacities[i]).cgColor
            seg.transform = CATransform3DMakeRotation(angle + .pi / 2.0, 0, 0, 1)
            layer.addSublayer(seg)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && isAnimating {
            applyAnimation()
        }
    }

    @objc private func appDidBecomeActive() {
        if isAnimating {
            applyAnimation()
        }
    }

    func startAnimating() {
        isAnimating = true
        applyAnimation()
    }

    func stopAnimating() {
        isAnimating = false
        layer.removeAllAnimations()
    }

    private func applyAnimation() {
        layer.removeAllAnimations()
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let count = 8
        var values: [Double] = []
        for i in 0...count {
            values.append(Double(i) * .pi * 2.0 / Double(count))
        }
        animation.values = values
        animation.keyTimes = (0...count).map { NSNumber(value: Double($0) / Double(count)) }
        animation.duration = 0.8
        animation.repeatCount = .infinity
        animation.calculationMode = .discrete
        layer.add(animation, forKey: "spin")
    }
}
