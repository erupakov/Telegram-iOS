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
    private let deleteWorkHistoryDisposable = MetaDisposable()
    private let createWorkExperienceDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true
    private let peer: Peer?
    
    public init(context: AccountContext, model: ProfileModel, peer: Peer? = nil) {
        self.context = context
        self.model = model
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.peer = peer
        
        self.title = "Work experience"
        
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
        self.deleteWorkHistoryDisposable.dispose()
        self.createWorkExperienceDisposable.dispose()
    }
    
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateNavigation() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        let addItem = UIBarButtonItem(image: UIImage(bundleImageName: "Models/addIcon"), style: .plain, target: self, action: #selector(self.addPressed))
        addItem.tintColor = UIColor(rgb: 0xBC8461)
        self.navigationItem.rightBarButtonItem = addItem
    }
    
    @objc private func addPressed() {
        addWorkExperience()
    }
    
    private func addWorkExperience() {
        let controller = AddWorkExperienceController(context: self.context)
        
        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
    }
    
    @objc private func backPressed() {
        self.navigationController?.popViewController(animated: true)
    }
   
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getWorkHistory()
    }
    
    private func getWorkHistory() {
        let supportPeer = Promise<[WorkExperienceModel]?>()
        
        supportPeer.set(context.engine.profileEngine.getWorkHistory(peer: peer))
        self.supportPeerDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { getWorkHistory in
            print("🔕", getWorkHistory ?? "")
            
            if let getWorkHistory = getWorkHistory {
                let workHistoryDataArray: [WorkExperienceItem] = getWorkHistory.map { model in
                    
                    return WorkExperienceItem(id: model.id, companyName: model.companyName, period: model.period, logoName: model.logoName)
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
        
        self.controllerNode.showDeleteAlert = { [weak self] text, id in
            self?.showDeleteAlert(text: text, id: id)
        }
        
        self.controllerNode.openAddWorkExperience = { [weak self] in
            self?.addWorkExperience()
        }
        
        
        self.displayNodeDidLoad()
    }
    
    private func showDeleteAlert(text: String, id: Int) {
        
        let alertController = textAlertController(
            context: context, title: nil,
            text: text, actions: [
                TextAlertAction(type: .destructiveAction, title: "Yes", action: {
                    self.deleteWorkHistory(id: id)
                }),
                TextAlertAction(type: .defaultAction, title: "No", action: {})
            ])
        present(alertController, in: .window(.root))
    }
    
    private func deleteWorkHistory(id: Int) {
        let supportPeer = Promise<Bool?>()
        
        supportPeer.set(context.engine.profileEngine.deleteWorkExperience(id: Int64(id)))
        self.deleteWorkHistoryDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { getWorkHistory in
            self.getWorkHistory()
        }))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
//        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
