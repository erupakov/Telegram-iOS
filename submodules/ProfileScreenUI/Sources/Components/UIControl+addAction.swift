import UIKit

extension UIControl {
    private struct Keys {
        static var closure = 0
    }
    
    private var actionClosure: (() -> Void)? {
        get {
            return objc_getAssociatedObject(self, &Keys.closure) as? () -> Void
        }
        set {
            objc_setAssociatedObject(self, &Keys.closure, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func addAction(for controlEvents: UIControl.Event = .touchUpInside, _ closure: @escaping () -> Void) {
        actionClosure = closure
        addTarget(self, action: #selector(handleAction), for: controlEvents)
    }
    
    @objc private func handleAction() {
        actionClosure?()
    }
}

