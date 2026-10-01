import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

/// DIVO: подпись teamgram для `POST /auth/telegram-link` (DIVO REST).
/// Сервер teamgram кладёт её в `help.getAppConfig` только владельцу авторизованной сессии.
public struct DivoLinkProof: Equatable {
    /// `divo_link_proof` — `"<exp>.<hex HMAC>"`, действует 10 минут.
    public let proof: String
    /// `divo_link_phone` — номер аккаунта teamgram (только цифры), под который сделана подпись.
    public let phone: String
}

/// Свежий proof: `help.getAppConfig` с `hash: 0` — кэш app config не годится (proof истекает).
/// nil — proof не выдан (функция выключена на сервере, нет сессии, включён 2FA, у аккаунта нет
/// номера) или запрос не прошёл.
func _internal_divoLinkProof(network: Network) -> Signal<DivoLinkProof?, NoError> {
    return network.request(Api.functions.help.getAppConfig(hash: 0))
    |> map { result -> DivoLinkProof? in
        switch result {
        case let .appConfig(appConfigData):
            guard let data = JSON(apiJson: appConfigData.config),
                  let proof = data["divo_link_proof"] as? String, !proof.isEmpty,
                  let phone = data["divo_link_phone"] as? String, !phone.isEmpty else {
                return nil
            }
            return DivoLinkProof(proof: proof, phone: phone)
        case .appConfigNotModified:
            return nil
        }
    }
    |> `catch` { _ -> Signal<DivoLinkProof?, NoError> in
        return .single(nil)
    }
}
