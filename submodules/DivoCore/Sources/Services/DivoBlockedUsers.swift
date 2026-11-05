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

    /// Пользователь только что заблокирован (userInfo: `userId` Int — DIVO id). Ленты, поиск,
    /// Face Match, события и профили убирают его из уже загруженного: сервер перестаёт отдавать
    /// его контент, но закэшированные в памяти экраны чистим сами (docs/divo-api-user-block.md).
    public static let userBlockedNotification = Notification.Name("DivoBlockedUsersUserBlocked")

    /// Максимальный размер страницы POST /user/blocked (больше — 422).
    private static let pageLimit = 100

    /// Локальный статус блокировки в Telegram (CachedUserData.isBlocked) по teamgram-id. Ставит
    /// приложение: DivoCore не видит Postbox. Без него плашка «Разблокировать» в чате жила бы до
    /// перечитывания данных собеседника — teamgram синхронизирует сервер, но локальный кэш нет.
    public static var telegramBlockStateUpdater: ((_ telegramUserId: Int64, _ isBlocked: Bool) -> Void)?

    private static let lock = NSLock()
    private static var storedIds: Set<Int>?
    /// Чей это список (`DivoConfig.currentDivoUserId` на момент загрузки) — после смены аккаунта
    /// без явного reset() чужой кэш не используется.
    private static var storedOwnerId: Int?
    /// DIVO id → teamgram id заблокированных (из списка и из блокировок); под `lock`.
    private static var telegramIds: [Int: Int64] = [:]

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

    /// teamgram-id заблокированного по последним известным данным: профиль заблокированного —
    /// заглушка без `telegramId`, а для разблокировки в чате он нужен.
    public static func telegramId(userId: Int) -> Int64? {
        lock.lock()
        defer { lock.unlock() }
        return telegramIds[userId]
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
        let listedTelegramIds = Dictionary(users.compactMap { user in user.telegramId.map { (user.id, $0) } }, uniquingKeysWith: { first, _ in first })
        withLock { telegramIds = listedTelegramIds }
        update { $0 = Set(users.map(\.id)) }
        // Сверка с чатами: все из списка заблокированы и в teamgram (источник правды — этот метод).
        if let updater = telegramBlockStateUpdater {
            for telegramId in users.compactMap(\.telegramId) {
                updater(telegramId, true)
            }
        }
        return users
    }

    /// Загружает список, только если он ещё не загружался в этой сессии. Ошибки глотает:
    /// профиль в этом случае показывает «Заблокировать» (как до появления списка).
    public static func fetchIfNeeded() async {
        let isLoaded = withLock { blockedIds != nil }
        guard !isLoaded, DivoConfig.hasDivoSession else { return }
        do {
            try await fetch()
        } catch {
            divoLog("[BLOCK] POST /user/blocked failed: \(error)", level: .warning)
        }
    }

    /// Идемпотентен: повторная блокировка отвечает 200. Взаимную отписку делает сервер.
    /// `telegramId` — id собеседника в teamgram, если известен: обновим статус и в чате.
    public static func block(userId: Int, telegramId: Int64? = nil) async throws {
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
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: userBlockedNotification, object: nil, userInfo: ["userId": userId])
            // Сервер отписывает в обе стороны — синкаем флажок подписки на экранах, которые его держат.
            NotificationCenter.default.post(name: DivoConfig.divoFollowStateChanged, object: nil, userInfo: ["userId": userId, "isFollowed": false])
        }
        if let telegramId {
            withLock { telegramIds[userId] = telegramId }
            telegramBlockStateUpdater?(telegramId, true)
        }
    }

    /// Идемпотентен; работает и для удалённых пользователей. Подписки не восстанавливаются.
    public static func unblock(userId: Int, telegramId: Int64? = nil) async throws {
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
        withLock { telegramIds[userId] = nil }
        if let telegramId {
            telegramBlockStateUpdater?(telegramId, false)
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
            // telegramId запоминаем для последующей разблокировки из DIVO-профиля; локальный
            // isBlocked в чате TelegramCore проставит и сам — повторное обновление безвредно.
            if isBlocked {
                try await block(userId: divoUserId, telegramId: telegramUserId)
            } else {
                try await unblock(userId: divoUserId, telegramId: telegramUserId)
            }
            return .done
        } catch {
            divoLog("[BLOCK] \(isBlocked ? "block" : "unblock") из чата failed (divoUserId=\(divoUserId)): \(error)", level: .warning)
            return .failed
        }
    }

    /// Сброс кэша — при выходе из аккаунта, чтобы следующий пользователь не унаследовал список.
    public static func reset() {
        lock.lock()
        telegramIds = [:]
        lock.unlock()
        update { $0 = nil }
    }

    /// Синхронная секция под `lock`. NSLock.lock()/unlock() нельзя звать прямо из async-функций
    /// (ошибка в Swift 6 / warnings-as-errors) — async-методы ходят в кэш только через этот хелпер.
    private static func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
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
