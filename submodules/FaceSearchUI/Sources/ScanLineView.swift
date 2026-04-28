import UIKit
import DivoUIKit

final class ScanLineView: UIView {

    private let lineLayer = CAGradientLayer()
    private let trailLayer = CAGradientLayer()
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    private let cycleDuration: CFTimeInterval = 2.0
    private let trailHeight: CGFloat = 60
    private let lineHeight: CGFloat = 3

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        isUserInteractionEnabled = false

        trailLayer.colors = [
            DivoColorPalette.accent.withAlphaComponent(0.0).cgColor,
            DivoColorPalette.accent.withAlphaComponent(0.15).cgColor,
            DivoColorPalette.accent.withAlphaComponent(0.3).cgColor
        ]
        trailLayer.locations = [0, 0.6, 1]
        trailLayer.startPoint = CGPoint(x: 0.5, y: 0)
        trailLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(trailLayer)

        lineLayer.colors = [
            DivoColorPalette.accent.withAlphaComponent(0.6).cgColor,
            DivoColorPalette.accent.cgColor,
            DivoColorPalette.accent.withAlphaComponent(0.6).cgColor
        ]
        lineLayer.startPoint = CGPoint(x: 0, y: 0.5)
        lineLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(lineLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Animation

    func startAnimating() {
        stopAnimating()
        animationStartTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
        lineLayer.isHidden = true
        trailLayer.isHidden = true
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - animationStartTime
        let progress = (elapsed.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration

        let h = bounds.height
        guard h > 0 else { return }

        lineLayer.isHidden = false
        trailLayer.isHidden = false

        let lineY = h * CGFloat(progress)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        lineLayer.frame = CGRect(x: 0, y: lineY - lineHeight / 2, width: bounds.width, height: lineHeight)

        let trailTop = max(0, lineY - trailHeight)
        trailLayer.frame = CGRect(x: 0, y: trailTop, width: bounds.width, height: lineY - trailTop)

        CATransaction.commit()
    }
}
