import UIKit
import Display

public enum DivoColorPalette {
    // MARK: - Brand
    public static let accent = UIColor(hexString: "#FF772D")!           // DIVO orange
    public static let accentSecondary = UIColor(hexString: "#BF7A54")!  // copper
    public static let roleBadgeBlue = UIColor(red: 34/255, green: 98/255, blue: 216/255, alpha: 1)

    // MARK: - Text
    public static let primaryText = UIColor(hexString: "#222222")!
    public static let secondaryText = UIColor(white: 153/255, alpha: 1) // #999999
    public static let disabledText = UIColor(white: 0.69, alpha: 1)     // #AFAFB1
    public static let primaryTextOnDark: UIColor = .white

    // MARK: - Surfaces
    public static let cardBackground = UIColor.white
    public static let screenBackground = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1) // #F0F0F0
    public static let darkBackground = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1)

    // MARK: - Controls
    public static let shadow = UIColor.black                            // применяется с alpha 0.08/0.1
    public static let disabledButtonBackground = UIColor(red: 0.322, green: 0.322, blue: 0.322, alpha: 1)

    // MARK: - Translucent overlays (поверх изображений/тёмных подложек)
    public static let overlayHighlight = UIColor.white.withAlphaComponent(0.16)
    public static let overlayCell = UIColor.white.withAlphaComponent(0.2)
    public static let overlayInput = UIColor.white.withAlphaComponent(0.1)
    public static let overlayInputIcon = UIColor.white.withAlphaComponent(0.5)
    public static let sectionIndex: UIColor = .white

    // MARK: - Stat pills (на карточках моделей)
    public static let statPillBackground = UIColor.white.withAlphaComponent(0.2)
    public static let statPillBorder = UIColor.white.withAlphaComponent(0.4)
}
