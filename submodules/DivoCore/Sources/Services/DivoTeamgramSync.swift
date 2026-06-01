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

    private init() {}

    /// Регистрируется из AppDelegate при готовности authorized-контекста (захватывает движок).
    public func setNameUpdater(_ updater: NameUpdater?) {
        lock.lock()
        self.nameUpdater = updater
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
