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

class AgeSliderNode: ASDisplayNode {
    private let titleNode: ASTextNode
    private let valueNode: ASTextNode
    private let slider: UISlider
    
    private let minAgeNode: ASTextNode
    private let maxAgeNode: ASTextNode
    
    override init() {
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: "Age (y.o)", font: Font.regular(16), textColor: .white)
        self.titleNode.displaysAsynchronously = false
        
        self.valueNode = ASTextNode()
        self.valueNode.attributedText = NSAttributedString(string: "17 y.o", font: Font.bold(16), textColor: .white)
        self.valueNode.displaysAsynchronously = false
        
        self.slider = UISlider()
        self.slider.minimumValue = 14
        self.slider.maximumValue = 45
        self.slider.value = 17
        self.slider.tintColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        self.minAgeNode = ASTextNode()
        self.minAgeNode.attributedText = NSAttributedString(string: "14", font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.minAgeNode.displaysAsynchronously = false
        
        self.maxAgeNode = ASTextNode()
        self.maxAgeNode.attributedText = NSAttributedString(string: "45", font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
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
        
        let sideInset: CGFloat = 24.0
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
        self.valueNode.attributedText = NSAttributedString(string: "\(roundedValue) y.o", font: Font.bold(16), textColor: .white)
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
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.bold(20.0), textColor: .white)
        
        self.iconNode = ASImageNode()
        self.iconNode.image = icon
        self.iconNode.contentMode = .scaleAspectFit
        
        super.init()
        
        self.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.cornerRadius = 6
//        self.layer.borderColor = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 0.14).cgColor
//        self.layer.borderWidth = 1
        
        if icon != nil {
            self.addSubnode(self.iconNode)
        }
        self.addSubnode(self.textNode)
    }
    
    override func layout() {
        super.layout()
        
        let textSize = self.textNode.measure(self.bounds.size)
        
        if self.iconNode.image != nil {
            // Layout with icon
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
            // Layout without icon (center the text)
            self.textNode.frame = CGRect(x: (self.bounds.width - textSize.width) / 2.0,
                                         y: (self.bounds.height - textSize.height) / 2.0,
                                         width: textSize.width,
                                         height: textSize.height)
        }
    }
}
