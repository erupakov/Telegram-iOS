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
import ProfileScreenUI

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
    
    private let createActionDisposable = MetaDisposable()
    private let clearDisposable = MetaDisposable()
    
    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .none, locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        let icon: UIImage?
        icon = UIImage(bundleImageName: "Models/IconModels")
        self.tabBarItem.title = self.presentationData.strings.ModelsFeed_TabTitle
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
        
        self.navigationItem.rightBarButtonItems = [searchButton]
        
        let titleLabel = UILabel()
        titleLabel.text = self.presentationData.strings.ModelsFeed_TabTitle.uppercased()
        titleLabel.font = Font.helveticaNeue(34)
        titleLabel.textColor = self.presentationData.theme.rootController.navigationBar.primaryTextColor
        titleLabel.sizeToFit()
        
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        containerView.addSubview(titleLabel)
        titleLabel.frame.origin.x = -10
        titleLabel.frame.origin.y = 10
        
        self.navigationItem.titleView = containerView
        self.navigationController?.hidesBarsOnSwipe = true
    }
    
    private var lastContentOffset: CGPoint = .zero
    
    public func updateContentOffset(offset: CGPoint) {
    }

    @objc private func searchPressed() {
//        let controller = EventsSearchController(context: context)
//        
//        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
//            navigationController.pushViewController(controller)
//        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func showProfile(_ model: CardModel) {
        let detailController = ProfileScreenController(context: context, eventData: "selectedEvent")
        
        navigationController?.pushViewController(detailController, animated: true)
    }
    
    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.peerViewDisposable.dispose()
        self.clearDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ModelsFeedNode(controller: self, context: self.context, presentationData: self.presentationData)
        self.controllerNode.showProfile = { [weak self] model in
            self?.showProfile(model)
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
