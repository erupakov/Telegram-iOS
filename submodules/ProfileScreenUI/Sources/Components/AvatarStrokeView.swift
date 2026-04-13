//
//  AvatarStrokeView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.02.2026.
//

import UIKit
import DivoUIKit

class AvatarStrokeView: UIView {
    
    private let rightArcLayer = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    private let leftArcMask = CAShapeLayer()
    private let gapAngle: CGFloat = .pi / 50
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        rightArcLayer.fillColor = UIColor.clear.cgColor
        rightArcLayer.strokeColor = DivoColorPalette.avatarStrokeQuiet.cgColor
        rightArcLayer.lineWidth = 3
        rightArcLayer.lineCap = .round
        layer.addSublayer(rightArcLayer)

        gradientLayer.colors = [
            DivoColorPalette.avatarStrokeRedDeep.cgColor,
            UIColor.black.cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        
        layer.addSublayer(gradientLayer)
        leftArcMask.fillColor = UIColor.clear.cgColor
        leftArcMask.strokeColor = UIColor.black.cgColor
        leftArcMask.lineWidth = 3
        leftArcMask.lineCap = .round
        gradientLayer.mask = leftArcMask
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - rightArcLayer.lineWidth) / 2
        
        let startRight = -CGFloat.pi / 2 + gapAngle
        let endRight = CGFloat.pi / 2 - gapAngle
        
        let rightPath = UIBezierPath(arcCenter: center,
                                     radius: radius,
                                     startAngle: startRight,
                                     endAngle: endRight,
                                     clockwise: true)
        rightArcLayer.path = rightPath.cgPath
        
        let startLeft = CGFloat.pi / 2 + gapAngle
        let endLeft = 3 * CGFloat.pi / 2 - gapAngle
        
        let leftPath = UIBezierPath(arcCenter: center,
                                    radius: radius,
                                    startAngle: startLeft,
                                    endAngle: endLeft,
                                    clockwise: true)
        
        gradientLayer.frame = bounds
        leftArcMask.path = leftPath.cgPath
    }
}
