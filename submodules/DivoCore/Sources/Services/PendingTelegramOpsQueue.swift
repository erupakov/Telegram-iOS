import Foundation

public enum DivoPendingTelegramOp: Codable, Equatable, Hashable {
    case nameUpdate(firstName: String, lastName: String)
    // Отложенный DIVO phone-link: если линк после teamgram-входа упал (нет сети) и юзер
    // закрыл приложение на алерте «Повторить» — допроводим линк на следующем старте,
    // иначе accessToken-геттер тихо отдаёт хардкод agencyToken (silent fallback).
    case phoneLink(phone: String)
    // telegram-link после регистрации (best-effort): бэк ставит структурное user.phone +
    // сшивает DIVO↔teamgram. Если упал на submit — дотягиваем ретраем (telegramUserId берётся
    // из DivoTeamgramSync на момент дренажа).
    case telegramLink(phone: String, divoUserId: Int)
    // teamgram-ава (best-effort): исполнитель тянет свежую аву из DIVO REST и заливает в MTProto.
    // Без payload — актуальная ава берётся на момент дренажа (см. DivoTeamgramPhoto).
    case photoUpdate
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

    public func drain() {
        Task { await drainAsync() }
    }

    private func drainAsync() async {
        let (snapshot, currentExecutor) = readSnapshotSync()

        guard let exec = currentExecutor, !snapshot.isEmpty else { return }
        divoLog("PendingTelegramOps drain: \(snapshot.count) op(s)", level: .info)

        for op in snapshot {
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
