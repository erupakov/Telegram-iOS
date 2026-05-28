import Foundation
import DivoCore

public enum DivoFirebaseBootstrap {
    public static func configure() {
        DivoConsoleLogger.shared.log("DivoFirebaseBootstrap.configure() — skeleton", level: .info)
        // Шаг 2: FirebaseApp.configure(options:) + Crashlytics enable + Performance + RemoteConfig fetch
        // Шаг 2: DivoErrorReporterRegistry.current = DivoFirebaseCrashlyticsReporter()
        // Шаг 2: DivoFeatureFlagsRegistry.current = DivoFirebaseFeatureFlags()
    }
}
