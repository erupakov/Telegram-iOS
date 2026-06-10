import Foundation

public enum DivoConfig {
    public static let baseURL = URL(string: "https://api-stage.divo.fashion/api")!

    public static let agencyToken = "Ccw5cQAMFzxCttzgpUu69NuJARelHshG78LOAHiPQEjKeMSP93OWsbc110MKc6mf"
    public static let modelToken = "GxelyeqTBVrPAJLWXRXUH4XktoUhu2QLTFfxIvgnvDD9jKBLolF6GDVQQsSzChSF"

    private static let tokenKey = "DivoConfig.customAccessToken"
    private static let delayKey = "DivoConfig.simulatedDelay"
    private static let roleKey = "DivoConfig.userRole"

    public static let tokenDidChangeNotification = Notification.Name("DivoConfig.tokenDidChange")
    public static let roleDidChangeNotification = Notification.Name("DivoConfig.roleDidChange")
    public static let profileDidUpdateNotification = Notification.Name("DivoConfig.profileDidUpdate")
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
                    NotificationCenter.default.post(name: tokenDidChangeNotification, object: nil)
                }
            }
        }
    }

    public static func resetToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
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
    /// Apple удаляет embedded.mobileprovision только при публикации в App Store.
    /// disableExtensions при сборке не влияет — profile всё равно встраивается в основной бандл.
    public static var isDebugEnabled: Bool = true

    public static let appPlatform = "ios"
    public static let appVersion = "1.1.1 (912)"

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
        // Профиль из соц-провайдера для префилла онбординга (имя/фото). Опциональны: Apple фото не
        // отдаёт, имя — только при первом входе. Старый персист без этих полей читается (nil).
        public let displayName: String?
        public let photoUrl: String?
        public init(uid: String, providerId: String, displayName: String? = nil, photoUrl: String? = nil) {
            self.uid = uid
            self.providerId = providerId
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
