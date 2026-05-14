import Foundation
import UIKit

// Расширение для подсчета строк
public extension String {
    func lineCount(for font: UIFont, width: CGFloat) -> Int {
        guard width > 0 else { return 0 }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes:[NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let rect = self.boundingRect(
            with: size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        
        return Int(ceil(rect.height / font.lineHeight))
    }
}

public extension UIView {
    func startShimmering() {
        let gradient = CAGradientLayer()
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        
        let baseColor = DivoColorPalette.shimmerBase.cgColor
        let highlightColor = DivoColorPalette.shimmerHighlight.cgColor
        
        gradient.colors = [baseColor, highlightColor, baseColor]
        gradient.locations = [0.0, 0.5, 1.0]
        
        gradient.frame = CGRect(x: -self.bounds.width, y: 0, width: self.bounds.width * 3, height: self.bounds.height)
        
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [0.0, 0.1, 0.2]
        animation.toValue = [0.8, 0.9, 1.0]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        
        gradient.add(animation, forKey: "shimmer")
        
        self.layer.mask = self.layer.cornerRadius > 0 ? nil : nil
        self.layer.addSublayer(gradient)
        self.layer.masksToBounds = true
    }
    
    func stopShimmering() {
        self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }
}

public extension UIView {
    func roundCorners(_ corners: UIRectCorner, radius: CGFloat) {
        var cornerMask = CACornerMask()
        
        if corners.contains(.topLeft) {
            cornerMask.insert(.layerMinXMinYCorner)
        }
        if corners.contains(.topRight) {
            cornerMask.insert(.layerMaxXMinYCorner)
        }
        if corners.contains(.bottomLeft) {
            cornerMask.insert(.layerMinXMaxYCorner)
        }
        if corners.contains(.bottomRight) {
            cornerMask.insert(.layerMaxXMaxYCorner)
        }
        if corners.contains(.allCorners) {
            cornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        
        self.layer.cornerRadius = radius
        self.layer.maskedCorners = cornerMask
        self.clipsToBounds = true
    }
}

public enum MediaFormatValidator {
    static let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv", "webm"]
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "heic"]
    
    static public func isVideo(_ ext: String?) -> Bool {
        guard let ext = ext?.lowercased() else { return false }
        return videoExtensions.contains(ext)
    }
    
    static public func isImage(_ ext: String?) -> Bool {
        guard let ext = ext?.lowercased() else { return false }
        return imageExtensions.contains(ext)
    }
}