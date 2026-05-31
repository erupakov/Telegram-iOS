import Foundation

public enum DivoPendingTelegramOp: Codable, Equatable {
    case nameUpdate(firstName: String, lastName: String)
    // Отложенный DIVO phone-link: если линк после teamgram-входа упал (нет сети) и юзер
    // закрыл приложение на алерте «Повторить» — допроводим линк на следующем старте,
    // иначе accessToken-геттер тихо отдаёт хардкод agencyToken (silent fallback).
    case phoneLink(phone: String)
}

public final class PendingTelegramOpsQueue {
    public static let shared = PendingTelegramOpsQueue()

    public typealias Executor = (DivoPendingTelegramOp) async throws -> Void

    private let storageKey = "divo.pendingTelegramOps"
    private let storage = UserDefaults.standard
    private let lock = NSLock()
    private var executor: Executor?

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
            do {
                try await exec(op)
                removeOpSync(op)
                divoLog("PendingTelegramOps done: \(op)", level: .info)
            } catch {
                divoLog("PendingTelegramOps retry-later \(op): \(error)", level: .debug)
            }
        }
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
