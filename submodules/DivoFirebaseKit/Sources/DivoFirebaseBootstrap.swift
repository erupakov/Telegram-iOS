import Foundation
import DivoCore
import FirebaseCore
import FirebaseCrashlytics
import FirebaseRemoteConfig

public enum DivoFirebaseBootstrap {
    public static func configure() {
        guard FirebaseApp.app() == nil else {
            divoLog("DivoFirebaseBootstrap.configure() — already configured, skip", level: .info)
            return
        }

        let options = FirebaseOptions(
            googleAppID: DivoFirebaseConfig.googleAppID,
            gcmSenderID: DivoFirebaseConfig.gcmSenderID
        )
        options.apiKey = DivoFirebaseConfig.apiKey
        options.clientID = DivoFirebaseConfig.clientID
        options.bundleID = DivoFirebaseConfig.bundleID
        options.projectID = DivoFirebaseConfig.projectID
        options.storageBucket = DivoFirebaseConfig.storageBucket
        options.databaseURL = DivoFirebaseConfig.databaseURL

        FirebaseApp.configure(options: options)

        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        DivoErrorReporterRegistry.current = DivoFirebaseCrashlyticsReporter()
        DivoFeatureFlagsRegistry.current = DivoFirebaseFeatureFlags()

        configureRemoteConfig()

        divoLog("Firebase configured, projectID=\(DivoFirebaseConfig.projectID)", level: .info)
    }

    private static func configureRemoteConfig() {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        Task {
            do {
                _ = try await remoteConfig.fetchAndActivate()
                divoLog("RemoteConfig fetched", level: .info)
            } catch {
                divoLog("RemoteConfig fetch failed: \(error)", level: .error)
            }
        }
    }
}
