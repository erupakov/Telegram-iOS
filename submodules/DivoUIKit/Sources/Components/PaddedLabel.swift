import UIKit

public final class PaddedLabel: UILabel {
    public var textInsets = UIEdgeInsets.zero {
        didSet { invalidateIntrinsicContentSize() }
    }
    
    override public func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let insetRect = bounds.inset(by: textInsets)
        let textRect = super.textRect(forBounds: insetRect, limitedToNumberOfLines: numberOfLines)
        let invertedInsets = UIEdgeInsets(
            top: -textInsets.top,
            left: -textInsets.left,
            bottom: -textInsets.bottom,
            right: -textInsets.right
        )
        return textRect.inset(by: invertedInsets)
    }
    
    override public func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
}