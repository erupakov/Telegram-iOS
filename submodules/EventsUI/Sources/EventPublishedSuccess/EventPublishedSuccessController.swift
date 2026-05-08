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
import TelegramBaseController
import DivoUIKit
import DivoGallery

public final class EventPublishedSuccessController: TelegramBaseController {
    private var controllerNode: EventPublishedSuccessNode {
        return self.displayNode as! EventPublishedSuccessNode
    }
    
    private let context: AccountContext
    private let eventTitle: String
    
    public var onViewEventTapped: (() -> Void)?
    public var onManageApplicationsTapped: (() -> Void)?
    
    public init(context: AccountContext, eventTitle: String) {
        self.context = context
        self.eventTitle = eventTitle
        super.init(context: context, navigationBarPresentationData: nil)
        self.navigationPresentation = .modal
        self.statusBar.statusBarStyle = .Black
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = EventPublishedSuccessNode(eventTitle: eventTitle)
        
        self.controllerNode.onViewEvent = { [weak self] in
            self?.onViewEventTapped?()
        }
        
        self.controllerNode.onManageApplications = { [weak self] in
            self?.onManageApplicationsTapped?()
        }
        
        self.controllerNode.onBackTapped = {[weak self] in
            self?.dismiss()
        }
        
        self.displayNodeDidLoad()
    }
}
