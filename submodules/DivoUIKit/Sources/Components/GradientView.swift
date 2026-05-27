import UIKit

public class GradientView: UIView {

    public enum GradientDirection {
        case vertical
        case horizontal
    }

    private var gradientLayer: CAGradientLayer {
        return self.layer as! CAGradientLayer
    }

    override public static var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    public func configure(colors: [UIColor], direction: GradientDirection) {
        gradientLayer.colors = colors.map { $0.cgColor }
        switch direction {
        case .vertical:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        case .horizontal:
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        }
    }
}