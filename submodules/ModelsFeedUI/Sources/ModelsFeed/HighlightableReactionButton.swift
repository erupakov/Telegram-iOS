import UIKit

final class HighlightableReactionButton: UIButton {
    
    private let backgroundContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }()
    
    var reactionType: ReactionType?
    
    var isCurrentlySelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    func updateAppearance(forPress: Bool = false) {
        if forPress {
            self.backgroundContainer.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        } else if self.isCurrentlySelected {
            self.backgroundContainer.backgroundColor = UIColor.white
        } else {
            self.backgroundContainer.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                if self.isHighlighted {
                    self.updateAppearance(forPress: true)
                } else {
                    self.updateAppearance(forPress: false)
                }
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        insertSubview(backgroundContainer, at: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundContainer.frame = self.bounds
    }
}

class GradientView: UIView {//TODO: 
    
    enum GradientDirection {
        case vertical
        case horizontal
    }
    
    private var gradientLayer: CAGradientLayer {
        return self.layer as! CAGradientLayer
    }

    override static var layerClass: AnyClass {
        return CAGradientLayer.self
    }
    
    func configure(colors: [UIColor], direction: GradientDirection) {
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
