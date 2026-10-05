import Foundation

/// Блокировки пользователей DIVO: POST /user/block, POST /user/unblock, POST /user/blocked
/// (контракт — docs/divo-api-user-block.md).
///
/// Держит в памяти множество id заблокированных — профиль по нему решает, показать в меню
/// «Заблокировать» или «Разблокировать». Любое изменение рассылает `didChangeNotification`.
///
/// Блок синхронизирует в teamgram сервер: `contacts.block` / `contacts.unblock` на клиенте
/// не вызывать — иначе teamgram рассинхронизируется с DIVO.
public enum DivoBlockedUsers {

    public enum BlockError: Error {
        /// Нет собственной DIVO-сессии: с зашитым токеном агентства блок ушёл бы от имени агентства.
        case noSession
    }

    /// Список / множество заблокированных изменились (блок, разблок, перезагрузка списка).
    public static let didChangeNotification = Notification.Name("DivoBlockedUsersDidChange")

    /// Максимальный размер страницы POST /user/blocked (больше — 422).
    private static let pageLimit = 100

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

    /// Загружает весь список заблокированных (постранично, сначала последние) и обновляет кэш id.
    @discardableResult
    public static func fetch() async throws -> [DivoBlockedUser] {
        guard DivoConfig.hasDivoSession else { throw BlockError.noSession }
        var users: [DivoBlockedUser] = []
        var offset = 0
        while true {
            let response: BlockedUsersResponse = try await DivoAPIClient.shared.request(
                path: "/user/blocked",
                method: "POST",
                body: BlockedUsersRequest(offset: offset, limit: pageLimit)
            )
            let page = response.data
            let items = page?.items ?? []
            users.append(contentsOf: items)
            let meta = page?.pagination?.meta
            // currentOffset = offset + элементы страницы — следующий offset; конец, когда >= totalCount.
            let nextOffset = meta?.currentOffset ?? (offset + items.count)
            if items.isEmpty || nextOffset <= offset {
                break
            }
            if let totalCount = meta?.totalCount {
                if nextOffset >= totalCount { break }
            } else if items.count < pageLimit {
                break
            }
            offset = nextOffset
        }
        update { $0 = Set(users.map(\.id)) }
        return users
    }

    /// Загружает список, только если он ещё не загружался в этой сессии. Ошибки глотает:
    /// профиль в этом случае показывает «Заблокировать» (как до появления списка).
    public static func fetchIfNeeded() async {
        lock.lock()
        let isLoaded = blockedIds != nil
        lock.unlock()
        guard !isLoaded, DivoConfig.hasDivoSession else { return }
        do {
            try await fetch()
        } catch {
            divoLog("[BLOCK] POST /user/blocked failed: \(error)", level: .warning)
        }
    }

    /// Идемпотентен: повторная блокировка отвечает 200. Взаимную отписку делает сервер.
    public static func block(userId: Int) async throws {
        guard DivoConfig.hasDivoSession else { throw BlockError.noSession }
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

    /// Идемпотентен; работает и для удалённых пользователей. Подписки не восстанавливаются.
    public static func unblock(userId: Int) async throws {
        guard DivoConfig.hasDivoSession else { throw BlockError.noSession }
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

    /// Результат блокировки из чата (по teamgram-id собеседника).
    public enum ChatBlockOutcome {
        /// Блок / разблок прошёл через DIVO; в teamgram его синхронизирует сервер.
        case done
        /// У собеседника нет DIVO-аккаунта (бот, чужой teamgram-пользователь) или нет своей
        /// DIVO-сессии — блокировать в DIVO некого, остаётся обычный `contacts.block`.
        case notDivoUser
        /// DIVO-запрос не прошёл. `contacts.block` не вызываем — иначе teamgram разъедется с DIVO.
        case failed
    }

    /// Блок / разблок из чата: в чате известен только teamgram-id, поэтому сначала
    /// GET /user/by-telegram (заглушка `isUnavailable` тоже содержит `id`), затем block / unblock.
    public static func setBlocked(telegramUserId: Int64, isBlocked: Bool) async -> ChatBlockOutcome {
        guard DivoConfig.hasDivoSession else { return .notDivoUser }
        let divoUserId: Int
        do {
            let response: UserDetailResponse = try await DivoAPIClient.shared.request(
                path: "/user/by-telegram?telegramId=\(telegramUserId)"
            )
            divoUserId = response.data.id
        } catch DivoAPIError.httpError(let statusCode, _) where statusCode == 404 || statusCode == 422 {
            // 404 — связки с teamgram нет, 422 — связанный DIVO-аккаунт неактивен.
            divoLog("[BLOCK] by-telegram \(statusCode) для telegramId=\(telegramUserId) — нет DIVO-аккаунта", level: .info)
            return .notDivoUser
        } catch {
            divoLog("[BLOCK] by-telegram failed для telegramId=\(telegramUserId): \(error)", level: .warning)
            return .failed
        }
        do {
            if isBlocked {
                try await block(userId: divoUserId)
            } else {
                try await unblock(userId: divoUserId)
            }
            return .done
        } catch {
            divoLog("[BLOCK] \(isBlocked ? "block" : "unblock") из чата failed (divoUserId=\(divoUserId)): \(error)", level: .warning)
            return .failed
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
