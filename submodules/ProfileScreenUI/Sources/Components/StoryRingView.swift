//
//  StoryRingView.swift
//  divo-ios
//

import UIKit
import DivoUIKit

/// Кольцо сторис вокруг аватарки: градиент — есть непросмотренные, ровный серый — все просмотрены.
class StoryRingView: UIView {

    var hasUnseen: Bool = false {
        didSet {
            guard hasUnseen != oldValue else { return }
            applyColors()
        }
    }

    private let gradientLayer = CAGradientLayer()
    private let ringMask = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        // Вертикальный градиент — как у кольца сторис в ленте (StoryCollectionViewCell)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.addSublayer(gradientLayer)

        ringMask.fillColor = UIColor.clear.cgColor
        // Маска: важна только alpha обводки, цвет любой непрозрачный
        ringMask.strokeColor = UIColor.black.cgColor
        ringMask.lineWidth = 3
        gradientLayer.mask = ringMask

        applyColors()
    }

    private func applyColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.colors = hasUnseen
            ? [DivoColorPalette.storyRingGradientStart.cgColor, DivoColorPalette.storyRingGradientEnd.cgColor]
            : [DivoColorPalette.avatarStrokeQuiet.cgColor, DivoColorPalette.avatarStrokeQuiet.cgColor]
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        ringMask.frame = bounds
        // inset держит обводку целиком внутри bounds, иначе внешний край срежется
        ringMask.path = UIBezierPath(ovalIn: bounds.insetBy(dx: ringMask.lineWidth / 2, dy: ringMask.lineWidth / 2)).cgPath
        CATransaction.commit()
    }
}
