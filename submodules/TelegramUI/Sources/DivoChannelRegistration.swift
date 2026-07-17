import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext
import DivoCore

// Регистрирует созданный ПУБЛИЧНЫЙ канал в DIVO REST (POST /channels/add), чтобы он попал
// в /channels/list профиля. Публичность (username) задаётся на экране после создания, поэтому
// ждём появления username и регистрируем только публичный канал; приватный не регистрируем.
// Нативное создание (CreateChannelController) — единственная точка входа, поэтому хук живёт здесь.
func divoRegisterCreatedChannel(context: AccountContext, peerId: PeerId) {
    let telegramChatId = peerId.id._internalGetInt64Value()

    let usernameSignal: Signal<String?, NoError> = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
    )
    |> map { peer -> String? in
        if let username = peer?.addressName, !username.isEmpty { return username }
        return nil
    }
    |> filter { $0 != nil }
    |> take(1)
    |> timeout(600.0, queue: Queue.mainQueue(), alternate: .single(nil))

    let _ = (usernameSignal
    |> mapToSignal { username -> Signal<(String, ExportedInvitation?), NoError> in
        guard let username = username else { return .complete() }
        return context.engine.peers.createPeerExportedInvitation(peerId: peerId, title: nil, expireDate: nil, usageLimit: nil, requestNeeded: nil, subscriptionPricing: nil)
        |> map { (username, $0) }
        |> `catch` { _ in .single((username, nil)) }
    }
    |> deliverOnMainQueue).startStandalone(next: { username, invitation in
        var link: String?
        if let invitation = invitation, case let .link(l, _, _, _, _, _, _, _, _, _, _, _, _) = invitation {
            link = l
        }
        guard let inviteLink = link else {
            divoLog("[CHANNELS] add: не удалось получить invite-ссылку для канала \(telegramChatId)", level: .error)
            return
        }
        Task {
            do {
                let _: ChannelAddResponse = try await DivoAPIClient.shared.request(
                    path: "/channels/add",
                    method: "POST",
                    body: ChannelAddRequest(telegramChatId: telegramChatId, username: username, inviteLink: inviteLink)
                )
                divoLog("[CHANNELS] публичный канал @\(username) (\(telegramChatId)) зарегистрирован в REST")
            } catch {
                divoLog("[CHANNELS] add failed для \(telegramChatId): \(error)", level: .error)
            }
        }
    })
}
