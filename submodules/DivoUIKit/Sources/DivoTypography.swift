import UIKit
import Display

/// Семантические типографические стили DIVO.
///
/// Каждый стиль — это комбинация font / kern / line-height / color, зафиксированная дизайном.
/// Возвращает готовый `NSAttributedString`, чтобы потребителю не нужно было собирать
/// `NSMutableParagraphStyle` каждый раз.
public enum DivoTypography {

    /// SF Pro Semibold 13 · line-height 18 · letter-spacing −0.08 · color primaryText (#222222).
    /// Используется для заголовков модальных шторок / bottom sheet'ов.
    public static func sheetTitle(
        _ text: String,
        color: UIColor = DivoColorPalette.primaryText,
        alignment: NSTextAlignment = .center
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 18
        paragraph.maximumLineHeight = 18
        paragraph.alignment = alignment
        return NSAttributedString(
            string: text,
            attributes: [
                .font: Font.semibold(13),
                .foregroundColor: color,
                .kern: -0.08,
                .paragraphStyle: paragraph,
            ]
        )
    }
}
