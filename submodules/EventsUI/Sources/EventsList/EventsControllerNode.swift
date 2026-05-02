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

    private var collectionView: UICollectionView!
    private var events: [EventData] = []
    private var isLoading = true
    private var shimmerViews: [ShimmerView] = []
    private var emptyStateView: DivoEmptyStateView?

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

        self.collectionView.register(EventCollectionViewCell.self, forCellWithReuseIdentifier: "EventCollectionViewCell")

        self.collectionView.isHidden = true
        self.view.addSubview(self.collectionView)
        self.view.addSubview(self.navBackgroundView)
        self.navBackgroundView.addSubview(self.titleLabel)

        self.events = []
        self.collectionView.reloadData()

        self.didSetReady = true
        self._ready.set(true)
        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.titleLabel.text = DivoStrings.navEvents
            if let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
    }

    func showShimmer(navigationBarHeight: CGFloat) {
        removeShimmer()
        isLoading = true
        collectionView.isHidden = true

        let width = self.view.bounds.width
        guard width > 0 else { return }
        let spacing: CGFloat = 10
        let itemWidth = floor((width - spacing * 3) / 2.0)
        let itemHeight = floor(itemWidth * 1.35)

        for i in 0..<6 {
            let shimmer = ShimmerView()
            shimmer.layer.cornerRadius = 12
            shimmer.layer.masksToBounds = true
            let col = i % 2
            let row = i / 2
            let x: CGFloat = spacing + CGFloat(col) * (itemWidth + spacing)
            let y: CGFloat = navigationBarHeight + spacing + CGFloat(row) * (itemHeight + spacing)
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

    public func beginLoading() {
        self.isLoading = true
        self.collectionView.isHidden = true
        hideEmptyState()
        if let (_, navigationBarHeight) = containerLayout {
            showShimmer(navigationBarHeight: navigationBarHeight)
        }
    }

    public func reloadEvents(events: [EventData]) {
        self.events = events
        self.isLoading = false
        removeShimmer()
        if events.isEmpty {
            collectionView.isHidden = true
            showEmptyState()
        } else {
            collectionView.isHidden = false
            hideEmptyState()
            self.collectionView.reloadData()
        }
    }

    public func showError(_ message: String) {
        self.isLoading = false
        removeShimmer()
        collectionView.isHidden = true

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
            textView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -10)
        ])
    }

    // MARK: - Empty State

    private func showEmptyState() {
        guard emptyStateView == nil else { return }

        let emptyView = DivoEmptyStateView()
        emptyView.backgroundColor = DivoColorPalette.screenBackground
        emptyView.configure(.init(
            icon: DivoImage.iconEvents,
            title: DivoStrings.noEventsYet,
            subtitle: DivoStrings.noUpcomingEventsSubtitle
        ))

        self.view.addSubview(emptyView)
        emptyStateView = emptyView

        if let (layout, navigationBarHeight) = containerLayout {
            emptyView.frame = CGRect(x: 0, y: navigationBarHeight, width: layout.size.width, height: layout.size.height - navigationBarHeight)
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

    override func layout() {
        super.layout()
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)

        let insets = layout.insets(options: [.input])
        let safeAreaInsets = layout.safeInsets

        // Nav background + title (same pattern as ModelsFeedNode)
        navBackgroundView.frame = CGRect(x: 0, y: 0, width: layout.size.width, height: navigationBarHeight)

        titleLabel.sizeToFit()
        let titleX: CGFloat = 16 + safeAreaInsets.left
        let titleY: CGFloat = navigationBarHeight - titleLabel.frame.height - 10
        let titleH: CGFloat = ceil(titleLabel.frame.height) + 6 // +4pt top / +2pt bottom for CJK
        titleLabel.frame = CGRect(x: titleX, y: titleY - 4, width: ceil(titleLabel.frame.width), height: titleH)

        // Collection
        let spacing: CGFloat = 10
        let itemWidth = floor((layout.size.width - safeAreaInsets.left - safeAreaInsets.right - spacing * 3) / 2.0)
        let itemHeight = floor(itemWidth * 1.35)

        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            flowLayout.minimumInteritemSpacing = spacing
            flowLayout.minimumLineSpacing = spacing
            flowLayout.sectionInset = UIEdgeInsets(top: navigationBarHeight + spacing, left: safeAreaInsets.left + spacing, bottom: insets.bottom + spacing, right: safeAreaInsets.right + spacing)
        }

        self.collectionView.frame = CGRect(origin: .zero, size: layout.size)

        if let emptyView = emptyStateView {
            emptyView.frame = CGRect(x: 0, y: navigationBarHeight, width: layout.size.width, height: layout.size.height - navigationBarHeight)
        }

        if isLoading && shimmerViews.isEmpty {
            showShimmer(navigationBarHeight: navigationBarHeight)
        }
    }
}

extension EventsControllerNode: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return events.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EventCollectionViewCell", for: indexPath) as? EventCollectionViewCell else {
            fatalError("Unable to dequeue EventCollectionViewCell")
        }
        let event = events[indexPath.item]
        cell.configure(with: event, context: context)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedEvent = events[indexPath.item]
        let detailController = EventDetailController(context: context, eventData: selectedEvent)

        if let navigationController = controller?.navigationController {
            navigationController.pushViewController(detailController, animated: true)
        }
    }
}
