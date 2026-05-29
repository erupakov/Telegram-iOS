import Foundation

public enum DivoBootstrap {
    public static func start() {
        divoLog("DivoBootstrap.start()", level: .info)
        PendingTelegramOpsQueue.shared.drain()
    }
}
