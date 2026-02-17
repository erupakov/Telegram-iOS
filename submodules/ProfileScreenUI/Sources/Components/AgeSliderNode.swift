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
    
    init(title: String, type: String, defaultValue: Int, minimumValue: Int, maximumValue: Int) {
        self.type = type
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.regular(16), textColor: .white)
        self.titleNode.displaysAsynchronously = false
        
        self.valueNode = ASTextNode()
        self.valueNode.attributedText = NSAttributedString(string: String(defaultValue) + " " + type, font: Font.bold(16), textColor: .white)
        self.valueNode.displaysAsynchronously = false
        
        self.slider = UISlider()
        self.slider.minimumValue = Float(minimumValue)
        self.slider.maximumValue = Float(maximumValue)
        self.slider.value = Float(defaultValue)
        self.slider.tintColor = UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0)
        
        self.minAgeNode = ASTextNode()
        self.minAgeNode.attributedText = NSAttributedString(string: String(minimumValue), font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
        self.minAgeNode.displaysAsynchronously = false
        
        self.maxAgeNode = ASTextNode()
        self.maxAgeNode.attributedText = NSAttributedString(string: String(maximumValue), font: Font.regular(14), textColor: .white.withAlphaComponent(0.8))
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
        
        let minSize = self.minAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.minAgeNode.frame = CGRect(x: sideInset, y: sliderY + sliderHeight, width: minSize.width, height: minSize.height)

        let maxSize = self.maxAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.maxAgeNode.frame = CGRect(x: maximumWidth - sideInset - maxSize.width, y: sliderY + sliderHeight, width: maxSize.width, height: maxSize.height)
    }
    
    @objc private func sliderValueChanged() {
        let roundedValue = Int(self.slider.value.rounded())
        self.valueNode.attributedText = NSAttributedString(string: "\(roundedValue) " + type, font: Font.bold(16), textColor: .white)
        self.setNeedsLayout()
    }
}

class CheckboxNode: ASButtonNode {
    private let checkboxSize: CGSize
    
    init(size: CGSize = CGSize(width: 20, height: 20)) {
        self.checkboxSize = size
        super.init()
        self.updateAppearance()
    }
    
    override var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }
    
    private func updateAppearance() {
        let normalImage = UIImage(bundleImageName: "Models/Checkbox")
        let selectedImage = UIImage(bundleImageName: "Models/CheckboxSelected")
        
        self.setImage(normalImage, for: .normal)
        self.setImage(selectedImage, for: .selected)
        self.setImage(selectedImage, for: .highlighted)
    }
}

