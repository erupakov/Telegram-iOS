import Foundation

public enum DivoBootstrap {
    public static func start() {
        DivoConsoleLogger.shared.log("DivoBootstrap.start()", level: .info)
        PendingTelegramOpsQueue.shared.drain()
    }
}
