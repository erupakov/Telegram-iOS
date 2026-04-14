import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import DivoCore
import MessageUI
import TelegramPresentationData
import AccountContext
import ShareController
import AlertUI
import PresentationDataUtils
import SearchUI
import LegacyMediaPickerUI
import CountrySelectionUI
import ChatScheduleTimeController
import DivoUIKit

protocol EditSocialLinksDelegate: AnyObject {
    func didUpdateSocialLinksData()
}

public class EditSocialLinksController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    
    private var editSocialLinksNode: EditSocialLinksNode {
        return self.displayNode as! EditSocialLinksNode
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Any?
    private var linksData: LinksData

    weak var delegate: EditSocialLinksDelegate?

    public init(context: AccountContext, presentationData: PresentationData, linksData: LinksData) {
        self.context = context
        self.linksData = linksData

        self.presentationData = presentationData

        super.init(navigationBarPresentationData: nil)

        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            self?.presentationData = presentationData
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        (self.presentationDataDisposable as? Disposable)?.dispose()
    }

    override public func loadDisplayNode() {

        self.displayNode = EditSocialLinksNode(
            context: self.context, 
            presentationData: self.presentationData, 
            linksData: linksData
        )
        
        self.editSocialLinksNode.saveSocialLinks = { [weak self] linksData in
            self?.saveSocialLinks(linksData: linksData)
        }

        self.editSocialLinksNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        self.displayNodeDidLoad()
    }
    
    private func saveSocialLinks(linksData: LinksData) {
        Task { @MainActor in
            do {
                let request = UpdateSocialLinksRequest(
                    model: UpdateSocialLinksRequest.ModelData(
                        tiktokUrl: linksData.tiktokUrl != nil ? linksData.tiktokUrl : "",
                        youtubeUrl: linksData.youtubeUrl != nil ? linksData.youtubeUrl : "",
                        telegramUrl: linksData.telegramUrl != nil ? linksData.telegramUrl : "",
                        instagramUrl: linksData.instagramUrl != nil ? linksData.instagramUrl : "",
                        websiteUrl: linksData.websiteUrl != nil ? linksData.websiteUrl : ""
                    )
                )
                
                let response: UpdateSocialLinksResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )
                
                print("✅ Social links successfully saved: \(response.message ?? "OK")")

                self.delegate?.didUpdateSocialLinksData()
                self.navigationController?.popViewController(animated: true)
                
            } catch {
                print("❌ Error saving social links: \(error)")
                self.editSocialLinksNode.toggleSpinner(active: false)
                self.editSocialLinksNode.showSnackbar(
                    message: DivoStrings.failedLinksUpdated,
                    style: .error
                )
            }
        }
    }
    

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.editSocialLinksNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
}
