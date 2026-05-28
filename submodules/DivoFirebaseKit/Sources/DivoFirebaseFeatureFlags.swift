import Foundation
import DivoCore
import FirebaseRemoteConfig

public final class DivoFirebaseFeatureFlags: DivoFeatureFlags {
    public init() {}

    private var rc: RemoteConfig { RemoteConfig.remoteConfig() }

    public func bool(forKey key: String, defaultValue: Bool) -> Bool {
        let value = rc[key]
        if value.source == .static {
            return defaultValue
        }
        return value.boolValue
    }

    public func string(forKey key: String) -> String? {
        let value = rc[key]
        if value.source == .static {
            return nil
        }
        return value.stringValue
    }

    public func int(forKey key: String, defaultValue: Int) -> Int {
        let value = rc[key]
        if value.source == .static {
            return defaultValue
        }
        return value.numberValue.intValue
    }

    public func refresh() async {
        do {
            _ = try await rc.fetchAndActivate()
        } catch {
            DivoConsoleLogger.shared.log("RemoteConfig refresh failed: \(error)", level: .error)
        }
    }
}
