import Foundation

/// DIVO: мост к авторизованному teamgram-движку для АТОМАРНЫХ операций в цепочке регистрации
/// (сейчас — обновление имени после онбординга). В отличие от `PendingTelegramOpsQueue`
/// (best-effort, retry-later), здесь вызов ДОЖИДАЕТСЯ и пробрасывает ошибку — submit-цепочка
/// падает целиком, если шаг не прошёл (правило атомарности Marina).
///
/// Замыкание ставит `AppDelegate`, когда поднялся authorized-контекст (есть движок). Онбординг
/// (и в живом флоу, и на cold-start) идёт уже при поднятом authorized-контексте, поэтому
/// updater к моменту submit'а выставлен.
public final class DivoTeamgramSync {
    public static let shared = DivoTeamgramSync()

    public enum SyncError: Error { case notReady }

    public typealias NameUpdater = (_ firstName: String, _ lastName: String) async throws -> Void

    private let lock = NSLock()
    private var nameUpdater: NameUpdater?
    private var _telegramUserId: Int64?

    private init() {}

    /// telegram user id (= `account.peerId.id`) авторизованного teamgram-аккаунта. Нужен для
    /// telegram-link (сшивка DIVO↔teamgram + установка структурного `user.phone` на бэке).
    /// Ставится из AppDelegate при поднятии authorized-контекста; читается на submit и в очереди ретраев.
    public var telegramUserId: Int64? {
        get { lock.lock(); defer { lock.unlock() }; return _telegramUserId }
        set { lock.lock(); _telegramUserId = newValue; lock.unlock() }
    }

    /// Регистрируется из AppDelegate при готовности authorized-контекста (захватывает движок).
    public func setNameUpdater(_ updater: NameUpdater?) {
        lock.lock()
        self.nameUpdater = updater
        lock.unlock()
    }

    /// Сброс на логауте: мост прошлого аккаунта не должен пережить выход — `telegramUserId` и
    /// `nameUpdater` захватывают движок предыдущего аккаунта. Заново ставятся при подъёме
    /// authorized-контекста следующего входа (см. AppDelegate.divoRegisterPendingOpsExecutor).
    public func reset() {
        lock.lock()
        self._telegramUserId = nil
        self.nameUpdater = nil
        lock.unlock()
    }

    /// Обновить имя в teamgram-контуре и ДОЖДАТЬСЯ завершения. Бросает, если движок ещё не
    /// готов — цепочка онбординга трактует это как фейл и откатывает (logout teamgram).
    public func updateName(firstName: String, lastName: String) async throws {
        let updater: NameUpdater? = {
            lock.lock(); defer { lock.unlock() }
            return self.nameUpdater
        }()
        guard let updater else {
            divoLog("DivoTeamgramSync.updateName: updater не готов (authorized-контекст не поднят)", level: .error)
            throw SyncError.notReady
        }
        try await updater(firstName, lastName)
        divoLog("DivoTeamgramSync.updateName: имя обновлено в teamgram (first=\(firstName))", level: .info)
    }
}
