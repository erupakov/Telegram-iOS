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
    private var emptyStateView: DivoEmptyStateView?
    
    private var isAgency: Bool = false
    private var userId: Int? = nil

    private var localeChangeObserver: NSObjectProtocol?

    private let navBackgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = DivoColorPalette.screenBackground
        return v
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.helveticaNeue(34)
        label.textColor = DivoColorPalette.primaryText
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
    
    // MARK: - Grid layout tokens
    // Используются и для шиммеров, и для реального layout коллекции —
    // должны совпадать побитово, иначе размер шиммера не совпадёт с ячейкой.
    private static let gridHorizontalInset: CGFloat = DivoDesignTokens.Spacing.m  // 16
    private static let gridInterspacing: CGFloat = 10                             // design choice, между s(8) и m(16)
    private static let gridAspectRatio: CGFloat = 1.35
    private static let gridColumns: CGFloat = 2.0
    private static let gridCellCornerRadius: CGFloat = DivoDesignTokens.Radius.m  // 12
    private static let shimmerCellCount = 6

    // Спиннер пагинации — встроен в collectionView.contentInset.bottom и
    // позиционируется под последней ячейкой (повторяет шаблон ModelsFeedNode).
    private static let paginationSpinnerHeight: CGFloat = 60

    private let paginationSpinnerView: UIView = {
        let container = UIView()
        container.isHidden = true
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = DivoColorPalette.primaryText
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }()
    
    private var errorView: UIView?
    private var errorIconCenterYConstraint: NSLayoutConstraint?
    private var errorRetryBottomConstraint: NSLayoutConstraint?
    
    var onTabSelected: ((Int) -> Void)?
    var loadMore: (() -> Void)?
    var createEvent: (() -> Void)?
    var applyForEvent: ((Int, EventCollectionViewCell) -> Void)?
    var onEventTapped: ((EventData) -> Void)? // Передаем тап по ячейке в контроллер
    
    var onRetry: (() -> Void)?
    var onPaginationRetry: (() -> Void)?

    /// Фаза экрана: loading / content / empty / failed.
    /// Меняется единственным сеттером — `applyState()` атомарно расставляет
    /// видимости и шиммеры. Никаких partial updates из сетевых колбэков.
    public enum ContentPhase: Equatable {
        case loading
        case content
        case empty
        case failed(networkError: Bool)
    }

    public var phase: ContentPhase = .loading {
        didSet {
            if oldValue != phase { applyState() }
        }
    }

    /// Пагинация — ортогональна `phase`: спиннер встраивается в `contentInset.bottom`
    /// коллекции и располагается под последней ячейкой.
    public var isPaginating: Bool = false {
        didSet {
            guard oldValue != isPaginating else { return }
            if isPaginating {
                collectionView.contentInset.bottom = Self.paginationSpinnerHeight
                paginationSpinnerView.isHidden = false
                updatePaginationSpinnerFrame()
            } else {
                collectionView.contentInset.bottom = 0
                paginationSpinnerView.isHidden = true
            }
        }
    }

    private func updatePaginationSpinnerFrame() {
        let width = collectionView.bounds.width
        let lastIndex = events.count - 1
        let y: CGFloat
        if lastIndex >= 0,
           let attrs = collectionView.layoutAttributesForItem(at: IndexPath(item: lastIndex, section: 0)) {
            y = attrs.frame.maxY
        } else {
            y = collectionView.contentSize.height
        }
        paginationSpinnerView.frame = CGRect(
            x: 0,
            y: y,
            width: width,
            height: Self.paginationSpinnerHeight
        )
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
        self.collectionView.addSubview(self.paginationSpinnerView)
        
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
        
        self.localeChangeObserver = NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.titleLabel.text = DivoStrings.navEvents
            self.segmentedControl.updateTitles(self.tabTitles)
            if let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
    }

    deinit {
        if let observer = self.localeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public func updateIsAgency(_ isAgency: Bool) {
        self.isAgency = isAgency
        // Безусловно переразложить layout: даже если значение совпало, на момент
        // первого присвоения (из loadDisplayNode) containerLayout мог быть nil,
        // и сегмент агентства не отрисовался бы.
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    public func setUserId(_ userId: Int?) {
        self.userId = userId
    }
    
    // Получение текущего скролла коллекции для сохранения в контроллере
    public func collectionViewContentOffset() -> CGPoint {
        return self.collectionView.contentOffset
    }

    // MARK: - Data API

    /// Полная замена списка событий. Фазу выставляет caller отдельно (`phase = .content / .empty`).
    public func setEvents(_ events: [EventData], scrollOffset: CGPoint = .zero) {
        self.events = events
        self.collectionView.reloadData()
        self.collectionView.layoutIfNeeded()

        let maxOffsetY = max(0, self.collectionView.contentSize.height - self.collectionView.bounds.height)
        let targetY = min(scrollOffset.y, maxOffsetY)
        self.collectionView.setContentOffset(CGPoint(x: scrollOffset.x, y: targetY), animated: false)
    }

    /// Пагинация — добавление новой страницы без перезагрузки коллекции.
    public func appendEvents(_ events: [EventData]) {
        guard !events.isEmpty else { return }
        let start = self.events.count
        self.events.append(contentsOf: events)

        // Если коллекция не на экране — performBatchUpdates с insertItems рискует
        // вызвать internal inconsistency (нет layout pass). Делаем reloadData.
        guard collectionView.window != nil else {
            collectionView.reloadData()
            updatePaginationSpinnerFrame()
            return
        }

        let indexPaths = (0..<events.count).map { IndexPath(item: start + $0, section: 0) }
        self.collectionView.performBatchUpdates({
            self.collectionView.insertItems(at: indexPaths)
        }, completion: { [weak self] _ in
            self?.updatePaginationSpinnerFrame()
        })
    }

    // Метод точечного обновления ячейки на экране (Задачи 1 и 2)
    public func updateEventLocally(eventId: Int, isApplied: Bool, appliesCount: Int? = nil) {
        guard let index = self.events.firstIndex(where: { $0.id == eventId }) else { return }
        
        var event = self.events[index]
        event.isApplied = isApplied
        
        if let appliesCount = appliesCount {
            event.appliesCount = appliesCount
        } else {
            // Если кол-во мест не пришло с сервера — вычисляем математически
            if let currentApplies = event.appliesCount {
                event.appliesCount = max(0, currentApplies + (isApplied ? 1 : -1))
            }
        }
        
        self.events[index] = event
        
        let indexPath = IndexPath(item: index, section: 0)
        self.collectionView.reloadItems(at: [indexPath])
    }

    public func updateEventDataLocally(_ updatedEvent: EventData) {
        guard let index = self.events.firstIndex(where: { $0.id == updatedEvent.id }) else { return }
        
        self.events[index] = updatedEvent
        let indexPath = IndexPath(item: index, section: 0)
        self.collectionView.reloadItems(at: [indexPath])
    }
    
    public func removeEventLocally(eventId: Int) {
        guard let index = self.events.firstIndex(where: { $0.id == eventId }) else { return }
        
        self.events.remove(at: index)
        let indexPath = IndexPath(item: index, section: 0)
        
        self.collectionView.performBatchUpdates({
            self.collectionView.deleteItems(at: [indexPath])
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            if self.events.isEmpty {
                self.phase = .empty
            }
        })
    }


    // MARK: - State machine

    private func applyState() {
        switch phase {
        case .loading:
            collectionView.isHidden = true
            searchFadeOverlay.isHidden = true
            hideEmptyState()
            hideErrorState()
            if let (layout, navigationBarHeight) = containerLayout {
                let currentTabsHeight = self.isAgency ? self.tabsHeight : 0.0
                showShimmer(topOffset: navigationBarHeight + currentTabsHeight + 16, width: layout.size.width)
            }
        case .content:
            collectionView.isHidden = false
            searchFadeOverlay.isHidden = false
            hideEmptyState()
            hideErrorState()
            removeShimmer()
        case .empty:
            collectionView.isHidden = true
            searchFadeOverlay.isHidden = true
            hideErrorState()
            removeShimmer()
            showEmptyState()
        case .failed:
            collectionView.isHidden = true
            searchFadeOverlay.isHidden = true
            hideEmptyState()
            removeShimmer()
            showErrorState()
        }
    }

    // MARK: - Shimmer

    func showShimmer(topOffset: CGFloat, width: CGFloat) {
        removeShimmer()
        collectionView.isHidden = true
        searchFadeOverlay.isHidden = true

        guard width > 0 else { return }

        let spacing = Self.gridHorizontalInset
        let gap = Self.gridInterspacing
        let columns = Self.gridColumns

        let itemWidth = floor((width - spacing * 2 - gap) / columns)
        let itemHeight = floor(itemWidth * Self.gridAspectRatio)

        for i in 0..<Self.shimmerCellCount {
            let shimmer = ShimmerView()
            shimmer.layer.cornerRadius = Self.gridCellCornerRadius
            shimmer.layer.masksToBounds = true
            let col = i % Int(columns)
            let row = i / Int(columns)

            let x: CGFloat = spacing + CGFloat(col) * (itemWidth + gap)
            let y: CGFloat = topOffset + CGFloat(row) * (itemHeight + gap)

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
    
    // MARK: - Error State (вёрстка повторяет ModelsFeedNode — единый стиль fullscreen
    // error для DIVO-лент. Кандидат на вынос в общий DivoErrorStateView в DivoUIKit-эпике).

    private func showErrorState() {
        guard errorView == nil else { return }

        let container = UIView()
        container.backgroundColor = DivoColorPalette.screenBackground

        let iconView = UIImageView(image: DivoImage.faceSearchError)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = DivoStrings.feedEventLoadErrorTitle.uppercased()
        titleLabel.font = UIFont(name: "HelveticaNeue-CondensedBold", size: 20) ?? Font.bold(20)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = DivoStrings.feedEventLoadErrorSubtitle
        subtitleLabel.font = Font.regular(14)
        subtitleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)

        let retryButton = UIButton(type: .custom)
        retryButton.setTitle(DivoStrings.retry, for: .normal)
        retryButton.setTitleColor(DivoColorPalette.primaryTextOnDark, for: .normal)
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
        // Сегмент-control (`Мои/Все`) для агентства остаётся видимым над error state —
        // вычитаем его высоту из доступного места под error view, как в ModelsFeedNode.
        let showTabs = self.isAgency
        let currentTabsHeight = showTabs ? self.tabsHeight : 0.0
        let topOffset = navigationBarHeight + currentTabsHeight
        let bottomInset = layout.intrinsicInsets.bottom
        error.frame = CGRect(x: 0, y: topOffset, width: layout.size.width, height: layout.size.height - topOffset)

        errorIconCenterYConstraint?.constant = -(bottomInset / 2) - 60
        errorRetryBottomConstraint?.constant = -bottomInset - 24
    }

    @objc private func errorRetryTapped() {
        onRetry?()
    }

    // Показ системного снэкбара при ошибке пагинации
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
    
    // MARK: - Empty State

    private func showEmptyState() {
        guard emptyStateView == nil else { return }

        let view = DivoEmptyStateView()
        view.backgroundColor = DivoColorPalette.screenBackground
        view.configure(.init(
            style: .largeIcon(icon: DivoImage.emptyEvents),
            title: DivoStrings.noUpcomingEventsTitle,
            subtitle: self.isAgency ? DivoStrings.noUpcomingEventsAgencySubtitle : DivoStrings.noUpcomingEventsSubtitle,
            ctaTitle: self.isAgency ? DivoStrings.createEvent : nil,
            onCTATapped: { [weak self] in self?.createEvent?() }
        ))

        self.view.addSubview(view)
        emptyStateView = view

        if let (layout, navigationBarHeight) = containerLayout {
            let currentTabsHeight = self.isAgency ? self.tabsHeight : 0.0
            view.frame = CGRect(x: 0, y: navigationBarHeight + currentTabsHeight, width: layout.size.width, height: layout.size.height - navigationBarHeight - currentTabsHeight)
            view.additionalBottomInset = self.emptyStateTabBarInset(for: layout)
        }

        view.animateAppearance()
    }

    /// Высота overlay-таббара Telegram сверх safe area. CTA эмпти-стейта привязана к
    /// `safeAreaLayoutGuide.bottomAnchor`, который учитывает только home-indicator, но не таббар —
    /// тот же зазор, что error-state/снэкбар закрывают через `intrinsicInsets.bottom`.
    private func emptyStateTabBarInset(for layout: ContainerViewLayout) -> CGFloat {
        return max(0, layout.intrinsicInsets.bottom - layout.safeInsets.bottom)
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
        
        let spacing = Self.gridHorizontalInset
        let gap = Self.gridInterspacing
        let itemWidth = floor((layout.size.width - safeAreaInsets.left - safeAreaInsets.right - spacing * 2 - gap) / Self.gridColumns)
        let itemHeight = floor(itemWidth * Self.gridAspectRatio)

        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            flowLayout.minimumInteritemSpacing = gap
            flowLayout.minimumLineSpacing = gap

            flowLayout.sectionInset = UIEdgeInsets(
                top: navigationBarHeight + currentTabsHeight + spacing,
                left: safeAreaInsets.left + spacing,
                bottom: insets.bottom + spacing,
                right: safeAreaInsets.right + spacing
            )
        }
        
        self.collectionView.frame = CGRect(origin: .zero, size: layout.size)

        if isPaginating {
            updatePaginationSpinnerFrame()
        }

        self.searchFadeOverlay.frame = CGRect(
            x: 0,
            y: navigationBarHeight + currentTabsHeight,
            width: layout.size.width,
            height: 60
        )
        
        if let emptyView = emptyStateView {
            emptyView.frame = CGRect(x: 0, y: navigationBarHeight + currentTabsHeight, width: layout.size.width, height: layout.size.height - navigationBarHeight - currentTabsHeight)
            emptyView.additionalBottomInset = self.emptyStateTabBarInset(for: layout)
        }
        
        layoutErrorState()
        
        if phase == .loading && shimmerViews.isEmpty {
            showShimmer(topOffset: navigationBarHeight + currentTabsHeight + 16, width: layout.size.width)
        }
    }

    // MARK: - Snackbar

    typealias SnackbarStyle = DivoSnackbar.Style

    private let snackbar = DivoSnackbar()

    func showSnackbar(message: String, style: SnackbarStyle, retryAction: (() -> Void)? = nil, persistent: Bool = false) {
        // safeAreaLayoutGuide самой node.view не учитывает overlay-таббар Telegram —
        // считаем inset через containerLayout.intrinsicInsets.bottom (включает таббар) + 16,
        // как в ModelsFeedNode.
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
}

extension EventsControllerNode: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return events.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Безопасная проверка выхода за пределы массива на случай рассинхронизации во время переключения
        guard indexPath.item < events.count else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "EventCollectionViewCell", for: indexPath)
        }
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EventCollectionViewCell", for: indexPath) as? EventCollectionViewCell else {
            fatalError("Unable to dequeue EventCollectionViewCell")
        }
        let event = events[indexPath.item]
        cell.configure(with: event)
        
        // Связываем действие тапа на кнопку Apply с замыканием узла
        cell.onApply = { [weak self, weak cell] in
            guard let self = self, let cell = cell else { return }
            self.applyForEvent?(event.id, cell)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < events.count else { return }
        let selectedEvent = events[indexPath.item]
        self.onEventTapped?(selectedEvent) // Передаем событие навигации в контроллер
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
