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
    /// Опционально применяется и лёгкий scale — для list-row-ячеек на карточках.
    ///
    /// Безопасен для scroll-контейнеров: при начале скролла жест отменяется и alpha/scale возвращаются.
    /// Не конфликтует с `UITapGestureRecognizer` — распознавание параллельное.
    ///
    /// - Parameters:
    ///   - alpha: alpha при нажатии. По умолчанию `PressState.alpha` (0.65) —
    ///     для ячеек с прозрачным фоном используйте `PressState.alphaOnClear` (0.4).
    ///   - scale: scale при нажатии. По умолчанию `1.0` (без scale). Для list-row-ячеек
    ///     используйте `PressState.scaleListRow` (0.98).
    public func addPressState(alpha: CGFloat = DivoDesignTokens.PressState.alpha, scale: CGFloat = 1.0) {
        guard objc_getAssociatedObject(self, &pressHandlerKey) == nil else { return }

        let handler = PressStateHandler()
        handler.targetView = self
        handler.pressAlpha = alpha
        handler.pressScale = scale

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
    var pressScale: CGFloat = 1.0

    @objc func handlePress(_ gesture: UILongPressGestureRecognizer) {
        guard let view = targetView else { return }
        switch gesture.state {
        case .began:
            UIView.animate(withDuration: DivoDesignTokens.PressState.pressDuration) {
                view.alpha = self.pressAlpha
                if self.pressScale != 1.0 {
                    view.transform = CGAffineTransform(scaleX: self.pressScale, y: self.pressScale)
                }
            }
        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: DivoDesignTokens.PressState.releaseDuration) {
                view.alpha = 1.0
                view.transform = .identity
            }
        default:
            break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}
