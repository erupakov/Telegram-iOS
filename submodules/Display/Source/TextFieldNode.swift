import Foundation
import UIKit
import AsyncDisplayKit

public final class TextFieldNodeView: UITextField {
    public var didDeleteBackwardWhileEmpty: (() -> Void)?
    
    var fixOffset: Bool = true
    var padding: UIEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    
    override public func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override public func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override public func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: padding)
    }
    
    override public func deleteBackward() {
        if self.text == nil || self.text!.isEmpty {
            self.didDeleteBackwardWhileEmpty?()
        }
        super.deleteBackward()
    }
    
    override public var keyboardAppearance: UIKeyboardAppearance {
        get {
            return super.keyboardAppearance
        }
        set {
            guard newValue != self.keyboardAppearance else {
                return
            }
            let resigning = self.isFirstResponder
            if resigning {
                self.resignFirstResponder()
            }
            super.keyboardAppearance = newValue
            if resigning {
                self.becomeFirstResponder()
            }
        }
    }
}

public class TextFieldNode: ASDisplayNode {
    public var textField: TextFieldNodeView {
        return self.view as! TextFieldNodeView
    }
    
    public var fixOffset: Bool = true {
        didSet {
            self.textField.fixOffset = self.fixOffset
        }
    }
    
    public var padding: UIEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) {
        didSet {
            self.textField.padding = self.padding
        }
    }
    
    
    override public init() {
        super.init()
        
        self.setViewBlock({
            return TextFieldNodeView()
        })
    }
}
