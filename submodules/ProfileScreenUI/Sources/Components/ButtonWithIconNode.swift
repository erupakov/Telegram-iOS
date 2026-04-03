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

final class ButtonWithIconNode: ASControlNode {
    
    private let titleLabel: PaddedLabel
    private let iconNode: ASImageNode
    private let spacing: CGFloat
    private let imageSize: CGSize
    
    init(title: String, icon: UIImage?, theme: PresentationTheme, spacing: CGFloat, imageSize: CGSize) {
        self.spacing = spacing
        self.imageSize = imageSize
        
        self.titleLabel = PaddedLabel()
        self.titleLabel.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0) 
        self.titleLabel.font = Font.helveticaNeue(16)
        self.titleLabel.textColor = .white
        self.titleLabel.text = title
        self.titleLabel.textAlignment = .center
        
        self.iconNode = ASImageNode()
        self.iconNode.image = icon
        self.iconNode.contentMode = .scaleAspectFit
        
        super.init()
        
        self.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.cornerRadius = 6
        
        if icon != nil {
            self.addSubnode(self.iconNode)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addSubview(self.titleLabel)
        
        self.titleLabel.isUserInteractionEnabled = false 
    }
    
    override func layout() {
        super.layout()
        
        let maxSize = CGSize(width: self.bounds.width - (self.iconNode.image != nil ? self.imageSize.width + self.spacing : 0), height: self.bounds.height)
        let titleSize = self.titleLabel.sizeThatFits(maxSize)
        
        if self.iconNode.image != nil {
            let contentWidth = self.imageSize.width + self.spacing + titleSize.width
            let contentOriginX = (self.bounds.width - contentWidth) / 2.0
            
            self.iconNode.frame = CGRect(
                x: contentOriginX,
                y: (self.bounds.height - self.imageSize.height) / 2.0,
                width: self.imageSize.width,
                height: self.imageSize.height
            )
            
            self.titleLabel.frame = CGRect(
                x: contentOriginX + self.imageSize.width + self.spacing,
                y: (self.bounds.height - titleSize.height) / 2.0,
                width: titleSize.width,
                height: titleSize.height
            )
        } else {
            self.titleLabel.frame = CGRect(
                x: (self.bounds.width - titleSize.width) / 2.0,
                y: (self.bounds.height - titleSize.height) / 2.0,
                width: titleSize.width,
                height: titleSize.height
            )
        }
    }
    
    func setTitle(_ title: String, with font: UIFont? = nil, with color: UIColor? = nil, for state: UIControl.State = .normal) {
        self.titleLabel.text = title
        if let font = font {
            self.titleLabel.font = font
        }
        if let color = color {
            self.titleLabel.textColor = color
        }
        self.setNeedsLayout()
    }
}