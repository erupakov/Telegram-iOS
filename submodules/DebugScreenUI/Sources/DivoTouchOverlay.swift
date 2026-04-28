import UIKit

public final class DivoTouchOverlay {
    public static let shared = DivoTouchOverlay()

    private var overlayWindow: TouchOverlayWindow?
    private static var isSwizzled = false

    private init() {}

    public func show() {
        guard overlayWindow == nil else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }

        let window = TouchOverlayWindow(windowScene: scene)
        window.windowLevel = .statusBar + 100
        window.isUserInteractionEnabled = false
        window.rootViewController = TouchOverlayViewController()
        window.isHidden = false
        window.backgroundColor = .clear
        self.overlayWindow = window

        Self.swizzleSendEventIfNeeded()
    }

    public func hide() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
    }

    public func restoreIfNeeded() {
        if UserDefaults.standard.bool(forKey: "DivoTouchOverlay.enabled") {
            show()
        }
    }

    fileprivate func handleTouch(_ touch: UITouch) {
        guard let vc = overlayWindow?.rootViewController as? TouchOverlayViewController else { return }
        let location = touch.location(in: overlayWindow)
        let id = ObjectIdentifier(touch)

        switch touch.phase {
        case .began:
            vc.touchBegan(id: id, at: location)
        case .moved:
            vc.touchMoved(id: id, at: location)
        case .ended, .cancelled:
            vc.touchEnded(id: id)
        default:
            break
        }
    }

    private static func swizzleSendEventIfNeeded() {
        guard !isSwizzled else { return }
        isSwizzled = true

        guard let original = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.sendEvent(_:))),
              let swizzled = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.divo_touchOverlay_sendEvent(_:)))
        else { return }
        method_exchangeImplementations(original, swizzled)
    }
}

// MARK: - Swizzle

extension UIApplication {
    @objc fileprivate func divo_touchOverlay_sendEvent(_ event: UIEvent) {
        divo_touchOverlay_sendEvent(event)

        guard event.type == .touches, let touches = event.allTouches else { return }
        for touch in touches {
            DivoTouchOverlay.shared.handleTouch(touch)
        }
    }
}

// MARK: - Window

private final class TouchOverlayWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

// MARK: - ViewController

private final class TouchOverlayViewController: UIViewController {
    private var indicators: [ObjectIdentifier: TouchIndicatorView] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    func touchBegan(id: ObjectIdentifier, at point: CGPoint) {
        let indicator = TouchIndicatorView()
        indicator.center = point
        view.addSubview(indicator)
        indicators[id] = indicator
        indicator.animateAppear()
    }

    func touchMoved(id: ObjectIdentifier, at point: CGPoint) {
        indicators[id]?.center = point
    }

    func touchEnded(id: ObjectIdentifier) {
        guard let indicator = indicators[id] else { return }
        indicators.removeValue(forKey: id)
        indicator.animateDisappear { [weak indicator] in
            indicator?.removeFromSuperview()
        }
    }
}

// MARK: - Indicator

private final class TouchIndicatorView: UIView {
    private static let dotSize: CGFloat = 44

    override init(frame: CGRect) {
        let size = Self.dotSize
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: size, height: size)))

        layer.cornerRadius = size / 2
        backgroundColor = UIColor.white.withAlphaComponent(0.5)
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 6
        layer.shadowOffset = .zero
    }

    required init?(coder: NSCoder) { fatalError() }

    func animateAppear() {
        transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
        alpha = 0
        UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseOut) {
            self.transform = .identity
            self.alpha = 1
        }
    }

    func animateDisappear(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        }, completion: { _ in
            completion()
        })
    }
}
