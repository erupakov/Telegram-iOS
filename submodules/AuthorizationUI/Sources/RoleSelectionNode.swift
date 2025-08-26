import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import SolidRoundedButtonNode
import AuthorizationUtils

final class RoleSelectionNode: ASDisplayNode {
    let roleImageNode: ASImageNode
    let roleTitleNode: ASTextNode
    let roleDescriptionNode: ASTextNode
    let checkmarkNode: ASImageNode
    let typeOfRole: String
    
    private let backgroundBlurView: UIVisualEffectView
    
    var isSelected: Bool = false {
        didSet {
            updateState()
        }
    }
    
    var tapped: (() -> Void)?
    
    init(roleImage: UIImage?, title: String, description: String, typeOfRole: String) {
        self.roleImageNode = ASImageNode()
        self.roleImageNode.image = roleImage
        self.roleImageNode.cornerRadius = 10
        self.roleImageNode.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        self.roleImageNode.contentMode = .scaleAspectFill
        
        self.roleTitleNode = ASTextNode()
        self.roleTitleNode.attributedText = NSAttributedString(string: title.uppercased(), attributes: [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.white
        ])
        
        self.roleDescriptionNode = ASTextNode()
        self.roleDescriptionNode.attributedText = NSAttributedString(string: description, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ])
        
        self.checkmarkNode = ASImageNode()
        self.checkmarkNode.image = UIImage(bundleImageName: "Components/Checkbox")
        self.checkmarkNode.tintColor = .gray
        
        let blurEffect = UIBlurEffect(style: .dark)
        self.backgroundBlurView = UIVisualEffectView(effect: blurEffect)
        self.backgroundBlurView.layer.cornerRadius = 6
        self.backgroundBlurView.clipsToBounds = true
        self.backgroundBlurView.alpha = 0.8
        self.typeOfRole = typeOfRole
        
        super.init()
        self.clipsToBounds = true
        self.cornerRadius = 6
        self.borderWidth = 1
        
        self.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.view.addGestureRecognizer(tapGesture)
        
        self.view.addSubview(self.backgroundBlurView)
        
        updateState()
        
        self.addSubnode(roleImageNode)
        self.addSubnode(roleTitleNode)
        self.addSubnode(roleDescriptionNode)
        self.addSubnode(checkmarkNode)
        
    }
    
    private func updateState() {
        self.checkmarkNode.image = isSelected ?  UIImage(named: "Components/CheckboxSelected") : UIImage(bundleImageName: "Components/Checkbox")
        self.checkmarkNode.tintColor = isSelected ? .blue : .gray
        self.borderColor = isSelected ? UIColor(red: 0.75, green: 0.48, blue: 0.33, alpha: 1.00).cgColor : UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.4).cgColor
    }
    
    @objc private func handleTap() {
        self.tapped?()
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundBlurView.frame = self.bounds
        
        let insets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        let imageInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        
        let imageSize = CGSize(width: 90, height: 110)
        let checkmarkSize = CGSize(width: 24, height: 24)
        
        self.roleImageNode.frame = CGRect(origin: CGPoint(x: 10, y: imageInsets.top), size: imageSize)
        
        let textX = insets.left + imageSize.width
        let availableWidthForText = self.bounds.width - textX - 20 - checkmarkSize.width - 10
        
        let titleSize = self.roleTitleNode.measure(CGSize(width: availableWidthForText + 20, height: .greatestFiniteMagnitude))
        let descriptionSize = self.roleDescriptionNode.measure(CGSize(width: availableWidthForText, height: .greatestFiniteMagnitude))
        
        let totalTextHeight = titleSize.height + (descriptionSize.height > 0 ? 10 : 0) + descriptionSize.height
        
        let textY = insets.top
        
        self.roleTitleNode.frame = CGRect(origin: CGPoint(x: textX, y: textY), size: titleSize)
        
        self.roleDescriptionNode.frame = CGRect(origin: CGPoint(x: textX, y: textY + titleSize.height + 10), size: descriptionSize)
        
        let checkmarkY = textY + (totalTextHeight - checkmarkSize.height) / 2.0
        self.checkmarkNode.frame = CGRect(origin: CGPoint(x: self.bounds.width - 15 - checkmarkSize.width, y: checkmarkY), size: checkmarkSize)
    }
}
