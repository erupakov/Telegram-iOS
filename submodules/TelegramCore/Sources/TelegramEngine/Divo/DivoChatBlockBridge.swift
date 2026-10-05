import Foundation
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
