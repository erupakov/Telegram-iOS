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

    var onReturn: (() -> Void)?
    var onBeginEditing: (() -> Void)?

    var textField: UITextField {
        get { fieldNode.textField }
    }
    
    init(title: String, prefix: String? = nil) {
        self.prefix = prefix
        super.init()
        setup(title: title)
        addSubnode(fieldNode)
    }
    
    // MARK: - Auto Layout
    override func didLoad() {
        super.didLoad()
        
        fieldNode.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            fieldNode.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            fieldNode.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            fieldNode.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            fieldNode.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            
            self.view.heightAnchor.constraint(equalToConstant: 46.0)
        ])
    }
    
    // MARK: - Setup
    private func setup(title: String) {
        fieldNode.textField.delegate = self
        fieldNode.textField.font = Font.regular(16.0)
        fieldNode.textField.textColor = UIColor(hexString: "#222222")
        fieldNode.textField.autocapitalizationType = .none
        fieldNode.textField.autocorrectionType = .no
        fieldNode.textField.returnKeyType = .done
        
        fieldNode.backgroundColor = .white
        fieldNode.cornerRadius = 23.0
        fieldNode.clipsToBounds = true
        fieldNode.padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        updateText(userText: title)
    }
    
    // MARK: - Logic
    private func updateText(userText: String) {
        guard let prefix = prefix else { return }
        
        let fullString = NSMutableAttributedString()
        
        let prefixAttr: [NSAttributedString.Key: Any] = [
            .font: Font.regular(16.0),
            .foregroundColor: UIColor(hexString: "#222222") ?? .black
        ]
        fullString.append(NSAttributedString(string: prefix, attributes: prefixAttr))
        
        let userAttr: [NSAttributedString.Key: Any] = [
            .font: Font.regular(16.0),
            .foregroundColor: UIColor(hexString: "#222222") ?? .black
        ]
        fullString.append(NSAttributedString(string: userText, attributes: userAttr))
        
        fieldNode.textField.attributedText = fullString
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.contains("\n") {
            textField.resignFirstResponder()
            return false
        }
        
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
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        fieldNode.borderWidth = 1.0
        fieldNode.borderColor = UIColor(hexString: "#FF772D")?.cgColor
        
        onBeginEditing?()
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        fieldNode.borderWidth = 0.0
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let onReturn = onReturn {
            onReturn()
        } else {
            textField.resignFirstResponder()
        }
        return false
    }
}
