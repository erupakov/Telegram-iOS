import UIKit

/// Helpers для шрифтов DIVO дизайн-системы, дополняющие `Font.*` из `Display`.
///
/// `Display.Font.helveticaNeue(...)` возвращает `HelveticaNeue-CondensedBold`
/// (кондензированный жирный, используется в DivoButton и крупных заголовках).
/// DIVO дизайн использует также обычные стили HelveticaNeue (Regular, Medium) —
/// для них этот helper.
///
/// Все методы имеют system-fallback на случай, если шрифт не зарегистрирован.
public enum DivoFont {
    /// Helvetica Neue Regular.
    public static func helveticaNeueRegular(_ size: CGFloat) -> UIFont {
        return UIFont(name: "HelveticaNeue", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .regular)
    }

    /// Helvetica Neue Medium.
    public static func helveticaNeueMedium(_ size: CGFloat) -> UIFont {
        return UIFont(name: "HelveticaNeue-Medium", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .medium)
    }
}
