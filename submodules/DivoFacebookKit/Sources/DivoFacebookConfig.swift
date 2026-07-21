import Foundation

// Конфиг Facebook (Meta) iOS SDK для DIVO (DIVI-62). Задаём в коде через FBSDKSettings,
// чтобы не править upstream Info.plist (по образцу DivoFirebaseConfig).
//
// appID и clientToken — из ТЗ «Meta SDK — iOS & Android» (App ID 1565841951920042).
// Это идентификаторы приложения Meta (не секретные ключи) — можно в git.
public enum DivoFacebookConfig {
    public static let appID = "1565841951920042"
    public static let clientToken = "8b7bd892a84a77e5cad82d38ae800e5e"
    public static let displayName = "DIVO"
}
