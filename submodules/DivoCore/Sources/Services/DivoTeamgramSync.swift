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

    /// Подпись teamgram для `POST /auth/telegram-link`: `proof` + номер (только цифры), под который она
    /// сделана. Выдаётся сервером teamgram в `help.getAppConfig` только владельцу сессии, живёт 10 минут.
    public struct LinkProof: Equatable {
        public let proof: String
        public let phone: String
        public init(proof: String, phone: String) {
            self.proof = proof
            self.phone = phone
        }
    }
    /// nil — proof не выдан (функция выключена на сервере, 2FA, нет номера) или запрос не прошёл.
    public typealias LinkProofProvider = () async -> LinkProof?

    private let lock = NSLock()
    private var nameUpdater: NameUpdater?
    private var linkProofProvider: LinkProofProvider?
    private var _telegramUserId: Int64?
    private var _telegramAccessHash: Int64?
    private var _telegramSelfPhone: String?

    private init() {}

    /// telegram user id (= `account.peerId.id`) авторизованного teamgram-аккаунта. Нужен для
    /// telegram-link (сшивка DIVO↔teamgram + установка структурного `user.phone` на бэке).
    /// Ставится из AppDelegate при поднятии authorized-контекста; читается на submit и в очереди ретраев.
    public var telegramUserId: Int64? {
        get { lock.lock(); defer { lock.unlock() }; return _telegramUserId }
        set { lock.lock(); _telegramUserId = newValue; lock.unlock() }
    }

    /// access_hash self-пира teamgram. Кладём в `additionalInfo` при регистрации (как Android/Саша),
    /// чтобы бэк мог сослаться на юзера в teamgram-контуре. Ставится из AppDelegate по готовности self-пира.
    public var telegramAccessHash: Int64? {
        get { lock.lock(); defer { lock.unlock() }; return _telegramAccessHash }
        set { lock.lock(); _telegramAccessHash = newValue; lock.unlock() }
    }

    /// Номер, под которым teamgram зарегал self-пира (для соц-ветки D — dummy). Соц-юзер реального
    /// номера не вводит, но telegram-link идёт надёжнее с ним (проверенная комбинация с phone), чем с nil.
    public var telegramSelfPhone: String? {
        get { lock.lock(); defer { lock.unlock() }; return _telegramSelfPhone }
        set { lock.lock(); _telegramSelfPhone = newValue; lock.unlock() }
    }

    /// Регистрируется из AppDelegate при готовности authorized-контекста (захватывает движок).
    public func setNameUpdater(_ updater: NameUpdater?) {
        lock.lock()
        self.nameUpdater = updater
        lock.unlock()
    }

    /// Регистрируется из AppDelegate вместе с nameUpdater (захватывает движок авторизованного аккаунта).
    public func setLinkProofProvider(_ provider: LinkProofProvider?) {
        lock.lock()
        self.linkProofProvider = provider
        lock.unlock()
    }

    /// Свежий proof для telegram-link — перед КАЖДОЙ попыткой (в т.ч. из очереди ретраев): proof
    /// истекает за 10 минут, поэтому нигде не храним. Провайдер ставится при подъёме authorized-
    /// контекста и в момент вызова может ещё не успеть — короткий ретрай, как у telegramUserId.
    public func freshLinkProof() async -> LinkProof? {
        for attempt in 0 ..< 6 {
            let provider: LinkProofProvider? = {
                lock.lock(); defer { lock.unlock() }
                return self.linkProofProvider
            }()
            if let provider {
                let proof = await provider()
                divoLog("telegram-link: proof \(proof == nil ? "не выдан teamgram" : "получен")", level: proof == nil ? .warning : .info)
                return proof
            }
            if attempt < 5 { try? await Task.sleep(nanoseconds: 200_000_000) }
        }
        divoLog("telegram-link: провайдер proof не готов (authorized-контекст не поднят)", level: .warning)
        return nil
    }

    /// Сброс на логауте: мост прошлого аккаунта не должен пережить выход — `telegramUserId` и
    /// `nameUpdater` захватывают движок предыдущего аккаунта. Заново ставятся при подъёме
    /// authorized-контекста следующего входа (см. AppDelegate.divoRegisterPendingOpsExecutor).
    public func reset() {
        lock.lock()
        self._telegramUserId = nil
        self._telegramAccessHash = nil
        self._telegramSelfPhone = nil
        self.nameUpdater = nil
        self.linkProofProvider = nil
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
