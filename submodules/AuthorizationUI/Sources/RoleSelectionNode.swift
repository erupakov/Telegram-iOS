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
import DivoUIKit

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
        self.roleImageNode.cornerRadius = 4
        self.roleImageNode.backgroundColor = DivoColorPalette.imagePlaceholderMedium
        self.roleImageNode.contentMode = .scaleAspectFill
        
        self.roleTitleNode = ASTextNode()
        self.roleTitleNode.attributedText = Font.helveticaNeue(title.uppercased(), 20)
        
        self.roleDescriptionNode = ASTextNode()
        self.roleDescriptionNode.attributedText = NSAttributedString(string: description, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: DivoColorPalette.overlayDarkMediumLine
        ])
        
        self.checkmarkNode = ASImageNode()
        self.checkmarkNode.image = UIImage(bundleImageName: "Components/Checkbox")
        self.checkmarkNode.tintColor = .gray
        
        let blurEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        self.backgroundBlurView = UIVisualEffectView(effect: blurEffect)
        self.backgroundBlurView.layer.cornerRadius = 4
        self.backgroundBlurView.clipsToBounds = true
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
        self.borderColor = isSelected ? DivoColorPalette.accentCopperDeep.cgColor : DivoColorPalette.overlayDarkFieldBorder.cgColor
    }
    
    @objc private func handleTap() {
        self.tapped?()
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundBlurView.frame = self.bounds
        
        let insets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        let imageInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        
        let imageSize = CGSize(width: 98, height: 110)
        let checkmarkSize = CGSize(width: 16, height: 16)
        
        self.roleImageNode.frame = CGRect(origin: CGPoint(x: imageInsets.left, y: imageInsets.top), size: imageSize)
        
        let textX = insets.left + imageSize.width
        let availableWidthForText = self.bounds.width - textX - 20 - checkmarkSize.width - 10
        
        let titleSize = self.roleTitleNode.measure(CGSize(width: availableWidthForText + 20, height: .greatestFiniteMagnitude))
        let descriptionSize = self.roleDescriptionNode.measure(CGSize(width: availableWidthForText, height: .greatestFiniteMagnitude))
                
        let textY = insets.top
        
        self.roleTitleNode.frame = CGRect(origin: CGPoint(x: textX, y: textY), size: titleSize)
        
        self.roleDescriptionNode.frame = CGRect(origin: CGPoint(x: textX, y: textY + titleSize.height + 10), size: descriptionSize)
        
        let checkmarkY = (imageSize.height + imageInsets.bottom + imageInsets.top) / 2 - checkmarkSize.width / 2
        self.checkmarkNode.frame = CGRect(origin: CGPoint(x: self.bounds.width - 16 - checkmarkSize.width, y: checkmarkY), size: checkmarkSize)
    }
}
