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

final class EventsControllerNode: ASDisplayNode {
    private weak var controller: ViewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let _ready = ValuePromise<Bool>()
    private var didSetReady = false
    var ready: Signal<Bool, NoError> {
        return _ready.get()
    }
    
    private(set) var collectionView: UICollectionView!
    private var events: [EventData] = []
    
    private var shimmerViews: [ShimmerView] = []
    private var emptyStateView: UIView?
    
    private var isAgency: Bool = false
    
    private let navBackgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = DivoColorPalette.screenBackground
        return v
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(34)
        label.textColor = .black
        return label
    }()
    
    private var tabTitles: [String] {
        [DivoStrings.eventsMy.uppercased(), DivoStrings.eventsAll.uppercased()]
    }
    private var selectedTabIndex = 0
    
    private lazy var segmentedControl = DivoSegmentedControl(titles: tabTitles)
    
    private let tabsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.screenBackground
        return view
    }()
    
    private let searchFadeOverlay: UIView = {
        let view = GradientView()
        view.isUserInteractionEnabled = false
        view.isHidden = true
        if let gradient = view.layer as? CAGradientLayer {
            gradient.colors = [
                DivoColorPalette.screenBackground.cgColor,
                DivoColorPalette.screenBackground.withAlphaComponent(0).cgColor,
            ]
            gradient.locations = [0.0, 0.45] as [NSNumber]
        }
        return view
    }()
    
    // Спиннер пагинации внизу страницы
    private let footerSpinner: DivoSegmentedSpinner = {
        let spinner = DivoSegmentedSpinner()
        spinner.isHidden = true
        return spinner
    }()
    
    var onTabSelected: ((Int) -> Void)?
    var loadMore: (() -> Void)?
    var createEvent: (() -> Void)?
    
    public var isLoading: Bool = true {
        didSet {
            if isLoading {
                self.beginLoading()
            }
        }
    }
    
    public var isPaginating: Bool = false {
        didSet {
            if isPaginating {
                self.footerSpinner.startAnimating()
                self.footerSpinner.isHidden = false
            } else {
                self.footerSpinner.stopAnimating()
                self.footerSpinner.isHidden = true
            }
        }
    }
    
    public var showNetworkError: Bool = false {
        didSet {
            if showNetworkError {
                self.showError(DivoStrings.feedLoadErrorSubtitle)
            } else {
                self.view.viewWithTag(999)?.removeFromSuperview()
            }
        }
    }
    
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        
        super.init()
        
        self.view.backgroundColor = DivoColorPalette.screenBackground
        
        titleLabel.text = DivoStrings.navEvents
        let flowLayout = UICollectionViewFlowLayout()
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        self.collectionView.backgroundColor = .clear
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.collectionView.showsVerticalScrollIndicator = false
        self.collectionView.contentInsetAdjustmentBehavior = .never
        self.collectionView.register(EventCollectionViewCell.self, forCellWithReuseIdentifier: "EventCollectionViewCell")
        
        self.collectionView.isHidden = true
        
        self.view.addSubview(self.collectionView)
        self.view.addSubview(self.searchFadeOverlay)
        self.view.addSubview(self.navBackgroundView)
        self.navBackgroundView.addSubview(self.titleLabel)
        self.view.addSubview(self.tabsContainerView)
        self.view.addSubview(self.footerSpinner)
        
        // Segmented control tabs
        tabsContainerView.addSubview(segmentedControl)
        segmentedControl.onTabSelected = { [weak self] index in
            guard let self = self else { return }
            self.selectedTabIndex = index
            self.hideEmptyState()
            self.onTabSelected?(index)
        }
        
        self.events = []
        self.collectionView.reloadData()
        
        self.didSetReady = true
        self._ready.set(true)
        
        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.titleLabel.text = DivoStrings.navEvents
            self.segmentedControl.updateTitles(self.tabTitles)
            if let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
    }
    
    public func updateIsAgency(_ isAgency: Bool) {
        if self.isAgency != isAgency {
            self.isAgency = isAgency
            if let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
    }
    
    // Получение текущего скролла коллекции для сохранения в контроллере
    public func collectionViewContentOffset() -> CGPoint {
        return self.collectionView.contentOffset
    }
    
    // Обновление списка событий с безопасным восстановлением скролла
    public func updateEvents(_ events: [EventData], scrollOffset: CGPoint = .zero) {
        self.events = events
        self.isLoading = false
        removeShimmer()
        
        if let (layout, navigationBarHeight) = containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        
        self.collectionView.reloadData()
        self.collectionView.layoutIfNeeded()
        
        let maxOffsetY = max(0, self.collectionView.contentSize.height - self.collectionView.bounds.height)
        let targetY = min(scrollOffset.y, maxOffsetY)
        self.collectionView.setContentOffset(CGPoint(x: scrollOffset.x, y: targetY), animated: false)
        
        if events.isEmpty {
            collectionView.isHidden = true
            searchFadeOverlay.isHidden = true
            showEmptyState()
        } else {
            collectionView.isHidden = false
            searchFadeOverlay.isHidden = false
            hideEmptyState()
        }
    }
    
    // Безопасное добавление новой страницы (пагинация)
    public func appendEvents(_ events: [EventData]) {
        let start = self.events.count
        self.events.append(contentsOf: events)
        self.isLoading = false
        removeShimmer()
        
        if let (layout, navigationBarHeight) = containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        
        if self.events.isEmpty {
            collectionView.isHidden = true
            searchFadeOverlay.isHidden = true
            showEmptyState()
            self.collectionView.reloadData()
        } else {
            collectionView.isHidden = false
            searchFadeOverlay.isHidden = false
            hideEmptyState()
            
            let indexPaths = (0..<events.count).map { IndexPath(item: start + $0, section: 0) }
            self.collectionView.performBatchUpdates({
                self.collectionView.insertItems(at: indexPaths)
            }, completion: nil)
        }
    }
    
    public func showEmptyStateIfNeeded() {
        if self.events.isEmpty && !self.isLoading {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
    
    func showShimmer(topOffset: CGFloat, width: CGFloat) {
        removeShimmer()
        collectionView.isHidden = true
        searchFadeOverlay.isHidden = true
        
        guard width > 0 else { return }
        let spacing: CGFloat = 16
        
        let itemWidth = floor((width - spacing * 2 - 10) / 2.0)
        let itemHeight = floor(itemWidth * 1.35)
        
        for i in 0..<6 {
            let shimmer = ShimmerView()
            shimmer.layer.cornerRadius = 12
            shimmer.layer.masksToBounds = true
            let col = i % 2
            let row = i / 2
            
            let x: CGFloat = spacing + CGFloat(col) * (itemWidth + 10)
            let y: CGFloat = topOffset + CGFloat(row) * (itemHeight + 10)
            
            shimmer.frame = CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
            self.view.addSubview(shimmer)
            shimmer.startShimmer()
            shimmerViews.append(shimmer)
        }
    }
    
    private func removeShimmer() {
        for v in shimmerViews {
            v.stopShimmer()
            v.removeFromSuperview()
        }
        shimmerViews.removeAll()
    }
    
    private func beginLoading() {
        self.collectionView.isHidden = true
        self.searchFadeOverlay.isHidden = true
        hideEmptyState()
        removeShimmer()
        
        if let (layout, navigationBarHeight) = containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    public func showError(_ message: String) {
        self.isLoading = false
        removeShimmer()
        collectionView.isHidden = true
        searchFadeOverlay.isHidden = true
        
        self.view.viewWithTag(999)?.removeFromSuperview()
        
        let textView = UITextView()
        textView.text = message
        textView.textColor = .darkGray
        textView.font = .systemFont(ofSize: 13)
        textView.textAlignment = .left
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.tag = 999
        textView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(textView)
        let navH = containerLayout?.1 ?? 100
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: navH + 10),
            textView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            textView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            textView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -10)
        ])
    }
    
    // MARK: - Empty State
    
    private func showEmptyState() {
        guard emptyStateView == nil else { return }
        
        let container = UIView()
        container.backgroundColor = DivoColorPalette.screenBackground
        container.alpha = 0
                
        let iconImageView = UIImageView()
        iconImageView.image = DivoImage.emptyEvents
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconImageView)
        
        let titleLabel = UILabel()
        titleLabel.text = DivoStrings.noUpcomingEventsTitle
        titleLabel.font = Font.helveticaNeue(26)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = DivoStrings.noUpcomingEventsSubtitle
        subtitleLabel.font = Font.medium(16)
        subtitleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)

        let createButton = DivoButton()
        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.makeDivoButton(title: DivoStrings.createEvent)
        createButton.addTarget(self, action: #selector(createEventTapped), for: .touchUpInside)
        container.addSubview(createButton)
        
        NSLayoutConstraint.activate([
            
            iconImageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -68),
            iconImageView.widthAnchor.constraint(equalToConstant: 68),
            iconImageView.heightAnchor.constraint(equalToConstant: 68),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 14),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.xl),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.xl),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.xl),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.xl),

            createButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -100),
            createButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            createButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            createButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
        createButton.isHidden = !self.isAgency

        self.view.addSubview(container)
        emptyStateView = container
        
        if let (layout, navigationBarHeight) = containerLayout {
            let showTabs = self.isAgency
            let currentTabsHeight = showTabs ? self.tabsHeight : 0.0
            container.frame = CGRect(x: 0, y: navigationBarHeight + currentTabsHeight, width: layout.size.width, height: layout.size.height - navigationBarHeight - currentTabsHeight)
        }
        
        iconImageView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 15)
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: []) {
            container.alpha = 1
            iconImageView.transform = .identity
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
    
    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    private let tabsHeight: CGFloat = 32
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        let insets = layout.insets(options: [.input])
        let safeAreaInsets = layout.safeInsets
        
        navBackgroundView.frame = CGRect(x: 0, y: 0, width: layout.size.width, height: navigationBarHeight)
        
        let showTabs = self.isAgency
        let currentTabsHeight = showTabs ? self.tabsHeight : 0.0
        
        if showTabs {
            tabsContainerView.isHidden = false
            let segmentHPadding: CGFloat = 16 + layout.safeInsets.left
            let segmentWidth = layout.size.width - segmentHPadding * 2
            let segmentHeight = tabsHeight
            segmentedControl.frame = CGRect(x: segmentHPadding, y: 0, width: segmentWidth, height: segmentHeight)
            
            tabsContainerView.frame = CGRect(
                x: 0,
                y: navigationBarHeight,
                width: layout.size.width,
                height: tabsHeight
            )
        } else {
            tabsContainerView.isHidden = true
            tabsContainerView.frame = .zero
        }
        
        titleLabel.sizeToFit()
        let titleX: CGFloat = 16 + safeAreaInsets.left
        let titleY: CGFloat = navigationBarHeight - titleLabel.frame.height - 10
        let titleH: CGFloat = ceil(titleLabel.frame.height) + 6
        titleLabel.frame = CGRect(x: titleX, y: titleY - 4, width: ceil(titleLabel.frame.width), height: titleH)
        
        let spacing: CGFloat = 16
        let itemWidth = floor((layout.size.width - safeAreaInsets.left - safeAreaInsets.right - spacing * 2 - 10) / 2.0)
        let itemHeight = floor(itemWidth * 1.35)
        
        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            flowLayout.minimumInteritemSpacing = 10
            flowLayout.minimumLineSpacing = 10
            
            flowLayout.sectionInset = UIEdgeInsets(
                top: navigationBarHeight + currentTabsHeight + 16,
                left: safeAreaInsets.left + spacing,
                bottom: insets.bottom + spacing,
                right: safeAreaInsets.right + spacing
            )
        }
        
        self.collectionView.frame = CGRect(origin: .zero, size: layout.size)
        
        // Позиционируем спиннер пагинации по центру внизу
        self.footerSpinner.frame = CGRect(
            x: (layout.size.width - 32.0) / 2.0,
            y: layout.size.height - insets.bottom - 48.0,
            width: 32.0,
            height: 32.0
        )
        
        self.searchFadeOverlay.frame = CGRect(
            x: 0,
            y: navigationBarHeight + currentTabsHeight,
            width: layout.size.width,
            height: 60
        )
        
        if let emptyView = emptyStateView {
            emptyView.frame = CGRect(x: 0, y: navigationBarHeight + currentTabsHeight, width: layout.size.width, height: layout.size.height - navigationBarHeight - currentTabsHeight)
        }
        
        if isLoading && shimmerViews.isEmpty {
            showShimmer(topOffset: navigationBarHeight + currentTabsHeight + 16, width: layout.size.width)
        }
    }

    @objc private func createEventTapped() {
        self.createEvent?()
    }
}

extension EventsControllerNode: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return events.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < events.count else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "EventCollectionViewCell", for: indexPath)
        }
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EventCollectionViewCell", for: indexPath) as? EventCollectionViewCell else {
            fatalError("Unable to dequeue EventCollectionViewCell")
        }
        let event = events[indexPath.item]
        cell.configure(with: event, context: context)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < events.count else { return }
        let selectedEvent = events[indexPath.item]
        let detailController = EventDetailController(context: context, eventId: selectedEvent.id, isMyEvent: false)
        
        if let navigationController = controller?.navigationController {
            navigationController.pushViewController(detailController, animated: true)
        }
    }
    
    // Отслеживание скролла для подгрузки новых страниц
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let threshold: CGFloat = 200.0
        let contentOffset = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let boundsHeight = scrollView.bounds.size.height
        if contentOffset > contentHeight - boundsHeight - threshold {
            self.loadMore?()
        }
    }
}
