import Foundation

public protocol DivoErrorReporter: AnyObject {
    func record(_ error: Error, context: [String: Any]?)
    func log(_ message: String)
    func setUserId(_ userId: String?)
}

public enum DivoErrorReporterRegistry {
    public static var current: DivoErrorReporter?

    public static func record(_ error: Error, context: [String: Any]? = nil) {
        current?.record(error, context: context)
    }

    public static func log(_ message: String) {
        current?.log(message)
    }

    public static func setUserId(_ userId: String?) {
        current?.setUserId(userId)
    }
}
