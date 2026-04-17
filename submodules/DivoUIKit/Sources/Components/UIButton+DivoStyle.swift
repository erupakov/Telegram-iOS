import UIKit
import ObjectiveC

/// Стили кнопок дизайн-системы DIVO.
///
/// Централизует press-state, disabled-state и цвета для всех стандартных кнопок.
/// Заменяет дублированные `buttonPressed`/`buttonReleased` пары в контроллерах.
///
/// Использование:
/// ```
/// button.addDivoPressState(.primary)
/// // или для pill-кнопок:
/// button.addDivoPressState(.pill)
/// ```
public enum DivoButtonStyle {
    /// Оранжевая Primary (фон accent → accentPressed, disabled #E4E4E4).
    case primary
    /// Чёрная Secondary (фон #343434 → #000000, disabled #E4E4E4).
    case secondary
    /// Pill-кнопка (filter/close) — мягкий alpha + scale.
    case pill
    /// Текстовая кнопка (Reset, More Filters) — только alpha.
    case text
    /// Акцентная inline-кнопка (Face Scan) — только alpha, без scale.
    case accentInline
}

private var divoStyleHandlerKey: UInt8 = 0

extension UIButton {

    /// Добавляет стандартный DIVO press-state для кнопки.
    ///
    /// - Parameter style: стиль из `DivoButtonStyle`.
    public func addDivoPressState(_ style: DivoButtonStyle) {
        guard objc_getAssociatedObject(self, &divoStyleHandlerKey) == nil else { return }

        let handler = DivoButtonPressHandler(style: style, button: self)

        addTarget(handler, action: #selector(DivoButtonPressHandler.pressed), for: .touchDown)
        addTarget(handler, action: #selector(DivoButtonPressHandler.released), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        objc_setAssociatedObject(self, &divoStyleHandlerKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private final class DivoButtonPressHandler: NSObject {
    let style: DivoButtonStyle
    weak var button: UIButton?

    init(style: DivoButtonStyle, button: UIButton) {
        self.style = style
        self.button = button
        super.init()
    }

    @objc func pressed() {
        guard let btn = button else { return }
        switch style {
        case .primary:
            UIView.animate(withDuration: 0.1) {
                btn.backgroundColor = DivoColorPalette.accentPressed
                btn.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            }
        case .secondary:
            UIView.animate(withDuration: 0.1) {
                btn.backgroundColor = DivoColorPalette.secondaryButtonPressed
                btn.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            }
        case .pill:
            UIView.animate(withDuration: 0.1) {
                btn.alpha = 0.85
                btn.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        case .text:
            UIView.animate(withDuration: 0.1) {
                btn.alpha = 0.5
            }
        case .accentInline:
            UIView.animate(withDuration: 0.1) {
                btn.backgroundColor = DivoColorPalette.accentPressed
                btn.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        }
    }

    @objc func released() {
        guard let btn = button else { return }
        switch style {
        case .primary:
            UIView.animate(withDuration: 0.2) {
                btn.backgroundColor = btn.isEnabled ? DivoColorPalette.accent : DivoColorPalette.buttonDisabledBackground
                btn.transform = .identity
            }
        case .secondary:
            UIView.animate(withDuration: 0.2) {
                btn.backgroundColor = btn.isEnabled ? DivoColorPalette.secondaryButtonBackground : DivoColorPalette.buttonDisabledBackground
                btn.transform = .identity
            }
        case .pill, .text:
            UIView.animate(withDuration: 0.2) {
                btn.alpha = 1.0
                btn.transform = .identity
            }
        case .accentInline:
            UIView.animate(withDuration: 0.2) {
                btn.backgroundColor = DivoColorPalette.accent
                btn.transform = .identity
            }
        }
    }
}
