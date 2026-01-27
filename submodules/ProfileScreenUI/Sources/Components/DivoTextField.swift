import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import SearchUI
import ChatListSearchItemHeader
import AppBundle
import ItemListUI

final class DivoTextField: ASDisplayNode, UITextFieldDelegate {
    
    let fieldNode = TextFieldNode()
    private let prefix: String?
    
    var textField: UITextField {
        get { fieldNode.textField }
    }
    
    init(title: String, prefix: String? = nil) {
        self.prefix = prefix
        super.init()
        setup(title: title)
        addSubnode(fieldNode)
    }
    
    private func setup(title: String) {
        fieldNode.textField.delegate = self
        fieldNode.textField.font = Font.regular(16.0)
        fieldNode.textField.textColor = .white
        fieldNode.textField.autocapitalizationType = .none
        fieldNode.textField.autocorrectionType = .no
        
        fieldNode.borderWidth = 1.0
        fieldNode.borderColor = UIColor(white: 1.0, alpha: 0.4).cgColor
        fieldNode.cornerRadius = 11.0
        fieldNode.clipsToBounds = true
        fieldNode.padding = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        
        if let prefix = prefix, !prefix.isEmpty {
            updateText(userText: title)
        } else {
            let placeholderAttributes: [NSAttributedString.Key: Any] = [
                .font: Font.regular(16.0),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.4)
            ]
            fieldNode.textField.attributedPlaceholder = NSAttributedString(
                string: title,
                attributes: placeholderAttributes
            )
        }
    }
    
    private func updateText(userText: String) {
        guard let prefix = prefix else { return }
        
        let fullString = NSMutableAttributedString()
        
        let prefixAttr: [NSAttributedString.Key: Any] = [
            .font: Font.bold(16.0),
            .foregroundColor: UIColor(white: 1.0, alpha: 0.4)
        ]
        fullString.append(NSAttributedString(string: prefix, attributes: prefixAttr))
        
        let userAttr: [NSAttributedString.Key: Any] = [
            .font: Font.regular(16.0),
            .foregroundColor: UIColor.white
        ]
        fullString.append(NSAttributedString(string: userText, attributes: userAttr))
        
        fieldNode.textField.attributedText = fullString
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let prefix = prefix, !prefix.isEmpty else { return true }
        
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        if updatedText.hasPrefix(prefix) {
            let userPart = String(updatedText.dropFirst(prefix.count))
            updateText(userText: userPart)
            
            let newPosition = textField.position(from: textField.beginningOfDocument, offset: range.location + string.count)
            if let newPosition = newPosition {
                textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
            }
            return false
        }
        
        return false
    }
    
    override func layout() {
        super.layout()
        fieldNode.frame = self.bounds
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 48.0)
    }
}
