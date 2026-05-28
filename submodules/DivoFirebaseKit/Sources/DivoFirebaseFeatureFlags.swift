import Foundation
import DivoCore

public final class DivoFirebaseFeatureFlags: DivoFeatureFlags {
    public init() {}

    public func bool(forKey key: String, defaultValue: Bool) -> Bool {
        // Шаг 2: RemoteConfig.remoteConfig()[key].boolValue
        return defaultValue
    }

    public func string(forKey key: String) -> String? {
        // Шаг 2: RemoteConfig.remoteConfig()[key].stringValue
        return nil
    }

    public func int(forKey key: String, defaultValue: Int) -> Int {
        // Шаг 2: Int(RemoteConfig.remoteConfig()[key].numberValue.intValue)
        return defaultValue
    }

    public func refresh() async {
        // Шаг 2: try? await RemoteConfig.remoteConfig().fetchAndActivate()
    }
}
