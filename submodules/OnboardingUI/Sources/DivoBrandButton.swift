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

    private func setup() {
        setTitleColor(.white, for: .normal)
        setTitleColor(DivoColors.disabledText, for: .disabled)
        titleLabel?.font = Font.helveticaNeue(20)
        backgroundColor = DivoColors.brand
        layer.cornerRadius = 28
    }
}
