import AsyncDisplayKit
import Display
import DivoUIKit

final class MultilineTextFieldNode: ASDisplayNode, ASEditableTextNodeDelegate {
    let textNode = ASEditableTextNode()

    init(placeholder: String) {
        super.init()

        self.backgroundColor = DivoColorPalette.fieldBackgroundLight
        self.borderWidth = 1.0
        self.borderColor = DivoColorPalette.overlayDarkFieldBorder.cgColor
        self.cornerRadius = 11.0
        self.clipsToBounds = true

        textNode.typingAttributes = [
            NSAttributedString.Key.font.rawValue: Font.regular(16.0),
            NSAttributedString.Key.foregroundColor.rawValue: DivoColorPalette.systemLabelBody
        ]

        textNode.attributedPlaceholderText = NSAttributedString(
            string: placeholder,
            attributes:[
                .font: Font.regular(16.0),
                .foregroundColor: DivoColorPalette.systemLabelPlaceholder
            ]
        )
        
        textNode.textContainerInset = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        textNode.delegate = self
        
        self.addSubnode(textNode)
    }
    
    override func layout() {
        super.layout()
        textNode.frame = self.bounds
    }
    
    var text: String {
        return textNode.textView.text ?? ""
    }

    func setText(_ newText: String) {
        if newText.isEmpty {
            textNode.attributedText = nil
        } else {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: Font.regular(16.0),
                .foregroundColor: DivoColorPalette.systemLabelBody
            ]
            
            textNode.attributedText = NSAttributedString(string: newText, attributes: attributes)
        }
    }
}