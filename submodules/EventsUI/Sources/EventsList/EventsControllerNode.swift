import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
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
    
    init(controller: ViewController, context: AccountContext, presentationData: PresentationData) {
        self.controller = controller
        self.context = context
        self.presentationData = presentationData
        
        super.init()
        
        let flowLayout = UICollectionViewFlowLayout()
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        self.collectionView.backgroundColor = .clear
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        self.collectionView.register(EventCollectionViewCell.self, forCellWithReuseIdentifier: "EventCollectionViewCell")
        
        self.view.addSubview(self.collectionView)
        
        self.events = [
            EventData(
                title: "FASHION MODEL EVENT",
                      subtitle: "May 27 · 5:00 PM · 🇺🇸 New York",
                imageName: "Components/Model",
                profileImageName: "Components/Model",
                profileName: "@nyfw",
                timeRemaining: "4d : 4h : 0m"
            ),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/EventTest", profileImageName: "Components/Model", profileName: "@vogue", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/Agencies", profileImageName: "Components/Model", profileName: "@elle", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/Model", profileImageName: "Components/Model", profileName: "@chanel", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/NewTalent", profileImageName: "Components/Model", profileName: "@dior", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/Agencies", profileImageName: "Components/Model", profileName: "@gucci", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/Model", profileImageName: "Components/Model", profileName: "@nyfw", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/NewTalent", profileImageName: "Components/Model", profileName: "@vogue", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/Agencies", profileImageName: "Components/Model", profileName: "@elle", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/Model", profileImageName: "Components/Model", profileName: "@chanel", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/NewTalent", profileImageName: "Components/Model", profileName: "@dior", timeRemaining: "4d : 4h : 0m"),
            EventData(title: "FASHION MODEL EVENT", subtitle: "May 27 • 5:00 PM • New York", imageName: "Components/Agencies", profileImageName: "Components/Model", profileName: "@gucci", timeRemaining: "4d : 4h : 0m")
        ]
        
        self.collectionView.reloadData()
        
        self.didSetReady = true
        self._ready.set(true)
    }
    
    public func reloadEvents(events: [EventData]) {
        self.events = events
        self.collectionView.reloadData()
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
        
        let itemWidth = floor((layout.size.width - safeAreaInsets.left - safeAreaInsets.right - 30) / 2.0)
//        let itemHeight = itemWidth * 1.5
        
        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = CGSize(width: itemWidth, height: 230)
            flowLayout.sectionInset = UIEdgeInsets(top: navigationBarHeight + 10, left: safeAreaInsets.left + 10, bottom: insets.bottom + 10, right: safeAreaInsets.right + 10)
        }
        
        self.collectionView.frame = CGRect(origin: .zero, size: layout.size)
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) { //TODO: move to EventsController
        let selectedEvent = events[indexPath.item]
        let detailController = EventDetailController(context: context, eventData: selectedEvent)
        
        if let navigationController = controller?.navigationController {
            navigationController.pushViewController(detailController, animated: true)
        }
    }
    
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
////        self.controller?.updateContentOffset(offset: scrollView.contentOffset)
////        let hide = scrollView.panGestureRecognizer.translation(in: scrollView.superview).y < 0
////        
////        self.controller?.navigationController?.setNavigationBarHidden(hide, animated: true)
//    }
}
