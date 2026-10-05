import Foundation

/// Блокировки пользователей DIVO: POST /user/block, POST /user/unblock, GET /user/blocked.
///
/// Держит в памяти множество id заблокированных — профиль по нему решает, показать в меню
/// «Заблокировать» или «Разблокировать». Любое изменение рассылает `didChangeNotification`.
public enum DivoBlockedUsers {

    /// Список / множество заблокированных изменились (блок, разблок, перезагрузка списка).
    public static let didChangeNotification = Notification.Name("DivoBlockedUsersDidChange")

    private static let lock = NSLock()
    private static var storedIds: Set<Int>?
    /// Чей это список (`DivoConfig.currentDivoUserId` на момент загрузки) — после смены аккаунта
    /// без явного reset() чужой кэш не используется.
    private static var storedOwnerId: Int?

    /// Кэш текущего аккаунта; вызывать под `lock`.
    private static var blockedIds: Set<Int>? {
        get { storedOwnerId == DivoConfig.currentDivoUserId ? storedIds : nil }
        set {
            storedIds = newValue
            storedOwnerId = newValue == nil ? nil : DivoConfig.currentDivoUserId
        }
    }

    /// Заблокирован ли пользователь по последним известным данным; `nil` — список ещё не загружался.
    public static func isBlocked(userId: Int) -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        return blockedIds.map { $0.contains(userId) }
    }

    /// Сколько пользователей заблокировано по последним известным данным; `nil` — список ещё не загружался.
    public static var cachedCount: Int? {
        lock.lock()
        defer { lock.unlock() }
        return blockedIds?.count
    }

    /// Загружает список заблокированных и обновляет кэш id.
    @discardableResult
    public static func fetch() async throws -> [DivoBlockedUser] {
        let response: BlockedUsersResponse = try await DivoAPIClient.shared.request(
            path: "/user/blocked",
            method: "GET"
        )
        update { $0 = Set(response.users.map(\.id)) }
        return response.users
    }

    /// Загружает список, только если он ещё не загружался в этой сессии. Ошибки глотает:
    /// профиль в этом случае показывает «Заблокировать» (как до появления списка).
    public static func fetchIfNeeded() async {
        lock.lock()
        let isLoaded = blockedIds != nil
        lock.unlock()
        guard !isLoaded else { return }
        do {
            try await fetch()
        } catch {
            divoLog("[BLOCK] GET /user/blocked failed: \(error)", level: .warning)
        }
    }

    public static func block(userId: Int) async throws {
        let _: UserBlockResponse = try await DivoAPIClient.shared.request(
            path: "/user/block",
            method: "POST",
            body: UserBlockRequest(userId: userId)
        )
        update { ids in
            var set = ids ?? []
            set.insert(userId)
            ids = set
        }
    }

    public static func unblock(userId: Int) async throws {
        let _: UserBlockResponse = try await DivoAPIClient.shared.request(
            path: "/user/unblock",
            method: "POST",
            body: UserBlockRequest(userId: userId)
        )
        update { ids in
            if var set = ids {
                set.remove(userId)
                ids = set
            }
        }
    }

    /// Сброс кэша — при выходе из аккаунта, чтобы следующий пользователь не унаследовал список.
    public static func reset() {
        update { $0 = nil }
    }

    private static func update(_ mutate: (inout Set<Int>?) -> Void) {
        lock.lock()
        mutate(&blockedIds)
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }
}
