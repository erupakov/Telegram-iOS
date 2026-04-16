import UIKit

extension UIView {

    /// Pop/bounce-анимация: scale 1.0 → peak → 1.0 (spring).
    ///
    /// Используется для визуального отклика на лайк/сохранение —
    /// мгновенный «подпрыг» иконки без задержки.
    ///
    /// - Parameter scale: пиковый масштаб (по умолчанию 1.15).
    public func divoPopAnimate(scale: CGFloat = 1.15) {
        transform = .identity
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.45,
            initialSpringVelocity: 0.8,
            options: [.allowUserInteraction, .curveEaseOut],
            animations: {
                self.transform = CGAffineTransform(scaleX: scale, y: scale)
            },
            completion: { _ in
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    usingSpringWithDamping: 0.6,
                    initialSpringVelocity: 0,
                    options: [.allowUserInteraction],
                    animations: {
                        self.transform = .identity
                    }
                )
            }
        )
    }
}
