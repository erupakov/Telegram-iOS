import Foundation

// Публичные конфиг-поля Firebase iOS SDK для DIVO-2 stage проекта (Firebase Console
// project `divo-2-stage`). Соответствуют GoogleService-Info.plist, в bundle plist не кладём
// — FirebaseOptions передаём в коде, чтобы не править upstream Info.plist.
//
// Это PUBLIC ключи (apiKey/clientID/googleAppID etc.) — не секретные, можно в git.
// При смене окружения (prod) — добавить новый набор и переключать через DivoConfig.
public enum DivoFirebaseConfig {
    public static let apiKey = "AIzaSyCDmShubmhmcNom4EhATQXydeFurIBKWRQ"
    public static let bundleID = "app.divo.fashion"
    public static let clientID = "121062802243-fccpe09e22b2fm9avqgnprv03avc8i9f.apps.googleusercontent.com"
    public static let reversedClientID = "com.googleusercontent.apps.121062802243-fccpe09e22b2fm9avqgnprv03avc8i9f"
    public static let gcmSenderID = "121062802243"
    public static let googleAppID = "1:121062802243:ios:3f17e8fede362c2409a5f6"
    public static let projectID = "divo-2-stage"
    public static let storageBucket = "divo-2-stage.firebasestorage.app"
    public static let databaseURL = "https://divo-2-stage-default-rtdb.europe-west1.firebasedatabase.app"
}
