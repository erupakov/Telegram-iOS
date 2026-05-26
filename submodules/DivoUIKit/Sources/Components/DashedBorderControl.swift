//
//  DashedBorderControl.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 21.05.2026.
//

import UIKit

public final class DashedBorderControl: UIControl {
    private let dashedLayer = CAShapeLayer()

    /// Показывать ли пунктирную обводку и серый card-фон.
    /// `false` имеет смысл, когда внутри стоит контент, который сам отрисовывает
    /// границу (например, выбранное фото на весь area).
    public var isBordered: Bool = true {
        didSet {
            guard oldValue != isBordered else { return }
            applyBordered()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        dashedLayer.strokeColor = DivoColorPalette.primaryText.withAlphaComponent(0.2).cgColor
        dashedLayer.fillColor = nil

        dashedLayer.lineDashPattern = [6, 6]
        dashedLayer.lineWidth = 1.5

        layer.addSublayer(dashedLayer)
        layer.cornerRadius = DivoDesignTokens.Radius.card
        clipsToBounds = true
        applyBordered()
    }

    private func applyBordered() {
        backgroundColor = isBordered ? DivoColorPalette.cardBackground : .clear
        dashedLayer.isHidden = !isBordered
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        dashedLayer.frame = bounds
        dashedLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }
}
