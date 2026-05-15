import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import DivoUIKit
import DivoCore

protocol EditParametersDelegate: AnyObject {
    func didUpdateParametersData()
}

public final class EditParametersController: ViewController {
    private let context: AccountContext

    private var editParametersNode: EditParametersNode {
        return self.displayNode as! EditParametersNode
    }

    private let userDetailData: UserDetail?

    weak var delegate: EditParametersDelegate?

    public init(context: AccountContext, userDetailData: UserDetail?) {
        self.context = context
        self.userDetailData = userDetailData
        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        self.editParametersNode.markLoading()

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
                self.editParametersNode.markContent()
            } catch {
                self.editParametersNode.toggleSpinner(active: false)
                self.editParametersNode.markFailed()
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
                let _: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: rawData
                )

                self.editParametersNode.toggleSaving(active: false)
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
}
