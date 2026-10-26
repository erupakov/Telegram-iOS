import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext
import DivoCore

// Каналы в профиле DIVO (/channels/list) — только ПУБЛИЧНЫЕ каналы (broadcast с @username),
// созданные пользователем. Приватные каналы и группы в профиль не попадают:
// - при создании канала регистрируем его, только когда у него есть username (задаётся при создании
//   или на экране сразу после него — следим 10 минут);
// - канал сделали публичным/приватным позже (ChannelVisibilityController → хук
//   `divoChannelVisibilityDidChange`) — регистрируем или удаляем запись.
// Повторный /channels/add обновляет username и inviteLink у существующей записи (app-backend !2;
// до его выкатки бэк отвечает 422 — тогда удаляем запись и регистрируем заново).

private enum DivoChannelProfileState: Equatable {
    case publicChannel(username: String)
    case notEligible
}

private func divoChannelProfileState(_ peer: EnginePeer?) -> DivoChannelProfileState {
    guard case let .channel(channel) = peer, case .broadcast = channel.info, channel.flags.contains(.isCreator) else {
        return .notEligible
    }
    guard let username = channel.addressName, !username.isEmpty else {
        return .notEligible
    }
    return .publicChannel(username: username)
}

/// Общая очередь для синхронизаций вне окна создания — запросы по одному каналу не обгоняют друг друга.
private let divoSharedChannelRegistrationChain = DivoChannelRegistrationChain()

func divoRegisterCreatedChannel(context: AccountContext, peerId: PeerId) {
    let telegramChatId = peerId.id._internalGetInt64Value()

    let stateSignal: Signal<DivoChannelProfileState, NoError> = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
    )
    |> map(divoChannelProfileState)
    |> distinctUntilChanged

    // Запросы строго по очереди — иначе поздний ответ мог бы перезаписать более свежее состояние.
    let chain = DivoChannelRegistrationChain()
    var isInitialState = true
    let disposable = (stateSignal
    |> deliverOnMainQueue).startStrict(next: { state in
        let wasInitial = isInitialState
        isInitialState = false
        switch state {
        case let .publicChannel(username):
            chain.enqueue {
                await divoAddRegisteredChannel(telegramChatId: telegramChatId, username: username)
            }
        case .notEligible:
            // Только что созданный приватный канал в REST не регистрировали — удалять нечего.
            guard !wasInitial else { return }
            chain.enqueue {
                await divoRemoveRegisteredChannel(telegramChatId: telegramChatId)
            }
        }
    })
    Queue.mainQueue().after(600.0) {
        disposable.dispose()
    }
}

/// Привести запись канала в /channels/list к текущей публичности канала (публичный → есть, иначе — нет).
func divoSyncChannelRegistration(context: AccountContext, peerId: PeerId) {
    let telegramChatId = peerId.id._internalGetInt64Value()
    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    |> deliverOnMainQueue).startStandalone(next: { peer in
        switch divoChannelProfileState(peer) {
        case let .publicChannel(username):
            divoSharedChannelRegistrationChain.enqueue {
                await divoAddRegisteredChannel(telegramChatId: telegramChatId, username: username)
            }
        case .notEligible:
            divoSharedChannelRegistrationChain.enqueue {
                await divoRemoveRegisteredChannel(telegramChatId: telegramChatId)
            }
        }
    })
}

private func divoAddRegisteredChannel(telegramChatId: Int64, username: String) async {
    let request = ChannelAddRequest(telegramChatId: telegramChatId, username: username, inviteLink: "https://t.me/\(username)")
    do {
        do {
            let _: ChannelAddResponse = try await DivoAPIClient.shared.request(path: "/channels/add", method: "POST", body: request)
        } catch let DivoAPIError.httpError(statusCode, _) where statusCode == 422 {
            // Бэк без app-backend !2: повторный add того же канала → 422 (пара user + chat уникальна).
            // Обходной путь от бэка: удалить запись и зарегистрировать заново с новым username.
            guard try await divoDeleteRegisteredChannel(telegramChatId: telegramChatId) else { throw DivoAPIError.httpError(statusCode: statusCode, body: "") }
            let _: ChannelAddResponse = try await DivoAPIClient.shared.request(path: "/channels/add", method: "POST", body: request)
        }
        divoLog("[CHANNELS] канал \(telegramChatId) зарегистрирован в REST (username: \(username))")
        await MainActor.run {
            NotificationCenter.default.post(name: DivoConfig.channelsDidChangeNotification, object: nil)
        }
    } catch {
        divoLog("[CHANNELS] add failed для \(telegramChatId) (username: \(username)): \(error)", level: .error)
    }
}

private func divoRemoveRegisteredChannel(telegramChatId: Int64) async {
    do {
        if try await divoDeleteRegisteredChannel(telegramChatId: telegramChatId) {
            await MainActor.run {
                NotificationCenter.default.post(name: DivoConfig.channelsDidChangeNotification, object: nil)
            }
        }
    } catch {
        divoLog("[CHANNELS] remove failed для \(telegramChatId): \(error)", level: .error)
    }
}

/// Удаляет запись канала текущего пользователя (по telegramChatId) из /channels/list.
/// false — записи нет (удалять нечего) или неизвестен divoUserId.
private func divoDeleteRegisteredChannel(telegramChatId: Int64) async throws -> Bool {
    guard let divoUserId = DivoConfig.currentDivoUserId else { return false }
    let list: ChannelsListResponse = try await DivoAPIClient.shared.request(path: "/channels/list?user_id=\(divoUserId)", method: "GET")
    guard let channel = list.data?.items?.first(where: { $0.telegramChatId == telegramChatId }) else { return false }
    _ = try await DivoAPIClient.shared.requestRawData(path: "/channels/\(channel.id)", method: "DELETE")
    divoLog("[CHANNELS] запись канала \(telegramChatId) удалена из REST")
    return true
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
