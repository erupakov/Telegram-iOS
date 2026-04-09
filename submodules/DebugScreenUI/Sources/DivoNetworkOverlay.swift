import UIKit
import TelegramCore
import DivoCore
import Display

public final class DivoNetworkOverlay {
    public static let shared = DivoNetworkOverlay()

    private var overlayView: NetworkOverlayView?
    private var observer: NSObjectProtocol?

    private init() {}

    public func show() {
        guard overlayView == nil else { return }

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else { return }

        let view = NetworkOverlayView()
        view.frame = CGRect(x: window.bounds.width - 136, y: 60, width: 120, height: 64)
        window.addSubview(view)
        self.overlayView = view

        observer = NotificationCenter.default.addObserver(
            forName: DivoRequestLogger.newEntryNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let entry = notification.object as? DivoRequestLogEntry else { return }
            self?.overlayView?.addEntry(entry)
        }

        // Populate with existing entries
        let recent = Array(DivoRequestLogger.shared.getEntries().prefix(20).reversed())
        for entry in recent {
            view.addEntry(entry)
        }
    }

    public func hide() {
        overlayView?.removeFromSuperview()
        overlayView = nil
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    public func restoreIfNeeded() {
        if UserDefaults.standard.bool(forKey: "DivoNetworkOverlay.enabled") {
            show()
        }
    }
}

// MARK: - Overlay View

private final class NetworkOverlayView: UIView {
    private let lastLabel = UILabel()
    private let avgLabel = UILabel()
    private let barsContainer = UIView()

    private var latencies: [BarEntry] = []
    private let maxBars = 16

    private struct BarEntry {
        let duration: TimeInterval
        let isSuccess: Bool
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.white.withAlphaComponent(0.92)
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.borderWidth = 0.5
        layer.borderColor = UIColor(rgb: 0xC6C6C8).cgColor

        lastLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        lastLabel.textColor = .black
        lastLabel.text = "— мс"
        addSubview(lastLabel)

        avgLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        avgLabel.textColor = UIColor(rgb: 0x8E8E93)
        avgLabel.text = "avg — мс"
        addSubview(avgLabel)

        barsContainer.clipsToBounds = true
        addSubview(barsContainer)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError() }

    func addEntry(_ entry: DivoRequestLogEntry) {
        let bar = BarEntry(duration: entry.duration, isSuccess: entry.isSuccess)
        latencies.append(bar)
        if latencies.count > maxBars {
            latencies.removeFirst()
        }

        let ms = entry.duration * 1000
        let dot: String
        if !entry.isSuccess {
            dot = "🔴"
            lastLabel.textColor = UIColor(rgb: 0xFF3B30)
        } else if ms > 500 {
            dot = "🔴"
            lastLabel.textColor = UIColor(rgb: 0xFF3B30)
        } else if ms > 200 {
            dot = "🟡"
            lastLabel.textColor = UIColor(rgb: 0xFF9500)
        } else {
            dot = "🟢"
            lastLabel.textColor = UIColor(rgb: 0x34C759)
        }
        lastLabel.text = "\(dot) \(Int(ms))мс"

        let allMs = latencies.map { $0.duration * 1000 }
        let avg = allMs.reduce(0, +) / Double(allMs.count)
        let errCount = latencies.filter { !$0.isSuccess }.count
        var avgText = "avg \(Int(avg))мс"
        if errCount > 0 { avgText += " \(errCount)err" }
        avgLabel.text = avgText

        updateBars()
    }

    private func updateBars() {
        barsContainer.subviews.forEach { $0.removeFromSuperview() }

        guard !latencies.isEmpty else { return }

        let maxMs = max(latencies.map({ $0.duration * 1000 }).max() ?? 100, 100)
        let barW: CGFloat = 5
        let gap: CGFloat = 2
        let totalW = barsContainer.bounds.width
        let barH = barsContainer.bounds.height

        for (i, entry) in latencies.enumerated() {
            let ms = entry.duration * 1000
            let h = max(CGFloat(ms / maxMs) * barH, 2)
            let x = totalW - CGFloat(latencies.count - i) * (barW + gap)
            guard x >= 0 else { continue }

            let bar = UIView()
            bar.frame = CGRect(x: x, y: barH - h, width: barW, height: h)
            bar.layer.cornerRadius = barW / 2

            if !entry.isSuccess {
                bar.backgroundColor = UIColor(rgb: 0xFF3B30)
            } else if ms > 500 {
                bar.backgroundColor = UIColor(rgb: 0xFF3B30)
            } else if ms > 200 {
                bar.backgroundColor = UIColor(rgb: 0xFF9500)
            } else {
                bar.backgroundColor = UIColor(rgb: 0x34C759)
            }

            barsContainer.addSubview(bar)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 10
        lastLabel.frame = CGRect(x: pad, y: 6, width: bounds.width - pad * 2, height: 16)
        avgLabel.frame = CGRect(x: pad, y: 22, width: bounds.width - pad * 2, height: 14)
        barsContainer.frame = CGRect(x: pad, y: 38, width: bounds.width - pad * 2, height: 20)
        updateBars()
    }

    // MARK: - Dragging

    private var dragStart: CGPoint = .zero

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = self.superview else { return }
        let translation = gesture.translation(in: superview)

        switch gesture.state {
        case .began:
            dragStart = self.center
        case .changed:
            self.center = CGPoint(x: dragStart.x + translation.x, y: dragStart.y + translation.y)
        case .ended, .cancelled:
            let safeArea = superview.safeAreaInsets
            var newCenter = self.center
            newCenter.x = max(bounds.width / 2 + safeArea.left + 4, min(newCenter.x, superview.bounds.width - bounds.width / 2 - safeArea.right - 4))
            newCenter.y = max(bounds.height / 2 + safeArea.top + 4, min(newCenter.y, superview.bounds.height - bounds.height / 2 - safeArea.bottom - 4))
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
                self.center = newCenter
            })
        default:
            break
        }
    }
}
