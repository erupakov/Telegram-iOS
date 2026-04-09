import Foundation
import UIKit
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

final class ModelsFeedNode: ASDisplayNode, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CardCellDelegate {
    private final class PaginationShimmerCell: UICollectionViewCell {
        private let cardShimmer = ShimmerView()
        private let avatarShimmer = ShimmerView()
        private let nameLine1 = ShimmerView()
        private let nameLine2 = ShimmerView()
        private let actionLine = ShimmerView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .white

            cardShimmer.layer.cornerRadius = 0
            addSubview(cardShimmer)

            avatarShimmer.layer.cornerRadius = 35
            avatarShimmer.layer.masksToBounds = true
            addSubview(avatarShimmer)

            nameLine1.layer.cornerRadius = 6
            nameLine1.layer.masksToBounds = true
            addSubview(nameLine1)

            nameLine2.layer.cornerRadius = 6
            nameLine2.layer.masksToBounds = true
            addSubview(nameLine2)

            actionLine.layer.cornerRadius = 10
            actionLine.layer.masksToBounds = true
            addSubview(actionLine)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let w = bounds.width
            let h = bounds.height
            cardShimmer.frame = bounds
            avatarShimmer.frame = CGRect(x: 15, y: h - 200, width: 70, height: 70)
            nameLine1.frame = CGRect(x: 95, y: h - 195, width: w * 0.45, height: 18)
            nameLine2.frame = CGRect(x: 95, y: h - 170, width: w * 0.3, height: 18)
            actionLine.frame = CGRect(x: 15, y: h - 110, width: 100, height: 36)
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            [cardShimmer, avatarShimmer, nameLine1, nameLine2, actionLine].forEach { $0.stopShimmer() }
        }

        func setLoading(_ isLoading: Bool) {
            if isLoading {
                [cardShimmer, avatarShimmer, nameLine1, nameLine2, actionLine].forEach { $0.startShimmer() }
            } else {
                [cardShimmer, avatarShimmer, nameLine1, nameLine2, actionLine].forEach { $0.stopShimmer() }
            }
        }
    }

    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData

    private let navBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
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
            StoryModel(name: DivoStrings.addStory, avatarName: "Chat List/AddIcon", isLive: false, isAdd: true),
            StoryModel(name: "Jack D.", avatarName: "Models/image5", isLive: false, isAdd: false),
            StoryModel(name: "Joshua", avatarName: "", isLive: false, isAdd: false),
            StoryModel(name: "waggles", avatarName: "", isLive: true, isAdd: false),
            StoryModel(name: "steve.loves", avatarName: "", isLive: true, isAdd: false),
        ]
    }

    private var cards: [CardModel] = []

    private var tabTitles: [String] { [DivoStrings.feedSubscribed, DivoStrings.feedAllUsers, DivoStrings.feedAgencies] }
    private var selectedTabIndex = 0

    private let tabsScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.backgroundColor = .white
        return sv
    }()

    private let tabsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 40
        stack.alignment = .center
        return stack
    }()

    private let tabIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 4
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        return view
    }()

    private var loadingPlaceholderView: UIView?
    private var errorView: UIView?
    private var emptyStateView: UIView?

    var showNetworkError: Bool = false {
        didSet {
            if showNetworkError && cards.isEmpty {
                showErrorView()
            } else {
                hideErrorView()
            }
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
                showLoadingPlaceholder()
                hideEmptyState()
            } else {
                hideLoadingPlaceholder()
            }
        }
    }

    var showProfile: ((CardModel) -> Void)?
    var loadMore: (() -> Void)?
    var onTabSelected: ((Int) -> Void)?

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
        self.storiesCollectionView.backgroundColor = .white
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
        self.mainCollectionView.backgroundColor = .white
        self.mainCollectionView.dataSource = self
        self.mainCollectionView.delegate = self
        self.mainCollectionView.translatesAutoresizingMaskIntoConstraints = false
        self.mainCollectionView.delaysContentTouches = false
        self.mainCollectionView.canCancelContentTouches = true

        self.mainCollectionView.register(CardCollectionViewCell.self, forCellWithReuseIdentifier: "CardCell")
        self.mainCollectionView.register(PaginationShimmerCell.self, forCellWithReuseIdentifier: "PaginationShimmerCell")


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
                if let img = UIImage(named: story.avatarName) {
                    iv.image = img.resized(to: CGSize(width: 30, height: 30))
                    iv.contentMode = .center
                }
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
        self.view.addSubview(self.tabsScrollView)
        for av in floatingAvatars { self.view.addSubview(av) }
        for lbl in floatingNames { self.view.addSubview(lbl) }
        self.navBackgroundView.addSubview(self.titleLabel)
        self.tabsScrollView.addSubview(self.tabsStackView)
        self.tabsScrollView.addSubview(self.tabIndicatorView)

        for (index, title) in tabTitles.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = Font.helveticaNeue(12)
            button.titleLabel?.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
            button.setTitleColor(index == 0 ? .black : UIColor(white: 0.5, alpha: 1.0), for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
            tabsStackView.addArrangedSubview(button)
        }

        self.storiesCollectionView.reloadData()
        self.mainCollectionView.reloadData()

        self.didSetReady = true
        self._ready.set(true)
        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.titleLabel.text = DivoStrings.navModels
            for (index, view) in self.tabsStackView.arrangedSubviews.enumerated() {
                if let button = view as? UIButton, index < self.tabTitles.count {
                    button.setTitle(self.tabTitles[index], for: .normal)
                }
            }
            if let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
            self.storiesCollectionView.reloadData()
            self.mainCollectionView.reloadData()
        }
    }

    @objc private func tabButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedTabIndex else { return }
        selectedTabIndex = index

        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
            for case let button as UIButton in self.tabsStackView.arrangedSubviews {
                let isSelected = button.tag == index
                button.setTitleColor(isSelected ? .black : UIColor(white: 0.5, alpha: 1.0), for: .normal)
            }
        }
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.3, options: []) {
            self.layoutTabIndicator()
            self.scrollTabToVisible(index: index)
        }
        hideEmptyState()
        onTabSelected?(index)
    }

    private func scrollTabToVisible(index: Int) {
        guard index < tabsStackView.arrangedSubviews.count else { return }
        let button = tabsStackView.arrangedSubviews[index]
        let buttonFrame = button.convert(button.bounds, to: tabsScrollView)
        let scrollWidth = tabsScrollView.bounds.width
        let targetX = buttonFrame.midX - scrollWidth / 2.0
        let maxOffsetX = max(tabsScrollView.contentSize.width - scrollWidth, 0)
        let clampedX = min(max(targetX, 0), maxOffsetX)
        tabsScrollView.contentOffset = CGPoint(x: clampedX, y: 0)
    }

    private func layoutTabIndicator() {
        guard selectedTabIndex < tabsStackView.arrangedSubviews.count,
              let selectedButton = tabsStackView.arrangedSubviews[selectedTabIndex] as? UIButton else { return }

        tabsStackView.layoutIfNeeded()

        let indicatorHeight: CGFloat = 2
        let textSize: CGSize
        if let title = selectedButton.title(for: .normal), let font = selectedButton.titleLabel?.font {
            textSize = (title as NSString).size(withAttributes: [.font: font])
        } else {
            textSize = selectedButton.bounds.size
        }

        let buttonFrame = selectedButton.convert(selectedButton.bounds, to: tabsScrollView)
        let indicatorWidth = ceil(textSize.width) + 4
        let indicatorX = buttonFrame.midX - indicatorWidth / 2.0

        tabIndicatorView.frame = CGRect(
            x: floor(indicatorX),
            y: tabsHeight - indicatorHeight,
            width: indicatorWidth,
            height: indicatorHeight
        )
        tabsScrollView.bringSubviewToFront(tabIndicatorView)
    }

    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    private let storiesHeight: CGFloat = 90
    private let tabsHeight: CGFloat = 36

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)

        if let emptyStateView = self.emptyStateView {
            let topOffset = navigationBarHeight + 90 + 36
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

        var buttonsWidth: CGFloat = 0
        for view in tabsStackView.arrangedSubviews {
            buttonsWidth += view.intrinsicContentSize.width
        }
        let spacing = tabsStackView.spacing * CGFloat(max(tabsStackView.arrangedSubviews.count - 1, 0))
        let stackWidth = ceil(buttonsWidth + spacing)
        tabsStackView.frame = CGRect(x: 16, y: 0, width: stackWidth, height: tabsHeight - 2)
        tabsScrollView.contentSize = CGSize(width: stackWidth + 32, height: tabsHeight)

        let headerHeight = navigationBarHeight + storiesHeight + tabsHeight
        let collapsedHeaderHeight = navigationBarHeight + tabsHeight

        if let mainFlowLayout = self.mainCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            mainFlowLayout.sectionInset = UIEdgeInsets(top: headerHeight,
                                                       left: safeAreaInsets.left,
                                                       bottom: insets.bottom,
                                                       right: safeAreaInsets.right)

            let cardWidth = layout.size.width - safeAreaInsets.left - safeAreaInsets.right
            let cardHeight = layout.size.height - collapsedHeaderHeight - insets.bottom
            mainFlowLayout.itemSize = CGSize(width: cardWidth, height: cardHeight)
            mainFlowLayout.minimumLineSpacing = 0
        }

        self.mainCollectionView.contentInset = .zero

        updateHeaderLayout()
        layoutLoadingPlaceholder()
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
        storiesCollectionView.alpha = max(1 - p * 10, 0)  // gone by 10%

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

        let floatingVisible = min(p * 10, 1.0)  // visible by 10%

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
        tabsScrollView.frame = CGRect(
            x: 0,
            y: tabsY,
            width: layout.size.width,
            height: tabsHeight
        )

        layoutTabIndicator()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === storiesCollectionView {
            return stories.count
        } else if collectionView === mainCollectionView {
            return cards.count + (isPaginating ? 1 : 0)
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
            if isPaginating && indexPath.item == cards.count {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PaginationShimmerCell", for: indexPath) as? PaginationShimmerCell else {
                    fatalError("Unable to dequeue PaginationShimmerCell")
                }
                cell.setLoading(true)
                return cell
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

    func cardCell(_ cell: CardCollectionViewCell, didTapReaction reaction: ReactionType, for cardName: String, isSelected: Bool) {
        guard let indexPath = mainCollectionView.indexPath(for: cell) else { return }
        let idx = indexPath.item
        guard idx < self.cards.count else { return }
        var card = self.cards[idx]

        if isSelected {
             card.userReaction = reaction
         } else {
             card.userReaction = nil
         }

        switch reaction {
        case .like:
            print("👍 didSelectItemAt 'Like': \(cardName)")
        case .heart:
            print("❤️ didSelectItemAt 'Heart': \(cardName)")
        case .dislike:
            print("👎 didSelectItemAt 'Dislike': \(cardName)")
        case .fire:
            print("🔥 didSelectItemAt 'Fire': \(cardName)")
        }

        self.cards[idx] = card
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

    func cardCell(_ cell: CardCollectionViewCell, didTapFollowForUserId userId: Int, isFollowed: Bool) {
        guard let indexPath = mainCollectionView.indexPath(for: cell) else { return }
        let idx = indexPath.item
        guard idx < self.cards.count else { return }
        self.cards[idx].isFollowed = isFollowed

        let path = isFollowed ? "/follower/follow" : "/follower/unfollow"
        let body = FollowRequest(id: userId)

        Task { @MainActor in
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
                if !isFollowed && self.selectedTabIndex == 0 {
                    self.cards.remove(at: idx)
                    self.mainCollectionView.deleteItems(at: [indexPath])
                } else {
                    let message = isFollowed ? DivoStrings.subscribed : DivoStrings.unsubscribed
                    let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.controller?.view.window?.rootViewController?.present(alert, animated: true)
                }
            } catch {
                self.cards[idx].isFollowed = !isFollowed
                if let cell = self.mainCollectionView.cellForItem(at: indexPath) as? CardCollectionViewCell {
                    cell.configure(with: self.cards[idx], delegate: self)
                }
                print("❌ [FOLLOW] Error: \(error)")
            }
        }
    }

    // MARK: - Loading Placeholder

    private func showLoadingPlaceholder() {
        guard loadingPlaceholderView == nil else { return }

        let placeholder = UIView()
        placeholder.backgroundColor = .white
        placeholder.clipsToBounds = true

        let cardShimmer = ShimmerView()
        cardShimmer.layer.cornerRadius = 0
        cardShimmer.tag = 100
        placeholder.addSubview(cardShimmer)

        let avatarShimmer = ShimmerView()
        avatarShimmer.layer.cornerRadius = 35
        avatarShimmer.layer.masksToBounds = true
        avatarShimmer.tag = 101
        placeholder.addSubview(avatarShimmer)

        let nameLine1 = ShimmerView()
        nameLine1.layer.cornerRadius = 6
        nameLine1.layer.masksToBounds = true
        nameLine1.tag = 102
        placeholder.addSubview(nameLine1)

        let nameLine2 = ShimmerView()
        nameLine2.layer.cornerRadius = 6
        nameLine2.layer.masksToBounds = true
        nameLine2.tag = 103
        placeholder.addSubview(nameLine2)

        let actionLine = ShimmerView()
        actionLine.layer.cornerRadius = 10
        actionLine.layer.masksToBounds = true
        actionLine.tag = 104
        placeholder.addSubview(actionLine)

        self.view.addSubview(placeholder)
        loadingPlaceholderView = placeholder

        layoutLoadingPlaceholder()

        placeholder.subviews.compactMap { $0 as? ShimmerView }.forEach { $0.startShimmer() }
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

    private func showErrorView() {
        guard errorView == nil else { return }

        let container = UIView()
        container.backgroundColor = .white

        let iconLabel = UILabel()
        iconLabel.text = "⚠️"
        iconLabel.font = .systemFont(ofSize: 40)
        iconLabel.textAlignment = .center

        let titleLabel = UILabel()
        titleLabel.text = DivoStrings.serverUnavailable
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.1, alpha: 1)
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = DivoStrings.serverUnavailableSubtitle
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor(white: 0.5, alpha: 1)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        [iconLabel, titleLabel, subtitleLabel].forEach {
            container.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -40),

            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
        ])

        self.view.addSubview(container)
        errorView = container

        if let (layout, navigationBarHeight) = containerLayout {
            let topOffset = navigationBarHeight + 90 + 36
            container.frame = CGRect(x: 0, y: topOffset, width: layout.size.width, height: layout.size.height - topOffset)
        }
    }

    private func hideErrorView() {
        errorView?.removeFromSuperview()
        errorView = nil
    }

    private func layoutLoadingPlaceholder() {
        guard let placeholder = loadingPlaceholderView,
              let (layout, navigationBarHeight) = containerLayout else { return }

        let topOffset = navigationBarHeight + 90 + 36
        placeholder.frame = CGRect(x: 0, y: topOffset, width: layout.size.width, height: layout.size.height - topOffset)

        let w = placeholder.bounds.width
        let h = placeholder.bounds.height

        if let cardShimmer = placeholder.viewWithTag(100) {
            cardShimmer.frame = placeholder.bounds
        }
        if let avatar = placeholder.viewWithTag(101) {
            avatar.frame = CGRect(x: 15, y: h - 200, width: 70, height: 70)
        }
        if let line1 = placeholder.viewWithTag(102) {
            line1.frame = CGRect(x: 95, y: h - 195, width: w * 0.45, height: 18)
        }
        if let line2 = placeholder.viewWithTag(103) {
            line2.frame = CGRect(x: 95, y: h - 170, width: w * 0.3, height: 18)
        }
        if let action = placeholder.viewWithTag(104) {
            action.frame = CGRect(x: 15, y: h - 110, width: 100, height: 36)
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
            let topOffset = navigationBarHeight + 90 + 36
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
