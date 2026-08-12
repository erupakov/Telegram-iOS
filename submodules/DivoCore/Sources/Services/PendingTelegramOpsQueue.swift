import Foundation

public enum DivoPendingTelegramOp: Codable, Equatable, Hashable {
    case nameUpdate(firstName: String, lastName: String)
    // Отложенный DIVO phone-link: если линк после teamgram-входа упал (нет сети) и юзер
    // закрыл приложение на алерте «Повторить» — допроводим линк на следующем старте,
    // иначе accessToken-геттер тихо отдаёт хардкод agencyToken (silent fallback).
    case phoneLink(phone: String)
    // telegram-link после регистрации (best-effort): бэк ставит структурное user.phone +
    // сшивает DIVO↔teamgram. Если упал на submit — дотягиваем ретраем (telegramUserId берётся
    // из DivoTeamgramSync на момент дренажа). phone опционален: соц-ветка D линкует без номера
    // (dummy в user.phone не пишем). Старый персист со String читается (decodeIfPresent).
    case telegramLink(phone: String?, divoUserId: Int)
    // teamgram-ава (best-effort): исполнитель тянет свежую аву из DIVO REST и заливает в MTProto.
    // Без payload — актуальная ава берётся на момент дренажа (см. DivoTeamgramPhoto).
    case photoUpdate
    // DIVI-103: follow должен заводить человека в контакты Telegram. Payload — только DIVO userId;
    // telegramId и имя исполнитель дотягивает из /user/{id} на момент дренажа (best-effort).
    case addContact(divoUserId: Int)
}

public final class PendingTelegramOpsQueue {
    public static let shared = PendingTelegramOpsQueue()

    public typealias Executor = (DivoPendingTelegramOp) async throws -> Void

    private let storageKey = "divo.pendingTelegramOps"
    private let storage = UserDefaults.standard
    private let lock = NSLock()
    private var executor: Executor?
    /// Операции, исполняемые ПРЯМО СЕЙЧАС. Несколько drain'ов (registerExecutor + enqueue + token-change)
    /// могут стартовать поверх одного снапшота — без этого один и тот же op (напр. .telegramLink) уходил
    /// бы на сервер 2-3 раза параллельно (двойной POST + гонка токена). Дедуп только на enqueue не спасал.
    private var inFlight: Set<DivoPendingTelegramOp> = []
    /// DIVI-109: очередь пишет в Postbox только на переднем плане. В фоне незавершённая SQLite-запись
    /// держит лок в общем app-group контейнере под suspend → iOS убивает процесс (RUNNINGBOARD
    /// 0xdead10cc). Флаг ведёт AppDelegate штатным applicationInForeground; op'ы best-effort —
    /// ждут в сторе и докатываются при возврате на передний план.
    private var isForeground = true

    private init() {}

    public func registerExecutor(_ executor: @escaping Executor) {
        lock.lock()
        self.executor = executor
        lock.unlock()
        drain()
    }

    public func enqueue(_ op: DivoPendingTelegramOp) {
        appendOpSync(op)
        divoLog("PendingTelegramOps enqueued: \(op)", level: .info)
        drain()
    }

    /// Положить op в стор БЕЗ немедленного drain. Для cold-start страховки, когда живой
    /// ретрай ведёт другой механизм (in-flow алерт) — параллельный прогон не нужен,
    /// op сработает на следующем старте (DivoBootstrap → drain).
    public func persist(_ op: DivoPendingTelegramOp) {
        appendOpSync(op)
        divoLog("PendingTelegramOps persisted (cold-start safety): \(op)", level: .info)
    }

    /// Снять op — например, когда живой ретрай уже довёл операцию и страховка не нужна.
    public func remove(_ op: DivoPendingTelegramOp) {
        removeOpSync(op)
    }

    /// Полный сброс на логауте/сбросе DIVO-сессии: снимаем персист + in-flight + исполнителя. Иначе
    /// опы прошлого аккаунта (напр. .telegramLink) переживают выход и дренятся против НОВОГО teamgram-
    /// аккаунта → 409 "already linked". Зовётся из DivoConfig.resetDivoSessionForRollback (teardown-путь).
    public func clear() {
        lock.lock()
        storage.removeObject(forKey: storageKey)
        inFlight.removeAll()
        executor = nil
        lock.unlock()
    }

    /// Обновить foreground-состояние (ведёт AppDelegate через штатный applicationInForeground).
    /// Возврат на передний план сам докатывает отложенное в фоне. Тред-безопасно (тот же lock).
    public func setForeground(_ value: Bool) {
        lock.lock()
        let resumed = value && !isForeground
        isForeground = value
        lock.unlock()
        if resumed {
            drain()
        }
    }

    public func drain() {
        Task { await drainAsync() }
    }

    private func drainAsync() async {
        let (snapshot, currentExecutor) = readSnapshotSync()

        guard let exec = currentExecutor, !snapshot.isEmpty else { return }
        // DIVI-109: в фоне не начинаем — иначе запись в Postbox под suspend держит лок → 0xdead10cc.
        guard isForegroundSync() else {
            divoLog("PendingTelegramOps drain отложен: приложение в фоне", level: .info)
            return
        }
        divoLog("PendingTelegramOps drain: \(snapshot.count) op(s)", level: .info)

        for op in snapshot {
            // Ушли в фон посреди дренажа — стоп, остаток докатим при возврате на передний план (DIVI-109).
            guard isForegroundSync() else {
                divoLog("PendingTelegramOps drain прерван: ушли в фон", level: .info)
                break
            }
            // Занять op (синхронно — NSLock нельзя в async-контексте). false = уже исполняется
            // параллельным drain'ом ИЛИ уже снят из стора (снапшот устарел) → пропускаем, иначе двойное
            // исполнение (напр. .telegramLink ушёл бы на сервер дважды).
            guard claimForExecutionSync(op) else { continue }

            do {
                try await exec(op)
                removeOpSync(op)
                divoLog("PendingTelegramOps done: \(op)", level: .info)
            } catch {
                divoLog("PendingTelegramOps retry-later \(op): \(error)", level: .debug)
            }
            releaseInFlightSync(op)
        }
    }

    /// Атомарно занять op под исполнение. true = заняли; false = уже исполняется ИЛИ уже снят из стора.
    private func claimForExecutionSync(_ op: DivoPendingTelegramOp) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard loadOps().contains(op), !inFlight.contains(op) else { return false }
        inFlight.insert(op)
        return true
    }

    private func releaseInFlightSync(_ op: DivoPendingTelegramOp) {
        lock.lock()
        defer { lock.unlock() }
        inFlight.remove(op)
    }

    private func isForegroundSync() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isForeground
    }

    private func appendOpSync(_ op: DivoPendingTelegramOp) {
        lock.lock()
        defer { lock.unlock() }
        var ops = loadOps()
        if !ops.contains(op) {
            ops.append(op)
            saveOps(ops)
        }
    }

    private func readSnapshotSync() -> ([DivoPendingTelegramOp], Executor?) {
        lock.lock()
        defer { lock.unlock() }
        return (loadOps(), executor)
    }

    private func removeOpSync(_ op: DivoPendingTelegramOp) {
        lock.lock()
        defer { lock.unlock() }
        var ops = loadOps()
        if let idx = ops.firstIndex(of: op) {
            ops.remove(at: idx)
            saveOps(ops)
        }
    }

    private func loadOps() -> [DivoPendingTelegramOp] {
        guard let data = storage.data(forKey: storageKey),
              let ops = try? JSONDecoder().decode([DivoPendingTelegramOp].self, from: data) else {
            return []
        }
        return ops
    }

    private func saveOps(_ ops: [DivoPendingTelegramOp]) {
        guard let data = try? JSONEncoder().encode(ops) else { return }
        storage.set(data, forKey: storageKey)
    }
}
