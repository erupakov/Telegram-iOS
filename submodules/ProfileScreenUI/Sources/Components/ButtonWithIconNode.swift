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
    private let textNode: ASTextNode
    private let iconNode: ASImageNode
    private let spacing: CGFloat
    private let imageSize: CGSize
    
    init(title: String, icon: UIImage?, theme: PresentationTheme, spacing: CGFloat, imageSize: CGSize) {
        self.spacing = spacing
        self.imageSize = imageSize
        
        self.textNode = ASTextNode()
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.helveticaNeue(16), textColor: .white)
        
        self.iconNode = ASImageNode()
        self.iconNode.image = icon
        self.iconNode.contentMode = .scaleAspectFit
        
        super.init()
        
        self.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.cornerRadius = 6
        
        if icon != nil {
            self.addSubnode(self.iconNode)
        }
        self.addSubnode(self.textNode)
    }
    
    override func layout() {
        super.layout()
        let textSize = self.textNode.measure(self.bounds.size)
        
        if self.iconNode.image != nil {
            let contentWidth = self.imageSize.width + self.spacing + textSize.width
            let contentOriginX = (self.bounds.width - contentWidth) / 2.0
            
            self.iconNode.frame = CGRect(x: contentOriginX,
                                         y: (self.bounds.height - self.imageSize.height) / 2.0,
                                         width: self.imageSize.width,
                                         height: self.imageSize.height)
            
            self.textNode.frame = CGRect(x: contentOriginX + self.imageSize.width + self.spacing,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        } else {
            self.textNode.frame = CGRect(x: (self.bounds.width - textSize.width) / 2.0,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        }
    }
}
