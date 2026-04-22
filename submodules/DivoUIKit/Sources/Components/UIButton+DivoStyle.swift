import UIKit
import ObjectiveC

/// Стили кнопок дизайн-системы DIVO.
///
/// Централизует press-state и disabled-state для всех стандартных кнопок.
/// Для `.primary` и `.secondary` автоматически переключает фон
/// (enabled ↔ `buttonDisabledBackground`) при смене `isEnabled` — через KVO.
/// Вызывающему коду достаточно выставлять `btn.isEnabled`, без ручного `backgroundColor`.
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
    private var enabledObservation: NSKeyValueObservation?

    init(style: DivoButtonStyle, button: UIButton) {
        self.style = style
        self.button = button
        super.init()
        observeIsEnabled()
        applyEnabledBackground()
        applyDisabledTitleColor()
    }

    private func applyDisabledTitleColor() {
        guard let btn = button else { return }
        switch style {
        case .primary, .secondary:
            btn.setTitleColor(DivoColorPalette.disabledText, for: .disabled)
        case .pill, .text, .accentInline:
            break
        }
    }

    private func observeIsEnabled() {
        enabledObservation = button?.observe(\.isEnabled, options: [.new]) { [weak self] _, _ in
            self?.applyEnabledBackground()
        }
    }

    private func enabledBackground() -> UIColor? {
        switch style {
        case .primary: return DivoColorPalette.accent
        case .secondary: return DivoColorPalette.secondaryButtonBackground
        case .pill, .text, .accentInline: return nil
        }
    }

    private func applyEnabledBackground() {
        guard let btn = button, let bg = enabledBackground() else { return }
        btn.backgroundColor = btn.isEnabled ? bg : DivoColorPalette.buttonDisabledBackground
    }

    @objc func pressed() {
        guard let btn = button else { return }
        let s = DivoDesignTokens.PressState.scale
        switch style {
        case .primary:
            UIView.animate(withDuration: DivoDesignTokens.PressState.pressDuration) {
                btn.backgroundColor = DivoColorPalette.accentPressed
                btn.transform = CGAffineTransform(scaleX: s, y: s)
            }
        case .secondary:
            UIView.animate(withDuration: DivoDesignTokens.PressState.pressDuration) {
                btn.backgroundColor = DivoColorPalette.secondaryButtonPressed
                btn.transform = CGAffineTransform(scaleX: s, y: s)
            }
        case .pill:
            UIView.animate(withDuration: DivoDesignTokens.PressState.pressDuration) {
                btn.alpha = 0.85
                btn.transform = CGAffineTransform(scaleX: s, y: s)
            }
        case .text:
            UIView.animate(withDuration: DivoDesignTokens.PressState.pressDuration) {
                btn.alpha = 0.5
            }
        case .accentInline:
            UIView.animate(withDuration: DivoDesignTokens.PressState.pressDuration) {
                btn.backgroundColor = DivoColorPalette.accentPressed
                btn.transform = CGAffineTransform(scaleX: s, y: s)
            }
        }
    }

    @objc func released() {
        guard let btn = button else { return }
        switch style {
        case .primary:
            UIView.animate(withDuration: DivoDesignTokens.PressState.releaseDuration) {
                btn.backgroundColor = btn.isEnabled ? DivoColorPalette.accent : DivoColorPalette.buttonDisabledBackground
                btn.transform = .identity
            }
        case .secondary:
            UIView.animate(withDuration: DivoDesignTokens.PressState.releaseDuration) {
                btn.backgroundColor = btn.isEnabled ? DivoColorPalette.secondaryButtonBackground : DivoColorPalette.buttonDisabledBackground
                btn.transform = .identity
            }
        case .pill, .text:
            UIView.animate(withDuration: DivoDesignTokens.PressState.releaseDuration) {
                btn.alpha = 1.0
                btn.transform = .identity
            }
        case .accentInline:
            UIView.animate(withDuration: DivoDesignTokens.PressState.releaseDuration) {
                btn.backgroundColor = DivoColorPalette.accent
                btn.transform = .identity
            }
        }
    }
}
