import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
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
import DivoCore

protocol EditParametersDelegate: AnyObject {
    func didUpdateParametersData()
}

public class EditParametersController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    
    private var editParametersNode: EditParametersNode {
        return self.displayNode as! EditParametersNode
    }
    
    private let userDetailData: UserDetail?
    private var selectedAvatarUUID: String?
    
    weak var delegate: EditParametersDelegate?

    public init(context: AccountContext, userDetailData: UserDetail?) {
        self.context = context
        self.userDetailData = userDetailData
        super.init(navigationBarPresentationData: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override public func loadDisplayNode() {

        self.displayNode = EditParametersNode(
            context: self.context,
            model: userDetailData
        )
        
        self.editParametersNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.editParametersNode.presentController = { [weak self] vc in
            self?.view.window?.rootViewController?.present(vc, animated: true)
        }
        
        self.editParametersNode.saveProfile = { [weak self] rawData in
            self?.handleSave(with: rawData)
        }

        self.displayNodeDidLoad()
        
        self.loadDictionaries()
    }
    
    private func loadDictionaries() {
        self.editParametersNode.toggleSpinner(active: true)
        self.editParametersNode.showScreenLoading()
        
        Task { @MainActor in
            do {
                async let appearanceTask = DivoAPIClient.shared.request(
                    path: "/dictionary/appearances",
                    method: "GET"
                ) as AppearanceDictionaryResponse
                
                async let genderTask = DivoAPIClient.shared.request(
                    path: "/dictionary/gender",
                    method: "GET"
                ) as GenderResponse
                
                let (appearanceResponse, genderResponse) = try await (appearanceTask, genderTask)
                
                self.editParametersNode.configureAppearanceDictionaries(appearanceResponse.data)
                self.editParametersNode.configureGenderDictionaries(genderResponse)
                self.editParametersNode.toggleSpinner(active: false)
                self.editParametersNode.hideScreenLoading()
                
            } catch {
                self.editParametersNode.toggleSpinner(active: false)
                self.editParametersNode.hideScreenLoading()
                self.editParametersNode.showSnackbar(
                    message: DivoStrings.failedLoadInteractionList,
                    style: .error,
                    retryAction: { [weak self] in
                        self?.editParametersNode.hideSnackbar(animated: true)
                        self?.loadDictionaries()
                    },
                    persistent: true
                )
            }
        }
    }
    
    private func handleSave(with rawData: UpdateBiographyPageRequest) {
        Task { @MainActor in
            do {
                let avatarUuid = self.selectedAvatarUUID.map {
                    UpdateBiographyPageRequest.AvatarUuid(uuid: $0)
                }
                let request = UpdateBiographyPageRequest(
                    fullName: rawData.fullName,
                    gender: rawData.gender,
                    model: rawData.model,
                    avatar: avatarUuid
                )

                let _: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )
                
                self.delegate?.didUpdateParametersData()
                self.navigationController?.popViewController(animated: true)

            } catch {
                self.editParametersNode.toggleSaving(active: false)
                self.editParametersNode.showSnackbar(
                    message: DivoStrings.failedParametersUpdated,
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
}
