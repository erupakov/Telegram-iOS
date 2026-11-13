import Foundation

/// Имя из DIVO-профиля для заголовка личного чата (вместо номера телефона / Telegram-имени).
/// Резолвится один раз на telegramId через `GET /user/by-telegram`, результат (в т.ч. «нет профиля») кэшируется.
public final class DivoChatTitleNames {
    public static let shared = DivoChatTitleNames()

    private var names: [Int64: String?] = [:]
    private var pending: Set<Int64> = []

    /// Заранее известное имя (например, из открытого DIVO-профиля, откуда пользователь жмёт «Написать»):
    /// заголовок чата сразу берёт его, не дожидаясь `/user/by-telegram`.
    public func seed(telegramId: Int64, name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        names[telegramId] = .some(trimmed)
    }

    /// Имя из кэша; если ещё не резолвили — запускает запрос и по готовности зовёт `onResolved` (main).
    /// nil — имени пока нет или у пользователя нет DIVO-профиля.
    public func name(for telegramId: Int64, onResolved: @escaping () -> Void) -> String? {
        assert(Thread.isMainThread)
        if let cached = names[telegramId] {
            return cached
        }
        if !pending.contains(telegramId) {
            pending.insert(telegramId)
            Task { @MainActor [weak self] in
                let info = await resolveDivoPublicProfile(telegramId: telegramId)
                divoLog("[chat-title] by-telegram \(telegramId): \(info?.fullName ?? "нет профиля")", level: .info)
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
