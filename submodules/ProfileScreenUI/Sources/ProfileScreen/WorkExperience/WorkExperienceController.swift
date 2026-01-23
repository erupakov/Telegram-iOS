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
import LegacyMediaPickerUI
import Postbox
import MapResourceToAvatarSizes
import ContextUI

public final class WorkExperienceController: TelegramBaseController {
    
    private var controllerNode: WorkExperience {
        return self.displayNode as! WorkExperience
    }
    
    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?
    
    private let model: ProfileModel
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let createWorkExperienceDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true
    private let peer: Peer?
    
    public init(context: AccountContext, model: ProfileModel, peer: Peer? = nil) {
        self.context = context
        self.model = model
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.peer = peer
        let darkNavigationTheme = NavigationBarTheme(
            buttonColor: UIColor(red: 0.75, green: 0.48, blue: 0.33, alpha: 1.00),
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .black,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)
//        
        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))
        
        super.init(context: context, navigationBarPresentationData: navigationBarData, mediaAccessoryPanelVisibility: .none, locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        updateNavigation()
    }
    
    deinit {
        self.supportPeerDisposable.dispose()
        self.createWorkExperienceDisposable.dispose()
    }
    
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateNavigation() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        
        let addImage = PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme)?.withRenderingMode(.alwaysTemplate)
        let addItem = UIBarButtonItem(image: addImage, style: .plain, target: self, action: #selector(self.addPressed))
        addItem.tintColor = UIColor(rgb: 0xBC8461)
        self.navigationItem.rightBarButtonItem = addItem
    }
    
    @objc private func addPressed() {
        let controller = AddWorkExperienceController(context: self.context)
        
        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
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
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getWorkHistory()
    }
    
    private func getWorkHistory() {
        let supportPeer = Promise<[WorkExperienceModel]?>()
        
        supportPeer.set(context.engine.eventsEngine.getWorkHistory(peer: peer))
        self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { getWorkHistory in
            print("🔕", getWorkHistory ?? "")
            
            if let getWorkHistory = getWorkHistory {
                let workHistoryDataArray: [WorkExperienceItem] = getWorkHistory.map { model in
                    
                    return WorkExperienceItem(companyName: model.companyName, period: model.period, logoName: model.logoName)
                }
                
                self.controllerNode.reloadEvents(items: workHistoryDataArray)
            }
        }))
    }
    
    
    override public func loadDisplayNode() {
        self.displayNode = WorkExperience(
            controller: self,
            context: self.context,
            presentationData: self.presentationData,
            model: model)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
//        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
