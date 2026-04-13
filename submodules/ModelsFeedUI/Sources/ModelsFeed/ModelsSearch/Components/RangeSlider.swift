//
//  RangeSlider.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import UIKit
import DivoUIKit

final class RangeSlider: UIControl {
    var minimumValue: CGFloat = 0 { didSet { updateLayerFrames() } }
    var maximumValue: CGFloat = 100 { didSet { updateLayerFrames() } }
    
    var lowerValue: CGFloat = 20 {
        didSet {
            lowerValue = max(minimumValue, min(lowerValue, upperValue))
            updateLayerFrames()
        }
    }
    
    var upperValue: CGFloat = 80 {
        didSet {
            upperValue = max(lowerValue, min(upperValue, maximumValue))
            updateLayerFrames()
        }
    }
    
    private var isTrackingLower = false
    private var isTrackingUpper = false
    
    private let trackLayer = CALayer()
    private let highlightLayer = CALayer()
    private let lowerThumbLayer = CALayer()
    private let upperThumbLayer = CALayer()
    
    private var previousLocation = CGPoint()
    private let thumbWidth: CGFloat = 28.0
    private let trackHeight: CGFloat = 4.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrames()
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        previousLocation = touch.location(in: self)
        
        // Расширяем зону нажатия (hit area)
        let expand: CGFloat = 15
        let lowerFrame = lowerThumbLayer.frame.insetBy(dx: -expand, dy: -expand)
        let upperFrame = upperThumbLayer.frame.insetBy(dx: -expand, dy: -expand)
        
        if lowerFrame.contains(previousLocation) {
            isTrackingLower = true
        } else if upperFrame.contains(previousLocation) {
            isTrackingUpper = true
        }
        return isTrackingLower || isTrackingUpper
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)
        let deltaLocation = location.x - previousLocation.x
        let deltaValue = (maximumValue - minimumValue) * deltaLocation / (bounds.width - thumbWidth)
        
        previousLocation = location
        
        if isTrackingLower {
            lowerValue = min(max(minimumValue, lowerValue + deltaValue), upperValue)
        } else if isTrackingUpper {
            upperValue = min(max(lowerValue, upperValue + deltaValue), maximumValue)
        }
        
        sendActions(for: .valueChanged)
        return true
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        isTrackingLower = false
        isTrackingUpper = false
    }
    
    private func setupLayers() {
        trackLayer.backgroundColor = DivoColorPalette.accent.withAlphaComponent(0.2).cgColor
        trackLayer.cornerRadius = trackHeight / 2
        layer.addSublayer(trackLayer)

        highlightLayer.backgroundColor = DivoColorPalette.accent.cgColor
        highlightLayer.cornerRadius = trackHeight / 2
        layer.addSublayer(highlightLayer)
        
        setupThumb(lowerThumbLayer)
        setupThumb(upperThumbLayer)
    }
    
    private func setupThumb(_ thumbLayer: CALayer) {
        thumbLayer.backgroundColor = UIColor.white.cgColor
        thumbLayer.cornerRadius = thumbWidth / 2
        thumbLayer.shadowColor = DivoColorPalette.shadow.cgColor
        thumbLayer.shadowOffset = CGSize(width: 0, height: 2)
        thumbLayer.shadowOpacity = 0.15
        thumbLayer.shadowRadius = 4
        layer.addSublayer(thumbLayer)
    }
    
    private func updateLayerFrames() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let trackY = (bounds.height - trackHeight) / 2
        trackLayer.frame = CGRect(x: thumbWidth / 2, y: trackY, width: bounds.width - thumbWidth, height: trackHeight)
        
        let lowerThumbCenter = positionForValue(lowerValue)
        let upperThumbCenter = positionForValue(upperValue)
        
        highlightLayer.frame = CGRect(x: lowerThumbCenter, y: trackY, width: upperThumbCenter - lowerThumbCenter, height: trackHeight)
        
        lowerThumbLayer.frame = CGRect(x: lowerThumbCenter - thumbWidth / 2, y: (bounds.height - thumbWidth) / 2, width: thumbWidth, height: thumbWidth)
        upperThumbLayer.frame = CGRect(x: upperThumbCenter - thumbWidth / 2, y: (bounds.height - thumbWidth) / 2, width: thumbWidth, height: thumbWidth)
        
        CATransaction.commit()
    }
    
    private func positionForValue(_ value: CGFloat) -> CGFloat {
        let width = bounds.width - thumbWidth
        let percent = (value - minimumValue) / (maximumValue - minimumValue)
        return thumbWidth / 2 + width * percent
    }
}
