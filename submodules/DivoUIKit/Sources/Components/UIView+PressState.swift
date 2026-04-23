import UIKit
import ObjectiveC

/// Press-state для интерактивных ячеек дизайн-системы DIVO.
///
/// Правило: **все тапабельные ячейки** (фильтры, дропдауны, опции) должны давать визуальный отклик
/// при нажатии. Вызов `addPressState()` добавляет стандартный alpha-эффект из `DivoDesignTokens.PressState`.
///
/// - Ячейки с непрозрачным фоном (FilterRowView): `addPressState()` — фон сам «проваливается», alpha = 0.65.
/// - Ячейки с прозрачным фоном (AppearanceFilterRowView, option cells): `addPressState(alpha:)` с более
///   низким значением (`PressState.alphaOnClear = 0.4`), чтобы эффект был заметен.
///
/// Кнопки (`UIButton`) управляют press-state самостоятельно — для них `addPressState()` не нужен.

private var pressHandlerKey: UInt8 = 0

extension UIView {

    /// Добавляет стандартный press-state: alpha снижается при нажатии, восстанавливается при отпускании.
    ///
    /// Безопасен для scroll-контейнеров: при начале скролла жест отменяется и alpha возвращается.
    /// Не конфликтует с `UITapGestureRecognizer` — распознавание параллельное.
    ///
    /// - Parameter alpha: alpha при нажатии. По умолчанию `PressState.alpha` (0.65) —
    ///   для ячеек с прозрачным фоном используйте `PressState.alphaOnClear` (0.4).
    public func addPressState(alpha: CGFloat = DivoDesignTokens.PressState.alpha) {
        guard objc_getAssociatedObject(self, &pressHandlerKey) == nil else { return }

        let handler = PressStateHandler()
        handler.targetView = self
        handler.pressAlpha = alpha

        let press = UILongPressGestureRecognizer(target: handler, action: #selector(PressStateHandler.handlePress(_:)))
        press.minimumPressDuration = 0
        press.cancelsTouchesInView = false
        press.delegate = handler
        addGestureRecognizer(press)

        objc_setAssociatedObject(self, &pressHandlerKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

extension UITableViewCell {

    /// Press-state для ячеек списков: белая заливка `contentView` + лёгкий scale.
    ///
    /// Вызывать из `setHighlighted(_:animated:)`. Используется в DIVO-ячейках, которые
    /// живут на сером/экранном фоне (поиск DIVO-профиля, списки interaction).
    public func applyDivoListHighlight(_ highlighted: Bool) {
        let duration = highlighted
            ? DivoDesignTokens.PressState.pressDuration
            : DivoDesignTokens.PressState.releaseDuration
        UIView.animate(withDuration: duration) {
            self.contentView.backgroundColor = highlighted
                ? DivoColorPalette.cardBackground
                : .clear
            let scale = DivoDesignTokens.PressState.scaleListRow
            self.contentView.transform = highlighted
                ? CGAffineTransform(scaleX: scale, y: scale)
                : .identity
        }
    }
}

private final class PressStateHandler: NSObject, UIGestureRecognizerDelegate {
    weak var targetView: UIView?
    var pressAlpha: CGFloat = DivoDesignTokens.PressState.alpha

    @objc func handlePress(_ gesture: UILongPressGestureRecognizer) {
        guard let view = targetView else { return }
        switch gesture.state {
        case .began:
            UIView.animate(withDuration: DivoDesignTokens.PressState.pressDuration) {
                view.alpha = self.pressAlpha
            }
        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: DivoDesignTokens.PressState.releaseDuration) {
                view.alpha = 1.0
            }
        default:
            break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}
