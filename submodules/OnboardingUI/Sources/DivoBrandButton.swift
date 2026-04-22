import UIKit
import Display
import DivoUIKit

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
        titleLabel?.font = Font.helveticaNeue(20)
        backgroundColor = DivoColorPalette.accent
        layer.cornerRadius = 28
        addDivoPressState(.primary)
    }
}
