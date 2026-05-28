import Foundation
import DivoCore
import FirebaseCrashlytics

public final class DivoFirebaseCrashlyticsReporter: DivoErrorReporter {
    public init() {}

    public func record(_ error: Error, context: [String: Any]?) {
        let crashlytics = Crashlytics.crashlytics()
        if let context = context {
            for (key, value) in context {
                crashlytics.setCustomValue(value, forKey: key)
            }
        }
        crashlytics.record(error: error)
    }

    public func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    public func setUserId(_ userId: String?) {
        Crashlytics.crashlytics().setUserID(userId ?? "")
    }
}
