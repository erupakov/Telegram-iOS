import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences

final class DivoTextView: ASDisplayNode, ASEditableTextNodeDelegate { //TODO: Move to common
    
    private let backgroundNode = ASDisplayNode()
    private let titleNode = ASTextNode()
    private let textNode = ASEditableTextNode()
    
    private let title: String
    
    var text: String {
        get {
            return textNode.textView.text ?? ""
        }
    }
    
    init(title: String, initialText: String = "") {
        self.title = title
        super.init()
        
        setupNodes()
        if !initialText.isEmpty {
            textNode.attributedText = NSAttributedString(
                string: initialText,
                attributes: [
                    .font: Font.regular(16.0),
                    .foregroundColor: UIColor.white
                ]
            )
        }
    }
    
    private func setupNodes() {
        backgroundNode.backgroundColor = .clear
        backgroundNode.borderWidth = 1.0
        backgroundNode.borderColor = UIColor(white: 1.0, alpha: 0.2).cgColor
        backgroundNode.cornerRadius = 11.0
        addSubnode(backgroundNode)
        
        titleNode.attributedText = NSAttributedString(
            string: title,
            attributes: [
                .font: Font.regular(14.0),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.4)
            ]
        )
        addSubnode(titleNode)
        
        textNode.delegate = self
        textNode.textView.font = Font.regular(16.0)
        textNode.textView.textColor = .white
        textNode.textView.backgroundColor = .clear
//        textNode.textView.typingAttributes = [
//            NSAttributedString.Key.font.rawValue: Font.regular(16.0),
//            NSAttributedString.Key.foregroundColor.rawValue: UIColor.white
//        ]
        
        textNode.textView.textContainerInset = .zero
        textNode.textView.textContainer.lineFragmentPadding = 0
        
        addSubnode(textNode)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let inset: CGFloat = 12.0
        let titleHeight: CGFloat = 20.0
        
        backgroundNode.frame = bounds
        
        let titleSize = titleNode.measure(CGSize(width: bounds.width - (inset * 2), height: titleHeight))
        titleNode.frame = CGRect(
            origin: CGPoint(x: inset, y: 10.0),
            size: titleSize
        )
        
        let textY = titleNode.frame.maxY + 10.0
        let textWidth = bounds.width - (inset * 2)
        let textHeight = bounds.height - textY - 12.0
        
        textNode.frame = CGRect(
            x: inset,
            y: textY,
            width: textWidth,
            height: textHeight
        )
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let inset: CGFloat = 12.0
        let titleHeight: CGFloat = 20.0
        let topPadding: CGFloat = 10.0
        let middlePadding: CGFloat = 4.0
        let bottomPadding: CGFloat = 12.0
        
        let minHeight: CGFloat = 120.0
        
        let textMeasuredSize = textNode.calculateSizeThatFits(
            CGSize(width: constrainedSize.width - (inset * 2), height: constrainedSize.height)
        )
        
        let calculatedHeight = topPadding + titleHeight + middlePadding + textMeasuredSize.height + bottomPadding
        
        return CGSize(width: constrainedSize.width, height: max(minHeight, calculatedHeight))
    }
    
    func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        self.setNeedsLayout()
//        self.relayoutIncludingSubnodes()
    }
}
