import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import DivoCore
import TelegramPresentationData
import AccountContext
import PresentationDataUtils
import Postbox
import ChatScheduleTimeController
import DivoUIKit

protocol AddWorkExperienceDelegate: AnyObject {
    func didUpdateWorkExperience(isEdit: Bool)
}

public class AddWorkExperienceController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    private let editItem: WorkHistoryItem?

    private var addWorkExperienceNode: AddWorkExperience {
        return self.displayNode as! AddWorkExperience
    }
    
    weak var delegate: AddWorkExperienceDelegate?

    public init(context: AccountContext, editItem: WorkHistoryItem? = nil) {
        self.context = context
        self.editItem = editItem

        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override public func loadDisplayNode() {
        self.displayNode = AddWorkExperience(context: self.context, editItem: self.editItem)

        self.addWorkExperienceNode.scheduleTimeController = { [weak self] type in
            self?.scheduleTimeController(type: type)
        }
        
        self.addWorkExperienceNode.onSave = {[weak self] requestBody in
            self?.saveWorkExperience(body: requestBody)
        }
        
        self.addWorkExperienceNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.addWorkExperienceNode.requestAgencySearch = { [weak self] query in
            self?.searchAgencies(query: query)
        }
        
        self.addWorkExperienceNode.onLoadPhoto = { [weak self] id in
            guard let id = id else { return }
            self?.fetchAgencyLogo(agencyId: id)
        }
        
        self.displayNodeDidLoad()
        
        if let agencyId = self.editItem?.agencyId {
            self.fetchAgencyLogo(agencyId: agencyId)
        }
    }

    // MARK: - Agency Search Request
    private var searchTask: Task<Void, Never>?
    
    private func searchAgencies(query: String) {
        searchTask?.cancel()
        
        searchTask = Task { @MainActor in
            do {
                let requestBody = AgencyListRequest(offset: 0, limit: 3, title: query)
                
                let response: AgencyListResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/list",
                    method: "POST",
                    body: requestBody
                )
                
                guard !Task.isCancelled else { return }
                
                self.addWorkExperienceNode.updateAgencyResults(response.data.items)
                
            } catch {
                if !Task.isCancelled {
                    self.addWorkExperienceNode.updateAgencyResults([])
                }
            }
        }
    }
    
    private func fetchAgencyLogo(agencyId: Int) {
        self.addWorkExperienceNode.currentPhoto = nil
        addWorkExperienceNode.loadAvatar(isLoading: true)
        Task {
            do {
                let response: AgencyDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/\(agencyId)"
                )
                
                if let urlString = response.data.photo?.fullUrl, let url = URL(string: urlString) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.addWorkExperienceNode.currentPhoto = image
                            addWorkExperienceNode.loadAvatar(isLoading: false)
                        }
                    }
                } else {
                    await MainActor.run {
                        self.addWorkExperienceNode.currentPhoto = nil
                        self.addWorkExperienceNode.loadAvatar(isLoading: false)
                    }
                }
            } catch {
                await MainActor.run {
                    self.addWorkExperienceNode.currentPhoto = nil
                    self.addWorkExperienceNode.loadAvatar(isLoading: false)
                    self.addWorkExperienceNode.showSnackbar(
                        message: DivoStrings.failedToUploadPhoto,
                        style: .error
                    )
                }
            }
        }
    }
    
    private func scheduleTimeController(type: TimeType) {
        let peerId = PeerId(0)
        let controller = TimeController(
            context: context,
            updatedPresentationData: nil,
            peerId: peerId,
            mode: .date,
            style: .default,
            currentTime: nil,
            minimalTime: nil,
            completion: { [weak self] time in
                self?.addWorkExperienceNode.updateTime(time, type: type)
            })
        present(controller, in: .window(.root))
    }

    // MARK: - Network Request
    
    private func saveWorkExperience(body: CreateWorkHistoryRequest) {
        let path = editItem != nil ? "/model-work-history/\(editItem!.id)" : "/model-work-history"
        let isEdit = editItem != nil
        Task { @MainActor in
            do {
                let _: WorkHistorySaveResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
                
                self.addWorkExperienceNode.toggleSpinner(active: false)
                self.delegate?.didUpdateWorkExperience(isEdit: isEdit)
                self.navigationController?.popViewController(animated: true)
                
            } catch {
                self.addWorkExperienceNode.toggleSpinner(active: false)
                self.addWorkExperienceNode.showSnackbar(
                    message: isEdit ? DivoStrings.workHistoryFailedUpdated : DivoStrings.workHistoryFailedCreate,
                    style: .error
                )
            }
        }
    }
}
