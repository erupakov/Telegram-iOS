import Foundation
import DivoCore

public final class DivoFirebaseCrashlyticsReporter: DivoErrorReporter {
    public init() {}

    public func record(_ error: Error, context: [String: Any]?) {
        // Шаг 2: Crashlytics.crashlytics().record(error: error)
    }

    public func log(_ message: String) {
        // Шаг 2: Crashlytics.crashlytics().log(message)
    }

    public func setUserId(_ userId: String?) {
        // Шаг 2: Crashlytics.crashlytics().setUserID(userId ?? "")
    }
}
