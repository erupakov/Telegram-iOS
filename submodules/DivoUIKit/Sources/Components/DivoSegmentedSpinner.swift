import UIKit

public final class DivoSegmentedSpinner: UIView {

    private var isAnimating = false
    private let segmentColor: UIColor

    public init(frame: CGRect = .zero, color: UIColor = .black) {
        self.segmentColor = color
        super.init(frame: frame)
        backgroundColor = .clear
        setupSegments()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupSegments() {
        let count = 8
        let segmentSize = CGSize(width: 3, height: 10)
        let innerRadius: CGFloat = 5.5
        let center = CGPoint(x: 16, y: 16)
        let cornerRadius: CGFloat = 1.0
        let opacities: [CGFloat] = [1.0, 0.875, 0.75, 0.625, 0.5, 0.375, 0.25, 0.125]

        for i in 0..<count {
            let angle = CGFloat(i) * (.pi * 2.0 / CGFloat(count)) - .pi / 2.0
            let dist = innerRadius + segmentSize.height / 2.0

            let seg = CALayer()
            seg.bounds = CGRect(origin: .zero, size: segmentSize)
            seg.position = CGPoint(
                x: center.x + dist * cos(angle),
                y: center.y + dist * sin(angle)
            )
            seg.cornerRadius = cornerRadius
            seg.backgroundColor = segmentColor.withAlphaComponent(opacities[i]).cgColor
            seg.transform = CATransform3DMakeRotation(angle + .pi / 2.0, 0, 0, 1)
            layer.addSublayer(seg)
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && isAnimating {
            applyAnimation()
        }
    }

    @objc private func appDidBecomeActive() {
        if isAnimating {
            applyAnimation()
        }
    }

    public func startAnimating() {
        isAnimating = true
        applyAnimation()
    }

    public func stopAnimating() {
        isAnimating = false
        layer.removeAllAnimations()
    }

    private func applyAnimation() {
        layer.removeAllAnimations()
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let count = 8
        var values: [Double] = []
        for i in 0...count {
            values.append(Double(i) * .pi * 2.0 / Double(count))
        }
        animation.values = values
        animation.keyTimes = (0...count).map { NSNumber(value: Double($0) / Double(count)) }
        animation.duration = 0.8
        animation.repeatCount = .infinity
        animation.calculationMode = .discrete
        layer.add(animation, forKey: "spin")
    }
}
