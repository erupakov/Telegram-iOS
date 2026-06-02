import Foundation

public protocol DivoFeatureFlags: AnyObject {
    func bool(forKey key: String, defaultValue: Bool) -> Bool
    func string(forKey key: String) -> String?
    func int(forKey key: String, defaultValue: Int) -> Int
    func refresh() async
}

public enum DivoFeatureFlagsRegistry {
    public static var current: DivoFeatureFlags?

    public static func bool(_ key: String, default defaultValue: Bool = false) -> Bool {
        current?.bool(forKey: key, defaultValue: defaultValue) ?? defaultValue
    }

    public static func string(_ key: String) -> String? {
        current?.string(forKey: key)
    }

    public static func int(_ key: String, default defaultValue: Int = 0) -> Int {
        current?.int(forKey: key, defaultValue: defaultValue) ?? defaultValue
    }
}
