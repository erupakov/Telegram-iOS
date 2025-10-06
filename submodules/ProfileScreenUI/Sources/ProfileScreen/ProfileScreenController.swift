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
import TelegramBaseController

public final class ProfileScreenController: TelegramBaseController {
    
    private var controllerNode: ProfileScreenNode {
        return self.displayNode as! ProfileScreenNode
    }
    
    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?
    
    private let model: ProfileModel
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true

    public init(context: AccountContext, model: ProfileModel) {
        self.context = context
        self.model = model
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let darkNavigationTheme = NavigationBarTheme(
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)
        
        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))
        
        super.init(context: context, navigationBarPresentationData: navigationBarData, mediaAccessoryPanelVisibility: .none, locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        updateNavigation()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateNavigation() {
        self.statusBar.statusBarStyle = .White
    }
    
    @objc private func backPressed() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func likePressed() {
        print("Like button pressed")
    }
    
    @objc private func sharePressed() {
        print("Share button pressed")
    }
    
    @objc private func bookmarkPressed() {
        print("Bookmark button pressed")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ProfileScreenNode(controller: self, context: self.context, presentationData: self.presentationData, model: model)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
