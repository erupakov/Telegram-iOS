import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext
import DivoCore

// Регистрирует созданный канал в DIVO REST (POST /channels/add), чтобы он попал в /channels/list
// профиля. Бэк принимает и приватный канал (username необязателен, нужна invite-ссылка), поэтому
// регистрируем СРАЗУ после создания. Публичность (username) задаётся на экране после создания —
// когда username появляется или меняется, повторяем /channels/add: бэк обновляет username и
// inviteLink у существующей записи (app-backend !2; до его выкатки повтор вернёт 422 — безвредно).
// Нативное создание (CreateChannelController) — единственная точка входа, поэтому хук живёт здесь.
func divoRegisterCreatedChannel(context: AccountContext, peerId: PeerId) {
    let telegramChatId = peerId.id._internalGetInt64Value()

    let inviteLinkSignal: Signal<String?, NoError> = context.engine.peers.createPeerExportedInvitation(peerId: peerId, title: nil, expireDate: nil, usageLimit: nil, requestNeeded: nil, subscriptionPricing: nil)
    |> map { invitation -> String? in
        if let invitation = invitation, case let .link(link, _, _, _, _, _, _, _, _, _, _, _, _) = invitation {
            return link
        }
        return nil
    }
    |> `catch` { _ -> Signal<String?, NoError> in
        return .single(nil)
    }

    let usernameSignal: Signal<String?, NoError> = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
    )
    |> map { peer -> String? in
        if let username = peer?.addressName, !username.isEmpty { return username }
        return nil
    }
    |> distinctUntilChanged

    // Регистрация (первое значение — сразу после создания) + перерегистрация на каждую смену username.
    // Следим 10 минут: username задают на экране сразу после создания. Запросы строго по очереди —
    // иначе поздний ответ «без username» мог бы перезаписать уже зарегистрированный username.
    let chain = DivoChannelRegistrationChain()
    let disposable = (inviteLinkSignal
    |> mapToSignal { inviteLink -> Signal<(String?, String?), NoError> in
        return usernameSignal |> map { (inviteLink, $0) }
    }
    |> deliverOnMainQueue).startStrict(next: { inviteLink, username in
        // Публичному каналу ссылка t.me/<username> подходит, если invite-ссылку получить не удалось.
        guard let link = inviteLink ?? username.map({ "https://t.me/\($0)" }) else {
            divoLog("[CHANNELS] add: нет invite-ссылки для канала \(telegramChatId)", level: .error)
            return
        }
        chain.enqueue {
            do {
                let _: ChannelAddResponse = try await DivoAPIClient.shared.request(
                    path: "/channels/add",
                    method: "POST",
                    body: ChannelAddRequest(telegramChatId: telegramChatId, username: username, inviteLink: link)
                )
                divoLog("[CHANNELS] канал \(telegramChatId) зарегистрирован в REST (username: \(username ?? "нет"))")
                await MainActor.run {
                    NotificationCenter.default.post(name: DivoConfig.channelsDidChangeNotification, object: nil)
                }
            } catch {
                divoLog("[CHANNELS] add failed для \(telegramChatId) (username: \(username ?? "нет")): \(error)", level: .error)
            }
        }
    })
    Queue.mainQueue().after(600.0) {
        disposable.dispose()
    }
}

/// Последовательное выполнение async-шагов: каждый следующий ждёт завершения предыдущего.
/// Мутирует только на main (`deliverOnMainQueue` выше).
private final class DivoChannelRegistrationChain {
    private var last: Task<Void, Never>?

    func enqueue(_ operation: @escaping () async -> Void) {
        let previous = self.last
        self.last = Task {
            await previous?.value
            await operation()
        }
    }
}
