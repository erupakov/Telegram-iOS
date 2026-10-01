import Foundation

// Публичные конфиг-поля Firebase iOS SDK для DIVO-2. Соответствуют GoogleService-Info.plist, в bundle
// plist не кладём — FirebaseOptions передаём в коде (см. DivoFirebaseBootstrap), чтобы не править
// upstream Info.plist. Это PUBLIC ключи (apiKey/clientID/googleAppID etc.) — не секретные, можно в git.
//
// Набор выбирается по окружению сборки (см. [[DivoEnvironment]]): stage → Firebase-проект `divo-2-stage`,
// prod → `divodev-62848` (прод-плист Google).
public enum DivoFirebaseConfig {
    public struct Values {
        public let apiKey: String
        public let bundleID: String
        public let clientID: String
        public let reversedClientID: String
        public let gcmSenderID: String
        public let googleAppID: String
        public let projectID: String
        public let storageBucket: String
        public let databaseURL: String
    }

    private static let stage = Values(
        apiKey: "AIzaSyCDmShubmhmcNom4EhATQXydeFurIBKWRQ",
        bundleID: "app.divo.fashion",
        clientID: "121062802243-fccpe09e22b2fm9avqgnprv03avc8i9f.apps.googleusercontent.com",
        reversedClientID: "com.googleusercontent.apps.121062802243-fccpe09e22b2fm9avqgnprv03avc8i9f",
        gcmSenderID: "121062802243",
        googleAppID: "1:121062802243:ios:3f17e8fede362c2409a5f6",
        projectID: "divo-2-stage",
        storageBucket: "divo-2-stage.firebasestorage.app",
        databaseURL: "https://divo-2-stage-default-rtdb.europe-west1.firebasedatabase.app"
    )

    // Прод-набор из GoogleService-Info.plist (проект divodev-62848, iOS-приложение app.divo.fashion).
    private static let prod = Values(
        apiKey: "AIzaSyDZ8G_C8kxiGd5_tWeSTn14UHg-vvRO66A",
        bundleID: "app.divo.fashion",
        clientID: "432665781659-col2pcdjpsreehlpoc0thoufe8sgf79l.apps.googleusercontent.com",
        reversedClientID: "com.googleusercontent.apps.432665781659-col2pcdjpsreehlpoc0thoufe8sgf79l",
        gcmSenderID: "432665781659",
        googleAppID: "1:432665781659:ios:eb45d00e916fe609a8ad3e",
        projectID: "divodev-62848",
        storageBucket: "divodev-62848.firebasestorage.app",
        databaseURL: "https://divodev-62848-default-rtdb.firebaseio.com"
    )

    public static var current: Values {
        switch DivoEnvironment.current {
        case .stage: return stage
        case .prod: return prod
        }
    }

    // Плоские аксессоры для обратной совместимости с потребителями (DivoFirebaseBootstrap и др.).
    public static var apiKey: String { current.apiKey }
    public static var bundleID: String { current.bundleID }
    public static var clientID: String { current.clientID }
    public static var reversedClientID: String { current.reversedClientID }
    public static var gcmSenderID: String { current.gcmSenderID }
    public static var googleAppID: String { current.googleAppID }
    public static var projectID: String { current.projectID }
    public static var storageBucket: String { current.storageBucket }
    public static var databaseURL: String { current.databaseURL }
}
