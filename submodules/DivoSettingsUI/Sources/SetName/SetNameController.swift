import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import DivoCore

protocol SetNameDelegate: AnyObject {
    func didUpdateName()
}

public final class SetNameController: ViewController {
    private let context: AccountContext

    private var setNameNode: SetNameNode {
        return self.displayNode as! SetNameNode
    }

    private let userDetail: UserDetail?

    weak var delegate: SetNameDelegate?

    public init(context: AccountContext, userDetail: UserDetail?) {
        self.context = context
        self.userDetail = userDetail
        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let currentName = userDetail?.role == "agency_employee"
            ? userDetail?.agency?.title
            : userDetail?.fullName
        self.displayNode = SetNameNode(currentName: currentName)

        self.setNameNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        self.setNameNode.saveName = { [weak self] name in
            self?.handleSave(name: name)
        }

        self.displayNodeDidLoad()
    }

    private func handleSave(name: String) {
        if userDetail?.role == "agency_employee" {
            saveAgencyName(name)
        } else {
            saveUserName(name)
        }
    }

    private func saveUserName(_ name: String) {
        Task { @MainActor in
            do {
                // Шлём полный профиль с новым именем — остальные поля берём из текущего /user/info,
                // чтобы ничего не затереть (не зависим от merge/replace-семантики бэка). Если профиль
                // не загружен — деградируем до одного имени.
                let request = userDetail.map { UpdateBiographyPageRequest(preserving: $0, fullName: name) }
                    ?? UpdateBiographyPageRequest(fullName: name)
                let _: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )

                // DIVO сохранил имя → синкаем его в teamgram (best-effort, ретрай на сбое).
                DivoTeamgramName.syncToTeamgram(fullName: name)

                self.finishSuccess()
            } catch {
                self.finishFailure(error)
            }
        }
    }

    private func saveAgencyName(_ name: String) {
        Task { @MainActor in
            do {
                guard let detail = userDetail else {
                    self.setNameNode.toggleSaving(active: false)
                    self.setNameNode.showSnackbar(message: DivoStrings.failedProfileUpdated, style: .error)
                    return
                }
                let request = UpdateDescriptionAgencyRequest(preserving: detail, title: name)
                let _: UpdateDescriptionAgencyResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/update",
                    method: "POST",
                    body: request
                )

                DivoTeamgramName.syncToTeamgram(fullName: name)

                self.finishSuccess()
            } catch {
                self.finishFailure(error)
            }
        }
    }

    @MainActor
    private func finishSuccess() {
        self.setNameNode.toggleSaving(active: false)
        self.delegate?.didUpdateName()
        self.navigationController?.popViewController(animated: true)
    }

    @MainActor
    private func finishFailure(_ error: Error) {
        self.setNameNode.toggleSaving(active: false)
        let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedProfileUpdated
        self.setNameNode.showSnackbar(message: userMsg, style: .error)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}
