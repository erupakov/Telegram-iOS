import Foundation
import Network

public final class DivoNetworkMonitor {
    public static let shared = DivoNetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.divo.networkMonitor")
    private let lock = NSLock()
    private var _isConnected = true

    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.lock.lock()
            self._isConnected = (path.status == .satisfied)
            self.lock.unlock()
        }
        monitor.start(queue: queue)
    }
}
