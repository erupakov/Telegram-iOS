import Foundation 
import UIKit

extension UIColor {
    public func blend(with color: UIColor, alpha: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * alpha,
            green: g1 + (g2 - g1) * alpha,
            blue: b1 + (b2 - b1) * alpha,
            alpha: a1 + (a2 - a1) * alpha
        )
    }
}