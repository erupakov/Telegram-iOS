import Foundation

public enum DivoConfig {
    /// REST-хост по окружению сборки (см. [[DivoEnvironment]]). stage — отладочный контур, prod — боевой.
    /// Пути намеренно разные: stage на `/api`, prod на `/v2` — так задал бэкенд.
    public static var baseURL: URL {
        switch DivoEnvironment.current {
        case .stage:
            return URL(string: "https://api-stage.divo.fashion/api")!
        case .prod:
            return URL(string: "https://api.divo.fashion/v2")!
        }
    }

    public static let agencyToken = "Ccw5cQAMFzxCttzgpUu69NuJARelHshG78LOAHiPQEjKeMSP93OWsbc110MKc6mf"
    public static let modelToken = "GxelyeqTBVrPAJLWXRXUH4XktoUhu2QLTFfxIvgnvDD9jKBLolF6GDVQQsSzChSF"

    private static let tokenKey = "DivoConfig.customAccessToken"
    private static let delayKey = "DivoConfig.simulatedDelay"
    private static let roleKey = "DivoConfig.userRole"

    public static let tokenDidChangeNotification = Notification.Name("DivoConfig.tokenDidChange")
    public static let roleDidChangeNotification = Notification.Name("DivoConfig.roleDidChange")
    public static let profileDidUpdateNotification = Notification.Name("DivoConfig.profileDidUpdate")
    /// Канал зарегистрирован в REST (/channels/add) → профиль перечитывает /channels/list.
    /// Регистрация асинхронна (ждёт username после создания), поэтому без нотификации свежий канал
    /// не появлялся в профиле до перезахода.
    public static let channelsDidChangeNotification = Notification.Name("DivoConfig.channelsDidChange")
    /// Статус заявки на событие изменился (apply/unapply) → перерисовать ячейки эвентов в табе/профиле.
    public static let divoEventAppliedStatusChanged = Notification.Name("DivoConfig.eventAppliedStatusChanged")
    /// Выставлен pending-онбординг (соц/phone). Нужно перепроверить app-gate: на первом входе
    /// context-ready может отработать ДО установки флага (async-линк) — нотификация добивает гонку.
    public static let pendingOnboardingDidChangeNotification = Notification.Name("DivoConfig.pendingOnboardingDidChange")
    /// Онбординг-цепочка (registration/role/profile) не прошла целиком → откат: logout teamgram + welcome.
    public static let onboardingChainFailedNotification = Notification.Name("DivoConfig.onboardingChainFailed")
    public static let divoEventDataUpdated = Notification.Name("DivoConfig.divoEventDataUpdated")
    public static let divoEventDeleted = Notification.Name("DivoConfig.divoEventDeleted")
    public static let divoEventCreated = Notification.Name("DivoConfig.divoEventCreated")
    /// follow/unfollow на любом экране (userInfo: userId Int, isFollowed Bool) — кеширующие ленты синкают флажок между собой.
    public static let divoFollowStateChanged = Notification.Name("DivoConfig.followStateChanged")
    /// like/unlike на любом экране (userInfo: userId Int, isLiked Bool) — кеширующие ленты синкают лайк между собой.
    public static let divoLikeStateChanged = Notification.Name("DivoConfig.likeStateChanged")

    // MARK: - User Roles

    public enum UserRole: String, CaseIterable {
        case agency = "agency_employee"
        case fan = "fan"
        case model = "model"
        case newFace = "new_face"

        public var displayName: String {
            switch self {
            case .agency: return "Agency"
            case .fan: return "Fan"
            case .model: return "Model"
            case .newFace: return "New Face"
            }
        }
    }

    public static var currentUserRole: UserRole {
        get {
            // При debug-форсе токена роль матчится с ним (консистентный UI).
            if isDebugEnabled, let forced = forcedTestToken {
                return forced.role
            }
            // Дефолт роли — model: новый юзер по умолчанию модель, не агентство.
            let rawValue = UserDefaults.standard.string(forKey: roleKey) ?? UserRole.model.rawValue
            return UserRole(rawValue: rawValue) ?? .model
        }
        set {
            let oldValue = currentUserRole
            UserDefaults.standard.set(newValue.rawValue, forKey: roleKey)
            if newValue != oldValue {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: roleDidChangeNotification, object: nil)
                }
            }
        }
    }

    public static func resetRole() {
        UserDefaults.standard.removeObject(forKey: roleKey)
    }

    // MARK: - Debug token force

    private static let forcedTokenKey = "DivoConfig.forcedTestToken"

    /// Дебаг-форс на один из тестовых токенов. nil = использовать реальный токен (от phone-auth).
    /// Нужен для разработки: залочиться на известный тестовый аккаунт независимо от реального входа.
    public enum ForcedTestToken: String {
        case agency
        case model

        public var token: String {
            switch self {
            case .agency: return DivoConfig.agencyToken
            case .model: return DivoConfig.modelToken
            }
        }
        public var role: UserRole {
            switch self {
            case .agency: return .agency
            case .model: return .model
            }
        }
    }

    public static var forcedTestToken: ForcedTestToken? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: forcedTokenKey) else { return nil }
            return ForcedTestToken(rawValue: raw)
        }
        set {
            let oldValue = forcedTestToken
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: forcedTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: forcedTokenKey)
            }
            if newValue != oldValue {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: tokenDidChangeNotification, object: nil)
                    NotificationCenter.default.post(name: roleDidChangeNotification, object: nil)
                }
            }
        }
    }

    public static var accessToken: String {
        get {
            // Debug-форс на тестовый токен (если включён) перебивает реальный.
            if isDebugEnabled, let forced = forcedTestToken {
                return forced.token
            }
            return UserDefaults.standard.string(forKey: tokenKey) ?? agencyToken
        }
        set {
            let oldValue = UserDefaults.standard.string(forKey: tokenKey) ?? agencyToken
            UserDefaults.standard.set(newValue, forKey: tokenKey)
            if newValue != oldValue {
                DispatchQueue.main.async {
                    didSignalSessionExpired = false // новый токен → снова можем сигналить о протухании
                    NotificationCenter.default.post(name: tokenDidChangeNotification, object: nil)
                }
            }
        }
    }

    public static func resetToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    // MARK: - Session expiry (401)

    /// REST-401 на реальном сохранённом токене = протухшая DIVO-сессия (refresh-эндпоинта у DIVO нет).
    /// Наблюдатель в TelegramUI делает полный ре-логин (reset + logout teamgram → welcome).
    public static let sessionExpiredNotification = Notification.Name("DivoConfig.sessionExpired")

    /// true только когда effective-токен — реальный сохранённый из auth-флоу (не fallback `agencyToken`,
    /// не debug-форс). 401 на нём лечится ре-логином; 401 на fallback/форсе — нет, поэтому не сигналим.
    public static var isUsingStoredToken: Bool {
        if isDebugEnabled, forcedTestToken != nil { return false }
        return UserDefaults.standard.string(forKey: tokenKey) != nil
    }

    /// Есть настоящая DIVO-сессия (сохранённый токен из auth-флоу или debug-форс). Без неё запросы идут по
    /// fallback `agencyToken` и `/user/info` отдаёт ЧУЖОЙ профиль — синк авы/имени в teamgram на нём
    /// заливал бы чужие данные в свежий teamgram-аккаунт (окно phone-онбординга до регистрации).
    public static var hasDivoSession: Bool {
        if isDebugEnabled, forcedTestToken != nil { return true }
        return UserDefaults.standard.string(forKey: tokenKey) != nil
    }

    // Дебаунс: десятки параллельных запросов отдают 401 пачкой — сигналим один раз на сессию.
    // Снимается при записи нового токена (см. accessToken.set) — следующая протухшая сессия снова сигналит.
    private static var didSignalSessionExpired = false

    /// Зовётся из DivoAPIClient на 401. Постит `sessionExpired` один раз и только если шлём реальный
    /// сохранённый токен. Реакцию делает наблюдатель в TelegramUI: DivoCore не импортит teamgram-модули,
    /// поэтому мост через NotificationCenter.
    public static func handleUnauthorizedResponse() {
        guard isUsingStoredToken else { return }
        DispatchQueue.main.async {
            guard !didSignalSessionExpired else { return }
            didSignalSessionExpired = true
            NotificationCenter.default.post(name: sessionExpiredNotification, object: nil)
        }
    }

    public static var simulatedDelay: TimeInterval {
        get {
            return UserDefaults.standard.double(forKey: delayKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: delayKey)
        }
    }

    /// Debug доступен если в бандле есть provisioning profile (dev/TF) ИЛИ приложение запущено из Xcode/симулятора.
    /// Apple удаляет embedded.mobileprovision только при публикации в App Store — поэтому в релизе авто-выключается.
    /// disableExtensions при сборке не влияет — profile всё равно встраивается в основной бандл.
    /// В prod-сборке (divoEnv=prod, см. [[DivoEnvironment]]) дебаг-экран выключен ЖЁСТКО — не полагаемся
    /// на то, что Apple вырежет профиль: боевая сборка не покажет Debug Menu ни при каких условиях.
    public static var isDebugEnabled: Bool = {
        if DivoEnvironment.current == .prod {
            return false
        }
        #if targetEnvironment(simulator)
        return true
        #else
        return Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") != nil
        #endif
    }()

    public static let appPlatform = "ios"

    /// REST-заголовок `app-version`. Берётся из бандла (CFBundleShortVersionString + CFBundleVersion),
    /// чтобы версия не жила в двух местах — единственный источник правды это `--define=telegramVersion`
    /// на сборке. Формат сохранён прежним: «2.0.0 (buildNumber)».
    public static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    public static let shareBaseURL = "https://api.divo.fashion"
    public static let shareHost = "api.divo.fashion"

    public static let eulaURL = "https://www.divo.global/legal-documents/mobile-app-eula"
    public static let privacyPolicyURL = "https://www.divo.global/legal-documents/privacy-policy"

    // MARK: - Pending social registration (ветка D)

    /// Соц-юзер прошёл Firebase, но DIVO-аккаунта ещё нет (login-social 422). Запоминаем
    /// uid/providerId, чтобы ПОСЛЕ teamgram-входа показать онбординг и довести registration-social.
    /// Чистится по завершении онбординга.
    public struct PendingSocialRegistration: Codable, Equatable {
        public let uid: String
        public let providerId: String
        // Реальная почта из соц-провайдера → в registration-social вместо синтетики из uid. Опциональна:
        // Apple при повторном входе email не отдаёт. Старый персист без поля читается (decodeIfPresent → nil).
        public let email: String?
        // Профиль из соц-провайдера для префилла онбординга (имя/фото). Опциональны: Apple фото не
        // отдаёт, имя — только при первом входе. Старый персист без этих полей читается (nil).
        public let displayName: String?
        public let photoUrl: String?
        public init(uid: String, providerId: String, email: String? = nil, displayName: String? = nil, photoUrl: String? = nil) {
            self.uid = uid
            self.providerId = providerId
            self.email = email
            self.displayName = displayName
            self.photoUrl = photoUrl
        }
    }

    private static let pendingSocialRegKey = "DivoConfig.pendingSocialRegistration"

    public static var pendingSocialRegistration: PendingSocialRegistration? {
        get {
            guard let data = UserDefaults.standard.data(forKey: pendingSocialRegKey) else { return nil }
            return try? JSONDecoder().decode(PendingSocialRegistration.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: pendingSocialRegKey)
                NotificationCenter.default.post(name: pendingOnboardingDidChangeNotification, object: nil)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingSocialRegKey)
            }
        }
    }

    private static let pendingSocialLinkPhoneKey = "DivoConfig.pendingSocialLinkPhone"

    /// Телефон для `telegram-link` соц-ветки B (`telegramLinked=false`): после teamgram-входа сшиваем
    /// свежий teamgram-аккаунт с существующим DIVO-аккаунтом. nil = линк не нужен (ветка A — уже связан).
    public static var pendingSocialLinkPhone: String? {
        get { UserDefaults.standard.string(forKey: pendingSocialLinkPhoneKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: pendingSocialLinkPhoneKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingSocialLinkPhoneKey)
            }
        }
    }

    private static let pendingPhoneOnboardingKey = "DivoConfig.pendingPhoneOnboarding"
    private static let pendingPhoneNumberKey = "DivoConfig.pendingPhoneNumber"

    /// Phone-юзер на онбординге: DIVO-аккаунт ещё НЕ заведён (регистрация — на submit с реальной
    /// ролью + additionalInfo) ИЛИ заведён ранее, но онбординг не пройден (legacy). App-gate
    /// показывает онбординг, пока флаг true.
    public static var pendingPhoneOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: pendingPhoneOnboardingKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: pendingPhoneOnboardingKey)
            if newValue {
                NotificationCenter.default.post(name: pendingOnboardingDidChangeNotification, object: nil)
            }
        }
    }

    /// Телефон НОВОГО phone-юзера, чей DIVO-аккаунт ещё не создан — нужен на submit, чтобы
    /// зарегистрироваться (синтетический email/пароль из номера) с реальной ролью + additionalInfo.
    /// Персистится для resume на cold-start. nil = аккаунт уже есть (existing-not-done → update-profile).
    public static var pendingPhoneNumber: String? {
        get { UserDefaults.standard.string(forKey: pendingPhoneNumberKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: pendingPhoneNumberKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingPhoneNumberKey)
            }
        }
    }

    private static let pendingTeamgramProfileResetKey = "DivoConfig.pendingTeamgramProfileReset"

    /// Phone-вход попал в УЖЕ существующий teamgram-аккаунт, а DIVO-аккаунта у него нет (осиротевший
    /// teamgram — напр. после удаления DIVO-профиля, когда MTProto-удаление не прошло). Новый DIVO-аккаунт
    /// не должен унаследовать старые ава/имя: после регистрации чистим teamgram-фото и ставим DIVO-аву
    /// (см. photoUpdate в AppDelegate+DivoOnboarding). НЕ входит в clearPendingOnboardingFlags — флаг нужен
    /// ПОСЛЕ submit'а, до дренажа photoUpdate; снимается исполнителем либо на сбросе сессии.
    public static var pendingTeamgramProfileReset: Bool {
        get { UserDefaults.standard.bool(forKey: pendingTeamgramProfileResetKey) }
        set {
            if newValue {
                UserDefaults.standard.set(true, forKey: pendingTeamgramProfileResetKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pendingTeamgramProfileResetKey)
            }
        }
    }

    /// Снять ВСЕ pending-флаги онбординга разом (вход завершён / откат / cold-start). Один источник
    /// правды: эти флаги чистились вручную в нескольких местах — легко было забыть один и оставить
    /// залипший флаг, который заново триггерит онбординг или cold-start resume.
    public static func clearPendingOnboardingFlags() {
        pendingSocialRegistration = nil
        pendingSocialLinkPhone = nil
        pendingPhoneOnboarding = false
        pendingPhoneNumber = nil
    }

    /// Полный откат DIVO-сессии при фейле/отмене онбординга (правило атомарности): сбрасываем токен
    /// (геттер вернёт fallback agencyToken) + divoUserId + pending-флаги — чтобы в следующей
    /// welcome-сессии не остался чужой accessToken/currentDivoUserId, бэкающий REST не того юзера.
    public static func resetDivoSessionForRollback() {
        resetToken()
        resetRole() // роль → дефолт (model); на следующем входе перезапишется с сервера
        currentDivoUserId = nil
        clearPendingOnboardingFlags()
        pendingTeamgramProfileReset = false
        // Полный teardown моста в teamgram: очередь отложенных опов + telegramUserId/nameUpdater НЕ
        // должны пережить логаут. Иначе опы прошлого аккаунта (telegramLink) дренятся против нового
        // teamgram-аккаунта → 409 "already linked" (ловилось на тестах через разлогины).
        PendingTelegramOpsQueue.shared.clear()
        DivoTeamgramSync.shared.reset()
        // Локально сохранённые имя/фамилия (для префилла экранов правки) — per-device, не должны
        // пережить логаут, иначе следующий аккаунт префиллит чужое имя.
        DivoTeamgramName.clearLocalName()
        // История поиска по лицу — per-device кэш (фото лиц на диске), не должна утечь следующему аккаунту.
        FaceSearchHistoryStorage.shared.clearAll()
    }

    // MARK: - DIVO session user id

    private static let currentDivoUserIdKey = "DivoConfig.currentDivoUserId"

    /// divoUserId текущей DIVO-сессии (ставит PhoneAuthLinker / registration). Нужен для telegram-link
    /// и привязки отложенных операций к аккаунту.
    public static var currentDivoUserId: Int? {
        get {
            let value = UserDefaults.standard.integer(forKey: currentDivoUserIdKey)
            return value == 0 ? nil : value
        }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: currentDivoUserIdKey) }
    }

    // MARK: - Mock Mode

    private static let mockKey = "DivoConfig.isMockEnabled"

    public static var isMockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: mockKey) }
        set { UserDefaults.standard.set(newValue, forKey: mockKey) }
    }
}
