//
//  RangeSlider.swift
//  DivoUIKit
//
//  Created by Michail Shagovitov on 07.04.2026.
//

import UIKit

final class RangeSlider: UIControl {
    var minimumValue: CGFloat = 0 { didSet { updateLayerFrames() } }
    var maximumValue: CGFloat = 300 { didSet { updateLayerFrames() } }

    var isSingleSlider: Bool = false {
        didSet {
            lowerThumbLayer.isHidden = isSingleSlider
            if isSingleSlider {
                lowerValue = minimumValue
            }
            updateLayerFrames()
        }
    }

    var lowerValue: CGFloat = 20 {
        didSet {
            if isSingleSlider { return }
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

    private func setupLayers() {
        trackLayer.backgroundColor = DivoColorPalette.accent.withAlphaComponent(0.2).cgColor
        trackLayer.cornerRadius = trackHeight / 2
        layer.addSublayer(trackLayer)

        highlightLayer.backgroundColor = DivoColorPalette.accent.cgColor
        highlightLayer.cornerRadius = trackHeight / 2
        layer.addSublayer(highlightLayer)

        setupThumb(lowerThumbLayer)
        setupThumb(upperThumbLayer)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        self.addGestureRecognizer(panGesture)
    }

    private func setupThumb(_ thumbLayer: CALayer) {
        thumbLayer.backgroundColor = UIColor.white.cgColor
        thumbLayer.cornerRadius = thumbWidth / 2
        thumbLayer.applyDivoShadow(
            opacity: 0.15, // TODO: DS alignment — non-DS opacity
            radius: DivoDesignTokens.Shadow.thumbRadius,
            offset: DivoDesignTokens.Shadow.thumbOffset
        )
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
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        
        switch gesture.state {
        case .began:
            previousLocation = location
            
            let expand: CGFloat = 15
            let lowerFrame = lowerThumbLayer.frame.insetBy(dx: -expand, dy: -expand)
            let upperFrame = upperThumbLayer.frame.insetBy(dx: -expand, dy: -expand)
            
            let isLowerHit = lowerFrame.contains(previousLocation)
            let isUpperHit = upperFrame.contains(previousLocation)
            
            if isSingleSlider {
                isTrackingUpper = isUpperHit
            } else {
                if isLowerHit && isUpperHit {
                    if lowerValue == minimumValue {
                        isTrackingUpper = true
                    } else if upperValue == maximumValue {
                        isTrackingLower = true
                    } else {
                        isTrackingLower = previousLocation.x < lowerThumbLayer.frame.midX
                        isTrackingUpper = !isTrackingLower
                    }
                } else if isLowerHit {
                    isTrackingLower = true
                } else if isUpperHit {
                    isTrackingUpper = true
                }
            }
            
        case .changed:
            let deltaLocation = location.x - previousLocation.x
            let deltaValue = (maximumValue - minimumValue) * deltaLocation / (bounds.width - thumbWidth)
            
            previousLocation = location
            
            if isTrackingLower && !isSingleSlider {
                lowerValue = min(max(minimumValue, lowerValue + deltaValue), upperValue)
            } else if isTrackingUpper {
                upperValue = min(max(lowerValue, upperValue + deltaValue), maximumValue)
            }
            
            sendActions(for: .valueChanged)
            
        case .ended, .cancelled, .failed, .possible:
            isTrackingLower = false
            isTrackingUpper = false

        @unknown default:
            break
        }
    }
}

extension RangeSlider: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: self)
        let expand: CGFloat = 15
        let lowerFrame = lowerThumbLayer.frame.insetBy(dx: -expand, dy: -expand)
        let upperFrame = upperThumbLayer.frame.insetBy(dx: -expand, dy: -expand)
        
        if isSingleSlider {
            return upperFrame.contains(location)
        } else {
            return lowerFrame.contains(location) || upperFrame.contains(location)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
