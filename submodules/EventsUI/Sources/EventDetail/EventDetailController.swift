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

public final class EventDetailController: TelegramBaseController {

    private var controllerNode: EventDetailControllerNode {
        return self.displayNode as! EventDetailControllerNode
    }

    private let getEventDisposable = MetaDisposable()
    private var eventId: Int?
    private var eventData: EventFullDetailData?
    private let context: AccountContext
    private var presentationData: PresentationData
    private let isMyEvent: Bool?

    public init(context: AccountContext, eventId: Int? = nil, isMyEvent: Bool? = nil) {
        self.context = context
        self.eventId = eventId
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.isMyEvent = isMyEvent

        super.init(context: context, navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.getEventDisposable.dispose()
    }

    override public func loadDisplayNode() {
        self.displayNode = EventDetailControllerNode(context: self.context, presentationData: self.presentationData, isMyEvent: self.isMyEvent ?? false)
        
        // Перехватываем действия из кастомного навбара
        self.controllerNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.controllerNode.onShareTapped = { [weak self] in
            self?.sharePressed()
        }
        
        self.controllerNode.onBookmarkTapped = {[weak self] in
            self?.bookmarkPressed()
        }
        
        self.controllerNode.onApplyTapped = {[weak self] in
            self?.applyPressed()
        }
        
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getEvent()
    }

    private func getEvent() {
        guard let eventId = eventId else { return }

        Task {
            do {
                let response: EventFullDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/event/\(eventId)"
                )
                guard let item = response.data else { return }
                await MainActor.run {
                    self.eventData = item
                    self.eventId = item.id
                    self.controllerNode.updateEventData(item)
                }
            } catch {
                print("❌ [DivoAPI] event/\(eventId) error: \(error)")
            }
        }
    }
    
    private func sharePressed() {
        guard let eventId = eventId else { return }
        
        let shareURL = URL(string: "\(DivoConfig.shareBaseURL)/event/\(eventId)")!
        let shareItem = DivoShareItemSource(
            url: shareURL,
            title: eventData?.title ?? "",
            subtitle: eventData?.type?.title ?? "",
            image: controllerNode.coverImage
        )
        let activityVC = UIActivityViewController(activityItems: [shareItem], applicationActivities: nil)
        self.present(activityVC, animated: true)
    }

    private func bookmarkPressed() {
        print("Bookmark button pressed")
    }
    
    private func applyPressed() {
        print("Apply button pressed")
    }
}
