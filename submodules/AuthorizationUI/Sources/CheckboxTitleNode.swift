//
//  CheckboxTitleNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 02.03.2026.
//

import UIKit
import AsyncDisplayKit
import Display
import DivoUIKit

final class CheckboxTitleNode: ASDisplayNode {
    let circleNode: ASDisplayNode
    let innerCircleNode: ASDisplayNode
    let textNode: ASTextNode

    var isSelected: Bool = false {
        didSet {
            innerCircleNode.isHidden = !isSelected
            circleNode.borderColor = isSelected ? DivoColorPalette.accentCopperWarm.cgColor : DivoColorPalette.overlayDarkMediumLine.cgColor
        }
    }

    private var target: Any?
    private var action: Selector?

    func addTarget(_ target: Any?, action: Selector) {
        self.target = target
        self.action = action

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
        self.view.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap() {
        if let target = self.target, let action = self.action {
            _ = (target as AnyObject).perform(action, with: self)
        }
    }

    init(title: String) {
        self.circleNode = ASDisplayNode()
        self.innerCircleNode = ASDisplayNode()

        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false

        super.init()

        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
        circleNode.borderWidth = 2.0
        circleNode.borderColor = DivoColorPalette.overlayDarkMediumLine.cgColor
        circleNode.cornerRadius = 12.0

        innerCircleNode.backgroundColor = DivoColorPalette.accentCopperWarm
        innerCircleNode.cornerRadius = 7.0

        textNode.attributedText = Font.helveticaNeue(title, 14, .white, alignment: .left)

        self.addSubnode(circleNode)
        self.addSubnode(innerCircleNode)
        self.addSubnode(textNode)

        updateSelectionState()
    }
    
    private func updateSelectionState() {
        self.innerCircleNode.isHidden = !self.isSelected
    }

    override func layout() {
        super.layout()

        let circleSize: CGFloat = 24.0
        let innerCircleSize: CGFloat = 14.0
        let textSpacing: CGFloat = 12.0

        circleNode.frame = CGRect(x: 0, y: (bounds.height - circleSize) / 2, width: circleSize, height: circleSize)
        innerCircleNode.frame = CGRect(x: (circleSize - innerCircleSize) / 2, y: (circleSize - innerCircleSize) / 2 + 8, width: innerCircleSize, height: innerCircleSize)

        let textSize = textNode.measure(CGSize(width: bounds.width - circleSize - textSpacing, height: bounds.height))
        textNode.frame = CGRect(x: circleSize + textSpacing, y: innerCircleNode.frame.minY - 2, width: textSize.width, height: textSize.height + 2)
    }
}
