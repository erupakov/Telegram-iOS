import UIKit
import DivoUIKit

final class HighlightableReactionButton: UIButton {

    private let backgroundContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = DivoDesignTokens.Radius.pill
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