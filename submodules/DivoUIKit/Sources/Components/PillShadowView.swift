import UIKit

/// Тень-подложка под «стеклянные» pill-кнопки поверх фото. Кладётся под pill:
/// на светлом фоне сама кнопка сливается, а тень отделяет её (как в дизайне).
/// Форма скруглённая — shadowPath пересчитывается под текущие bounds.
public final class PillShadowView: UIView {

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.shadowColor = DivoColorPalette.shadow.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2).cgPath
    }
}
