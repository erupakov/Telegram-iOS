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

    public static var accessToken: String {
        get {
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

    // MARK: - Mock Mode

    private static let mockKey = "DivoConfig.isMockEnabled"

    public static var isMockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: mockKey) }
        set { UserDefaults.standard.set(newValue, forKey: mockKey) }
    }
}
