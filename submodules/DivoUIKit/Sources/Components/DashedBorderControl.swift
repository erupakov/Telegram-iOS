//
//  DashedBorderControl.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 21.05.2026.
//

import UIKit

public final class DashedBorderControl: UIControl {
    private let dashedLayer = CAShapeLayer()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        backgroundColor = DivoColorPalette.cardBackground
        dashedLayer.strokeColor = DivoColorPalette.primaryText.withAlphaComponent(0.2).cgColor
        dashedLayer.fillColor = nil
        
        dashedLayer.lineDashPattern = [6, 6]
        dashedLayer.lineWidth = 1.5
        
        layer.addSublayer(dashedLayer)
        layer.cornerRadius = DivoDesignTokens.Spacing.xl
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        dashedLayer.frame = bounds
        dashedLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }
}
