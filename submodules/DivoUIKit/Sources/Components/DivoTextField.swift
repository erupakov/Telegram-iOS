import Display
import UIKit
import AsyncDisplayKit

public final class DivoTextField: ASDisplayNode, UITextFieldDelegate {

    public let fieldNode = TextFieldNode()
    private let prefix: String?

    public var onReturn: (() -> Void)?
    public var onBeginEditing: (() -> Void)?

    public var isGrouped: Bool = false

    public var textField: UITextField {
        get { fieldNode.textField }
    }
    
    public init(title: String, prefix: String? = nil) {
        self.prefix = prefix
        super.init()
        setup(title: title)
        addSubnode(fieldNode)
    }
    
    // MARK: - Auto Layout
    public override func didLoad() {
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
        fieldNode.textField.textColor = DivoColorPalette.primaryText
        fieldNode.textField.autocapitalizationType = .none
        fieldNode.textField.autocorrectionType = .no
        fieldNode.textField.returnKeyType = .done
        
        fieldNode.backgroundColor = DivoColorPalette.cardBackground
        fieldNode.cornerRadius = 23.0 // TODO: DS alignment — не в шкале Radius
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
            .foregroundColor: DivoColorPalette.primaryText
        ]
        fullString.append(NSAttributedString(string: prefix, attributes: prefixAttr))
        
        let userAttr: [NSAttributedString.Key: Any] = [
            .font: Font.regular(16.0),
            .foregroundColor: DivoColorPalette.primaryText
        ]
        fullString.append(NSAttributedString(string: userText, attributes: userAttr))
        
        fieldNode.textField.attributedText = fullString
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.contains("\n") {
            textField.resignFirstResponder()
            return false
        }

        guard let prefix = prefix, !prefix.isEmpty else { return true }

        // 1. Пробуем извлечь handle (URL с/без протокола, включая голый домен)
        if let handle = extractHandle(from: string) {
            let clean = sanitizeHandle(handle)
            updateText(userText: clean)
            moveCursorToEnd(textField)
            return false
        }

        // 2. Если не извлекли, но это URL — значит чужой домен, отклоняем
        if looksLikeURL(string) {
            return false
        }

        // 3. Валидация символов (одиночный ввод или вставка plain-текста)
        if !string.isEmpty && !isValidHandleInput(string) {
            return false
        }

        // 4. Стандартная логика: prefix несъедаемый
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
            textField.sendActions(for: .editingChanged)
            return false
        }

        return false
    }

    // MARK: - Smart Paste Helpers

    private func looksLikeURL(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") || lower.contains("://")
    }

    private func extractHandle(from pastedText: String) -> String? {
        guard let prefix = prefix, !prefix.isEmpty else { return nil }

        let domain = prefix.hasSuffix("/") ? String(prefix.dropLast()) : prefix
        let candidates = [
            "https://www.\(domain)/",
            "http://www.\(domain)/",
            "https://\(domain)/",
            "http://\(domain)/",
            "www.\(domain)/",
            "\(domain)/",
        ]

        let lowercased = pastedText.lowercased()
        for candidate in candidates {
            if lowercased.hasPrefix(candidate.lowercased()) {
                let raw = String(pastedText.dropFirst(candidate.count))
                // Убираем query-параметры (?igsh=...) и фрагменты (#...)
                let clean = raw.components(separatedBy: CharacterSet(charactersIn: "?#")).first ?? raw
                return clean.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }
        return nil
    }

    private func isValidHandleInput(_ text: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._@-"))
        return text.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func sanitizeHandle(_ handle: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._@-"))
        return String(handle.unicodeScalars.filter { allowed.contains($0) })
    }

    private func moveCursorToEnd(_ textField: UITextField) {
        let end = textField.endOfDocument
        textField.selectedTextRange = textField.textRange(from: end, to: end)
    }
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        if !isGrouped {
            fieldNode.borderWidth = 1.0
            fieldNode.borderColor = DivoColorPalette.accent.cgColor
        }
        onBeginEditing?()
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        if !isGrouped {
            fieldNode.borderWidth = 0.0
        }
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let onReturn = onReturn {
            onReturn()
        } else {
            textField.resignFirstResponder()
        }
        return false
    }
}
