import Foundation
import SwiftSignalKit
import DivoCore

/// Имя из DIVO-профиля для заголовка личного чата (вместо номера телефона / Telegram-имени).
/// Резолвится один раз на telegramId через `GET /user/by-telegram`, результат (в т.ч. «нет профиля») кэшируется.
final class DivoChatTitleNames {
    static let shared = DivoChatTitleNames()

    private var names: [Int64: String?] = [:]
    private var pending: Set<Int64> = []

    /// Имя из кэша; если ещё не резолвили — запускает запрос и по готовности зовёт `onResolved` (main).
    /// nil — имени пока нет или у пользователя нет DIVO-профиля.
    func name(for telegramId: Int64, onResolved: @escaping () -> Void) -> String? {
        assert(Thread.isMainThread)
        if let cached = names[telegramId] {
            return cached
        }
        if !pending.contains(telegramId) {
            pending.insert(telegramId)
            Task { @MainActor [weak self] in
                let info = await resolveDivoPublicProfile(telegramId: telegramId)
                guard let self else {
                    return
                }
                self.pending.remove(telegramId)
                self.names[telegramId] = .some(info?.fullName)
                if info != nil {
                    onResolved()
                }
            }
        }
        return nil
    }
}
