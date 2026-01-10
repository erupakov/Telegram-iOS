import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
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

public final class EventsController: TelegramBaseController {
    private var controllerNode: EventsControllerNode {
        return self.displayNode as! EventsControllerNode
    }
    
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
//        getEvents()
        return self._ready
    }
    
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let peerViewDisposable = MetaDisposable()
    
    private var isEmpty: Bool?
    
    private let createActionDisposable = MetaDisposable()
    private let clearDisposable = MetaDisposable()
    
    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .none, locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        let icon: UIImage?
        icon = UIImage(bundleImageName: "Chat List/Tabs/IconEvents")
        self.tabBarItem.title = self.presentationData.strings.Events_TabTitle
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon

        updateNavigation()
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
            }
        }).strict()
    }
    
    private func updateNavigation() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        let searchButton = UIBarButtonItem(image: PresentationResourcesRootController.navigationSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.searchPressed))
        let addButton = UIBarButtonItem(image: PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.addPressed))
        
        self.navigationItem.rightBarButtonItems = [searchButton, addButton]
        
        let titleLabel = UILabel()
        titleLabel.text = self.presentationData.strings.Events_TabTitle.uppercased()
        titleLabel.font = Font.helveticaNeue(34)
        titleLabel.textColor = self.presentationData.theme.rootController.navigationBar.primaryTextColor
        titleLabel.sizeToFit()
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        containerView.addSubview(titleLabel)
        titleLabel.frame.origin.x = -50
        titleLabel.frame.origin.y = 10
        
        self.navigationItem.titleView = containerView
        self.navigationController?.hidesBarsOnSwipe = true
    }
    
    private var lastContentOffset: CGPoint = .zero
    
    public func updateContentOffset(offset: CGPoint) {
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getEvents()
    }
    
    private func getEvents() {
        //        displayNode.
        let supportPeer = Promise<[EventModel]?>()
        supportPeer.set(context.engine.eventsEngine.getEvents())
        self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { events in
            print("🔕", events ?? "")//displayNode
            if let events = events {
                let eventDataArray: [EventData] = events.map { model in
                    let datePartPrefix = model.eventDate.prefix(while: { $0 != "T" })
                    
                    return EventData(
                        title: model.title,
                        subtitle: model.title,
                        imageName: "Components/Model",
                        profileImageName: "Components/Model",
                        profileName: "@nyfw",
                        timeRemaining: String(datePartPrefix)
                    )
                }
                
                self.controllerNode.reloadEvents(events: eventDataArray)
            }
        }))
    }
    
    @objc private func searchPressed() {
        let controller = EventsSearchController(context: context)
        
        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
    }

    @objc private func addPressed() {
        let controller = CreateEventController(context: context)
        
        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
        
        print("Add button pressed")
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.peerViewDisposable.dispose()
        self.clearDisposable.dispose()
        self.supportPeerDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = EventsControllerNode(controller: self, context: self.context, presentationData: self.presentationData)
        self.displayNodeDidLoad()
        
        
//        self._ready.set(combineLatest(queue: .mainQueue(),
////            self.contactsNode.contactListNode.ready,
////            self.contactsNode.storiesReady.get()
//        )
//        |> filter { a, b in
//            return a && b
//        }
//        |> take(1)
//        |> map { _ -> Bool in true })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
