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

class AgeSliderNode: ASDisplayNode {
    private let titleNode: ASTextNode
    private let valueNode: ASTextNode
    public let slider: UISlider
    
    private let minAgeNode: ASTextNode
    private let maxAgeNode: ASTextNode
    private let type: String
    
    init(title: String, min: String, max: String, value: String, type: String) {
        self.type = type
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(16), textColor: .white)
        self.titleNode.displaysAsynchronously = false
        
        self.valueNode = ASTextNode()
        self.valueNode.attributedText = NSAttributedString(string: value + " " + type, font: Font.bold(16), textColor: .white)
        self.valueNode.displaysAsynchronously = false
        
        self.slider = UISlider()
        self.slider.minimumValue = 14
        self.slider.maximumValue = 45
        self.slider.value = 17
        self.slider.tintColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        self.minAgeNode = ASTextNode()
        self.minAgeNode.attributedText = NSAttributedString(string: min, font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.minAgeNode.displaysAsynchronously = false
        
        self.maxAgeNode = ASTextNode()
        self.maxAgeNode.attributedText = NSAttributedString(string: max, font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.maxAgeNode.displaysAsynchronously = false
        
        super.init()
        
        self.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        self.addSubnode(titleNode)
        self.addSubnode(valueNode)
        self.view.addSubview(self.slider)
        
        self.addSubnode(self.minAgeNode)
        self.addSubnode(self.maxAgeNode)
    }
    
    override func layout() {
        super.layout()
        
        let sideInset: CGFloat = 0.0
        let maximumWidth: CGFloat = self.bounds.width
        
        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(x: sideInset, y: 0, width: titleSize.width, height: titleSize.height)
        
        let valueSize = self.valueNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.valueNode.frame = CGRect(x: maximumWidth - sideInset - valueSize.width, y: 0, width: valueSize.width, height: valueSize.height)
        
        let sliderWidth = maximumWidth - sideInset * 2.0
        let sliderHeight = self.slider.intrinsicContentSize.height
        let sliderY = titleSize.height
        self.slider.frame = CGRect(x: sideInset, y: sliderY, width: sliderWidth, height: sliderHeight)
        
        let minSize = self.minAgeNode.measure(CGSize(width: 20, height: 20))
        self.minAgeNode.frame = CGRect(x: sideInset, y: sliderY + sliderHeight, width: minSize.width, height: minSize.height)
        
        let maxSize = self.maxAgeNode.measure(CGSize(width: 20, height: 20))
        self.maxAgeNode.frame = CGRect(x: maximumWidth - sideInset - maxSize.width, y: sliderY + sliderHeight, width: maxSize.width, height: maxSize.height)
    }
    
    @objc private func sliderValueChanged() {
        let roundedValue = Int(self.slider.value.rounded())
        self.valueNode.attributedText = NSAttributedString(string: "\(roundedValue) " + type, font: Font.bold(16), textColor: .white)
//        self.setNeedsLayout()
    }
}

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
