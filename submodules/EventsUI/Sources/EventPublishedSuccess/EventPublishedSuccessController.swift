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
    
    public var onViewEventTapped: (() -> Void)?
    public var onManageApplicationsTapped: (() -> Void)?
    
    public init(context: AccountContext) {
        self.context = context
        
        super.init(context: context, navigationBarPresentationData: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = EventPublishedSuccessNode()
        
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
