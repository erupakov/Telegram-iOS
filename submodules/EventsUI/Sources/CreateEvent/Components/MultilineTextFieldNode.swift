import AsyncDisplayKit
import Display

final class MultilineTextFieldNode: ASDisplayNode, ASEditableTextNodeDelegate {
    let textNode = ASEditableTextNode()
    
    init(placeholder: String) {
        super.init()
        
        self.backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 1.00)
        self.borderWidth = 1.0
        self.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        self.cornerRadius = 11.0
        self.clipsToBounds = true
        
        textNode.typingAttributes = [
            NSAttributedString.Key.font.rawValue: Font.regular(16.0),
            NSAttributedString.Key.foregroundColor.rawValue: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1.0)
        ]
        
        textNode.attributedPlaceholderText = NSAttributedString(
            string: placeholder,
            attributes:[
                .font: Font.regular(16.0),
                .foregroundColor: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6)
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
                .foregroundColor: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1.0)
            ]
            
            textNode.attributedText = NSAttributedString(string: newText, attributes: attributes)
        }
    }
}