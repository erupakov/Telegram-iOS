import Foundation
import Postbox
import SwiftSignalKit

/// Итог DIVO-блокировки пользователя teamgram (см. `DivoChatBlockBridge`).
public enum DivoChatBlockOutcome {
    /// Блок / разблок прошёл через DIVO REST — локально обновляем `isBlocked`, MTProto не зовём.
    case done
    /// У пользователя нет DIVO-аккаунта — обычный `contacts.block` / `contacts.unblock`.
    case notDivoUser
    /// DIVO-запрос не прошёл — ничего не меняем (MTProto не зовём, иначе teamgram разъедется с DIVO).
    case failed
}

/// Мост блокировок: TelegramCore не зависит от DivoCore, поэтому DIVO-реализацию
/// (`/user/by-telegram` → `/user/block`) подставляет приложение при старте. Пока хук не задан,
/// `requestUpdatePeerIsBlocked` работает как в Telegram.
public enum DivoChatBlockBridge {
    /// (teamgram user id, isBlocked) → итог.
    public static var handler: ((Int64, Bool) -> Signal<DivoChatBlockOutcome, NoError>)?
}

/// Локально проставляет `isBlocked` пользователю teamgram без MTProto — после блока / разблока
/// в DIVO (профиль, «Заблокированные»): teamgram синхронизирует сервер, а кэш клиента — нет.
/// Трогаем только уже закэшированные данные: без них Telegram сам загрузит актуальные с сервера.
func _internal_divoSetLocalIsBlocked(account: Account, telegramUserId: Int64, isBlocked: Bool) -> Signal<Never, NoError> {
    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(telegramUserId))
    return account.postbox.transaction { transaction -> Void in
        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
            guard let current = current as? CachedUserData else {
                return current
            }
            return current.isBlocked == isBlocked ? current : current.withUpdatedIsBlocked(isBlocked)
        })
    }
    |> ignoreValues
}
