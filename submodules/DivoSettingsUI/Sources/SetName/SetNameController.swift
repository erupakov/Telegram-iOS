import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import TelegramCore
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

    /// Текущий ник аккаунта (Telegram), подгружается асинхронно. Нужен, чтобы не валидировать
    /// неизменённое значение (checkUsername на собственный ник вернул бы «занято»).
    private var currentUsername: String = ""

    private let validateDisposable = MetaDisposable()
    private let usernameUpdateDisposable = MetaDisposable()
    private var prefillDisposable: Disposable?

    weak var delegate: SetNameDelegate?

    public init(context: AccountContext, userDetail: UserDetail?) {
        self.context = context
        self.userDetail = userDetail
        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        validateDisposable.dispose()
        usernameUpdateDisposable.dispose()
        prefillDisposable?.dispose()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
    }

    override public func loadDisplayNode() {
        let currentName = userDetail?.role == "agency_employee"
            ? userDetail?.agency?.title
            : userDetail?.fullName
        self.displayNode = SetNameNode(currentName: currentName)

        self.setNameNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        self.setNameNode.onSave = { [weak self] name, action in
            self?.handleSave(name: name, usernameAction: action)
        }

        self.setNameNode.onUsernameChanged = { [weak self] handle in
            self?.handleUsernameChanged(handle)
        }

        // Ник хранится в Telegram-аккаунте, в REST /user/info его нет — тянем из движка.
        // take(1): нужен только стартовый прелоад, иначе апдейт пира затрёт ввод пользователя.
        self.prefillDisposable = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self else { return }
            let username = peer?.addressName ?? ""
            self.currentUsername = username
            self.setNameNode.setInitialUsername(username)
        })

        self.displayNodeDidLoad()
    }

    // MARK: - Username validation

    private func handleUsernameChanged(_ handle: String) {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != currentUsername else {
            validateDisposable.set(nil)
            return
        }
        validateDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .account, name: trimmed)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            self?.setNameNode.applyUsernameState(SetNameController.mapValidation(status))
        }))
    }

    private static func mapValidation(_ status: AddressNameValidationStatus) -> SetNameNode.UsernameState {
        switch status {
        case .checking:
            return .checking
        case let .invalidFormat(error):
            switch error {
            case .startsWithUnderscore:
                return .error(message: DivoStrings.usernameStartsWithUnderscore)
            case .endsWithUnderscore:
                return .error(message: DivoStrings.usernameEndsWithUnderscore)
            case .startsWithDigit:
                return .error(message: DivoStrings.usernameStartsWithDigit)
            case .tooShort:
                return .error(message: DivoStrings.usernameTooShort)
            case .invalidCharacters:
                return .error(message: DivoStrings.usernameInvalidChars)
            }
        case let .availability(availability):
            switch availability {
            case .available:
                return .available(message: DivoStrings.usernameAvailable)
            case .taken:
                return .error(message: DivoStrings.usernameTaken)
            case .invalid, .purchaseAvailable:
                return .error(message: DivoStrings.usernameInvalid)
            }
        }
    }

    // MARK: - Save

    private func handleSave(name: String, usernameAction: SetNameNode.UsernameAction) {
        Task { @MainActor in
            do {
                try await self.saveName(name)
                // DIVO сохранил имя → синкаем его в teamgram (best-effort, ретрай на сбое).
                DivoTeamgramName.syncToTeamgram(fullName: name)
            } catch {
                self.finishFailure(error)
                return
            }

            // Имя сохранено (REST). Ник идёт через MTProto отдельным каналом ошибок.
            switch usernameAction {
            case .unchanged:
                self.finishSuccess()
            case let .set(handle):
                self.applyUsername(handle)
            case .clear:
                self.applyUsername(nil)
            }
        }
    }

    private func saveName(_ name: String) async throws {
        // Шлём полный профиль с новым именем — остальные поля берём из текущего /user/info,
        // чтобы ничего не затереть (не зависим от merge/replace-семантики бэка).
        if userDetail?.role == "agency_employee" {
            guard let detail = userDetail else { throw DivoAPIError.unknown }
            let request = UpdateDescriptionAgencyRequest(preserving: detail, title: name)
            let _: UpdateDescriptionAgencyResponse = try await DivoAPIClient.shared.request(
                path: "/agency/update",
                method: "POST",
                body: request
            )
        } else {
            let request = userDetail.map { UpdateBiographyPageRequest(preserving: $0, fullName: name) }
                ?? UpdateBiographyPageRequest(fullName: name)
            let _: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
                path: "/user/update-profile",
                method: "POST",
                body: request
            )
        }
    }

    private func applyUsername(_ name: String?) {
        usernameUpdateDisposable.set((context.engine.peers.updateAddressName(domain: .account, name: name)
        |> deliverOnMainQueue).start(error: { [weak self] _ in
            self?.finishUsernameFailure()
        }, completed: { [weak self] in
            self?.currentUsername = name ?? ""
            self?.finishSuccess()
        }))
    }

    // Все три вызываются с главного потока (Task @MainActor / deliverOnMainQueue), без @MainActor-аннотации.
    private func finishSuccess() {
        self.setNameNode.toggleSaving(active: false)
        self.delegate?.didUpdateName()
        self.navigationController?.popViewController(animated: true)
    }

    private func finishFailure(_ error: Error) {
        self.setNameNode.toggleSaving(active: false)
        let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.failedProfileUpdated
        self.setNameNode.showSnackbar(message: userMsg, style: .error)
    }

    private func finishUsernameFailure() {
        self.setNameNode.toggleSaving(active: false)
        // Имя сохранилось, ник — нет: обновляем профиль на предыдущем экране, остаёмся здесь для ретрая.
        self.delegate?.didUpdateName()
        self.setNameNode.showSnackbar(message: DivoStrings.usernameUpdateFailed, style: .error)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}
