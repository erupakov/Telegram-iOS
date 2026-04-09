import UIKit

public final class ShimmerView: UIView {

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        let base = UIColor(white: 0.88, alpha: 1.0).cgColor
        let highlight = UIColor(white: 0.96, alpha: 1.0).cgColor
        layer.colors = [base, highlight, base]
        layer.locations = [0, 0.5, 1]
        return layer
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(gradientLayer)
        backgroundColor = UIColor(white: 0.88, alpha: 1.0)
    }

    public convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
    }

    public func startShimmer() {
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0, 0, 0.1]
        animation.toValue = [0.9, 1, 1]
        animation.duration = 1.2
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        gradientLayer.add(animation, forKey: "shimmer")
    }

    public func stopShimmer() {
        gradientLayer.removeAnimation(forKey: "shimmer")
    }
}

public extension UIView {
    private static var shimmerLayerKey: UInt8 = 0

    private var shimmerOverlay: ShimmerView? {
        get { objc_getAssociatedObject(self, &UIView.shimmerLayerKey) as? ShimmerView }
        set { objc_setAssociatedObject(self, &UIView.shimmerLayerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func addShimmerOverlay() {
        guard shimmerOverlay == nil else { return }
        let overlay = ShimmerView(frame: bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.layer.cornerRadius = layer.cornerRadius
        overlay.layer.masksToBounds = true
        addSubview(overlay)
        overlay.startShimmer()
        shimmerOverlay = overlay
    }

    func removeShimmerOverlay() {
        shimmerOverlay?.stopShimmer()
        shimmerOverlay?.removeFromSuperview()
        shimmerOverlay = nil
    }
}
