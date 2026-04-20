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
import LegacyMediaPickerUI
import Postbox
import MapResourceToAvatarSizes
import ContextUI
import DivoUIKit

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

        super.init(context: context, navigationBarPresentationData: nil)
    }

    deinit {
        self.supportPeerDisposable.dispose()
        self.createWorkExperienceDisposable.dispose()
    }


    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func addPressed() {
        addWorkExperience()
    }

    private func addWorkExperience() {
        let controller = AddWorkExperienceController(context: self.context)
        controller.delegate = self
        self.push(controller)
    }

    @objc private func backPressed() {
        self.navigationController?.popViewController(animated: true)
    }

    private func fetchData() {
        model.isMyProfile ? getWorkMyHistory() : getWorkHistory()
    }

    private func getWorkHistory() {
        controllerNode.setLoading(true)
        guard let userId = model.userId else {
            controllerNode.setLoading(false)
            return
        }
        Task {
            var structuredItems: [WorkHistoryItem] = []
            do {
                let response: WorkHistoryResponse = try await DivoAPIClient.shared.request(
                    path: "/model-work-history?userId=\(userId)"
                )
                structuredItems = response.data.items
            } catch {
            }

            if !structuredItems.isEmpty {
                await MainActor.run {
                    self.controllerNode.reloadWorkHistory(items: structuredItems)
                }
                self.fetchAgencyLogos(for: structuredItems)
                return
            }

            // Fallback: parse workExperience text from user profile
            do {
                let userResponse: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/\(userId)"
                )
                await MainActor.run {
                    self.controllerNode.reloadLegacyWorkHistory(model: userResponse.data)
                }
            } catch {
                await MainActor.run {
                    self.controllerNode.setLoading(false)
                }
            }
        }
    }

    private func getWorkMyHistory() {
        controllerNode.setLoading(true)
        
        Task {
            var structuredItems: [WorkHistoryItem] = []
            do {
                let response: WorkHistoryResponse = try await DivoAPIClient.shared.request(
                    path: "/model-work-history"
                )
                structuredItems = response.data.items
            } catch {
            }
            
            if !structuredItems.isEmpty {
                await MainActor.run {
                    self.controllerNode.reloadWorkHistory(items: structuredItems)
                }
                self.fetchAgencyLogos(for: structuredItems)
                return
            } else {
                self.controllerNode.reloadWorkHistory(items: [])
            }
        }
    }
    
    private func fetchAgencyLogos(for items:[WorkHistoryItem]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for item in items {
                    guard let agencyId = item.agencyId else { continue }
                    
                    group.addTask {
                        var tempUrl: URL? = nil
                        
                        do {
                            let response: AgencyDetailResponse = try await DivoAPIClient.shared.request(
                                path: "/agency/\(agencyId)"
                            )
                            if let urlString = response.data.photo?.fullUrl {
                                tempUrl = URL(string: urlString)
                            }
                        } catch {
                        }
                        
                        let finalUrl = tempUrl
                        
                        await MainActor.run {
                            self.controllerNode.updateAgencyLogo(itemId: item.id, url: finalUrl)
                        }
                    }
                }
            }
        }
    }

    override public func loadDisplayNode() {
        self.displayNode = WorkExperience(
            controller: self,
            context: self.context,
            presentationData: self.presentationData,
            model: model)

        self.controllerNode.onEditItem = { [weak self] item in
            self?.editWorkExperience(item)
        }
        
        self.controllerNode.onDeleteItem = { [weak self] item in
            self?.deleteWorkHistory(id: item.id)
        }

        self.controllerNode.openAddWorkExperience = { [weak self] in
            self?.addWorkExperience()
        }
        
        self.controllerNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        self.displayNodeDidLoad()
        self.fetchData() 
    }

    private func editWorkExperience(_ item: WorkHistoryItem) {
        let controller = AddWorkExperienceController(context: self.context, editItem: item)
        controller.delegate = self
        self.push(controller)
    }

    private func deleteWorkHistory(id: Int) {
        Task {
            do {
                let _: WorkHistoryDeleteResponse = try await DivoAPIClient.shared.request(
                    path: "/model-work-history/\(id)",
                    method: "DELETE"
                )
                await MainActor.run {
                    self.fetchData()
                }
                self.controllerNode.showSnackbar(
                    message: DivoStrings.workHistoryDelete,
                    style: .success
                )
            } catch {
                self.controllerNode.showSnackbar(
                    message: DivoStrings.failedToDelete,
                    style: .error
                )
            }
        }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

extension WorkExperienceController: AddWorkExperienceDelegate {
    func didUpdateWorkExperience(isEdit: Bool) {
        self.fetchData()
        self.controllerNode.showSnackbar(
            message: isEdit ? DivoStrings.workHistoryUpdated : DivoStrings.workHistoryCreate,
            style: .success
        )
    }
}

