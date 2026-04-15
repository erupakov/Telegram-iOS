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
import Postbox
import DivoUIKit

public class AddWorkExperienceController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    private let editItem: WorkHistoryItem?

    private var addWorkExperienceNode: AddWorkExperience {
        return self.displayNode as! AddWorkExperience
    }

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
        
        self.addWorkExperienceNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
        }
        
        self.addWorkExperienceNode.onSave = {[weak self] requestBody in
            self?.saveWorkExperience(body: requestBody)
        }
        
        self.addWorkExperienceNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        self.displayNodeDidLoad()
        
        if let agencyId = self.editItem?.agencyId {
            self.fetchAgencyLogo(agencyId: agencyId)
        }
    }

    @objc private func createPressed() {
        self.addWorkExperienceNode.applyButtonTapped()
    }
    
    private func fetchAgencyLogo(agencyId: Int) {
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
                }
            } catch {
                print("[DivoAPI] fetch edit agency logo error: \(error)")
                addWorkExperienceNode.loadAvatar(isLoading: false)
            }
        }
    }
    
    private func showAlert(text: String) {
        let alertController = textAlertController(
            context: context, title: nil,
            text: text, actions:[
                TextAlertAction(type: .genericAction, title: "Ok", action: {})
            ])
        present(alertController, in: .window(.root))
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

    // MARK: - Network Request (Логика поднята сюда)
    
    private func saveWorkExperience(body: CreateWorkHistoryRequest) {
        let path = editItem != nil ? "/model-work-history/\(editItem!.id)" : "/model-work-history"
        
        print("[DivoAPI] save work-history request: path=\(path), body=\(body)")
        
        Task { @MainActor in
            do {
                let response: WorkHistorySaveResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
                
                let msg = "OK: \(response.message ?? "nil")"
                print("[DivoAPI] save success: \(msg)")
                
                self.addWorkExperienceNode.toggleSpinner(active: false)
                self.showAlert(text: msg)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.navigationController?.popViewController(animated: true)
                }
                
            } catch {
                self.addWorkExperienceNode.toggleSpinner(active: false)
                let errMsg = "Error: \(error.localizedDescription)"
                print("[DivoAPI] save error: \(errMsg)")
                self.showAlert(text: errMsg)
            }
        }
    }
}
