import UIKit
import Display
import DivoCore

public final class DivoBrandButton: UIButton {

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                layer.removeAnimation(forKey: "opacity")
                alpha = 0.55
            } else {
                alpha = 1.0
                layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
            }
        }
    }

    private func setup() {
        setTitleColor(.white, for: .normal)
        setTitleColor(DivoColors.disabledText, for: .disabled)
        titleLabel?.font = Font.helveticaNeue(20)
        backgroundColor = DivoColors.brand
        layer.cornerRadius = 28
    }
}
