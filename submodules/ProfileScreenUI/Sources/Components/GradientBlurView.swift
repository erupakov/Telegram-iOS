//
//  GradientBlurView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 09.04.2026.
//

import UIKit

final class GradientBlurView: UIVisualEffectView {
    private let maskLayer = CAGradientLayer()
    
    init(isTop: Bool) {
        super.init(effect: UIBlurEffect(style: .light))
        self.isUserInteractionEnabled = false
        self.translatesAutoresizingMaskIntoConstraints = false
        
        maskLayer.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
        maskLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        
        if !isTop {
            maskLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        }
        
        self.layer.mask = maskLayer
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        maskLayer.frame = bounds
    }
}
