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

protocol SliderValue: CVarArg, Equatable {
    var floatValue: Float { get }
    init(_ float: Float)
    var stringValue: String { get }
    static var step: Float { get }
}

extension Int: SliderValue {
    var floatValue: Float { Float(self) }
    var stringValue: String { String(self) }
    static var step: Float { 1.0 }
}

extension Double: SliderValue {
    var floatValue: Float { Float(self) }
    
    var stringValue: String {
        let number = NSNumber(value: self)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")
        
        if let formatted = formatter.string(from: number) {
            return formatted
        } else {
            return "\(self)"
        }
    }
    
    static var step: Float { 0.01 }
}

struct AgeSliderConfiguration {
    var titleColor: UIColor
    var valueColor: UIColor
    var labelColor: UIColor
    var sliderTintColor: UIColor
    var thumbBorderColor: UIColor
    var thumbInnerColor: UIColor
    
    var titleFont: UIFont
    var valueFont: UIFont
    var labelFont: UIFont
    
    var thumbSize: CGFloat
    var borderWidth: CGFloat
    
    var sideInset: CGFloat
    var sliderHeight: CGFloat
    
    static var `default` = AgeSliderConfiguration(
        titleColor: .white,
        valueColor: .white,
        labelColor: .white.withAlphaComponent(0.8),
        sliderTintColor: UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0),
        thumbBorderColor: UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0),
        thumbInnerColor: .white,
        titleFont: Font.regular(16),
        valueFont: Font.bold(16),
        labelFont: Font.regular(14),
        thumbSize: 16.0,
        borderWidth: 2.0,
        sideInset: 0.0,
        sliderHeight: 30.0
    )
    
    static var `light` = AgeSliderConfiguration(
        titleColor: UIColor(hexString: "#3C3C43") ?? .white,
        valueColor: UIColor(hexString: "#3C3C43") ?? .white,
        labelColor: UIColor(hexString: "#3C3C43")?.withAlphaComponent(0.6) ?? .white,
        sliderTintColor: UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0),
        thumbBorderColor: UIColor(red: 0.77, green: 0.54, blue: 0.38, alpha: 1.0),
        thumbInnerColor: .white,
        titleFont: Font.regular(16),
        valueFont: Font.bold(16),
        labelFont: Font.regular(14),
        thumbSize: 16.0,
        borderWidth: 2.0,
        sideInset: 0.0,
        sliderHeight: 30.0
    )
}

enum AgeSliderMode {
    case single(value: Float)
    case range(minValue: Float, maxValue: Float)
}

class AgeSliderNode<T: SliderValue>: ASDisplayNode {
    private let titleNode: ASTextNode
    private let valueNode: ASTextNode
    private let slider: UISlider
    
    private let minAgeNode: ASTextNode
    private let maxAgeNode: ASTextNode
    private let type: String
    private let step: Float
    private let configuration: AgeSliderConfiguration
    
    private var rangeSliderView: RangeSliderView?
    private var isRangeSlider: Bool {
        if case .range = mode { return true }
        return false
    }

    public var currentValue: T {
        if case .range = mode, let rangeSliderView = rangeSliderView {
            return T((rangeSliderView.lowerValue + rangeSliderView.upperValue) / 2.0)
        }
        return T(slider.value)
    }

    public var currentRange: (min: T, max: T)? {
        guard case .range = mode, let rangeSliderView = rangeSliderView else { return nil }
        return (T(rangeSliderView.lowerValue), T(rangeSliderView.upperValue))
    }

    public var onValueChange: ((T) -> Void)?
    public var onRangeChange: ((T, T) -> Void)?

    private let mode: AgeSliderMode

    init(
        title: String,
        type: String,
        mode: AgeSliderMode,
        minimumValue: T,
        maximumValue: T,
        step: Float? = nil,
        configuration: AgeSliderConfiguration = .default
    ) {
        self.type = type
        self.step = step ?? T.step
        self.configuration = configuration
        self.mode = mode
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: configuration.titleFont, textColor: configuration.titleColor)
        self.titleNode.displaysAsynchronously = false
        
        self.valueNode = ASTextNode()
        let initialValue: T
        switch mode {
        case .single(let value):
            initialValue = T(value)
        case .range(let minVal, _):
            initialValue = T(minVal)
        }
        self.valueNode.attributedText = NSAttributedString(string: "\(initialValue.stringValue) \(type)", font: configuration.valueFont, textColor: configuration.valueColor)
        self.valueNode.displaysAsynchronously = false
        
        self.slider = UISlider()
        self.slider.minimumValue = minimumValue.floatValue
        self.slider.maximumValue = maximumValue.floatValue
        
        switch mode {
        case .single(let value):
            self.slider.value = value
        case .range(let minVal, _):
            self.slider.value = minVal
        }
        
        self.slider.tintColor = configuration.sliderTintColor
        
        let thumbImage = generateImage(CGSize(width: configuration.thumbSize, height: configuration.thumbSize), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            let borderRect = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            let path = UIBezierPath(ovalIn: borderRect)
            context.setStrokeColor(configuration.thumbBorderColor.cgColor)
            context.setLineWidth(configuration.borderWidth)
            context.addPath(path.cgPath)
            context.strokePath()
            
            let innerRect = CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4)
            let innerPath = UIBezierPath(ovalIn: innerRect)
            context.setFillColor(configuration.thumbInnerColor.cgColor)
            context.addPath(innerPath.cgPath)
            context.fillPath()
        })
        self.slider.setThumbImage(thumbImage, for: .normal)
        self.slider.setThumbImage(thumbImage, for: .highlighted)
        
        self.minAgeNode = ASTextNode()
        self.minAgeNode.attributedText = NSAttributedString(string: minimumValue.stringValue, font: configuration.labelFont, textColor: configuration.labelColor)
        self.minAgeNode.displaysAsynchronously = false
        
        self.maxAgeNode = ASTextNode()
        self.maxAgeNode.attributedText = NSAttributedString(string: maximumValue.stringValue, font: configuration.labelFont, textColor: configuration.labelColor)
        self.maxAgeNode.displaysAsynchronously = false
        
        super.init()
        
        print("AgeSliderNode.init: mode = \(mode), isRangeSlider = \(isRangeSlider)")
        
        if isRangeSlider {
            let rangeValues: (lower: Float, upper: Float)
            switch mode {
            case .single(let value):
                let center = value
                let rangeSpan = (maximumValue.floatValue - minimumValue.floatValue) * 0.1
                rangeValues = (center - rangeSpan / 2, center + rangeSpan / 2)
            case .range(let minValue, let maxValue):
                rangeValues = (minValue, maxValue)
            }
            
            self.rangeSliderView = RangeSliderView(
                minimumValue: minimumValue.floatValue,
                maximumValue: maximumValue.floatValue,
                lowerValue: rangeValues.lower,
                upperValue: rangeValues.upper,
                step: self.step,
                configuration: configuration
            )
            self.rangeSliderView?.onRangeChange = { [weak self] lower, upper in
                guard let self = self else { return }
                let lowerValue = T(lower)
                let upperValue = T(upper)
                self.valueNode.attributedText = NSAttributedString(
                    string: "\(lowerValue.stringValue) - \(upperValue.stringValue) \(self.type)",
                    font: self.configuration.valueFont,
                    textColor: self.configuration.valueColor
                )
                self.onRangeChange?(lowerValue, upperValue)
                self.setNeedsLayout()
            }
            self.view.addSubview(self.rangeSliderView!)
            self.rangeSliderView?.setNeedsDisplay()
            self.view.bringSubviewToFront(self.rangeSliderView!)
        } else {
            self.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
            self.view.addSubview(self.slider)
        }
        
        self.addSubnode(titleNode)
        self.addSubnode(valueNode)
        self.addSubnode(self.minAgeNode)
        self.addSubnode(self.maxAgeNode)
    }
    
    override func layout() {
        super.layout()
        
        let sideInset = configuration.sideInset
        let maximumWidth: CGFloat = self.bounds.width
        
        let titleSize = self.titleNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(x: sideInset, y: 0, width: titleSize.width, height: titleSize.height)
        
        let valueSize = self.valueNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.valueNode.frame = CGRect(x: maximumWidth - sideInset - valueSize.width, y: 0, width: valueSize.width, height: valueSize.height)
        
        let sliderWidth = maximumWidth - sideInset * 2.0
        let sliderY = titleSize.height
        let sliderFrame = CGRect(x: sideInset, y: sliderY, width: sliderWidth, height: configuration.sliderHeight)
        
        if isRangeSlider {
            self.rangeSliderView?.frame = sliderFrame
        } else {
            self.slider.frame = sliderFrame
        }
        
        let minSize = self.minAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.minAgeNode.frame = CGRect(x: sideInset, y: sliderY + configuration.sliderHeight, width: minSize.width, height: minSize.height)
        
        let maxSize = self.maxAgeNode.measure(CGSize(width: maximumWidth / 2.0, height: .greatestFiniteMagnitude))
        self.maxAgeNode.frame = CGRect(x: maximumWidth - sideInset - maxSize.width, y: sliderY + configuration.sliderHeight, width: maxSize.width, height: maxSize.height)
    }
    
    @objc private func sliderValueChanged() {
        let rawValue = self.slider.value
        let steppedValue = round(rawValue / step) * step
        let clampedValue = max(slider.minimumValue, min(slider.maximumValue, steppedValue))
        self.slider.value = clampedValue
        let genericValue = T(clampedValue)
        let valueString = genericValue.stringValue
        self.valueNode.attributedText = NSAttributedString(string: "\(valueString) \(type)", font: configuration.valueFont, textColor: configuration.valueColor)
        self.onValueChange?(genericValue)
        self.setNeedsLayout()
    }
    
    func setValue(_ value: T, animated: Bool = false) {
        guard !isRangeSlider else { return }
        let floatValue = value.floatValue
        if animated {
            UIView.animate(withDuration: 0.2) {
                self.slider.value = floatValue
                self.sliderValueChanged()
            }
        } else {
            slider.value = floatValue
            sliderValueChanged()
        }
    }
    
    func setRange(min: T, max: T, animated: Bool = false) {
        guard isRangeSlider, let rangeSliderView = rangeSliderView else { return }
        let lowerValue = min.floatValue
        let upperValue = max.floatValue
        if animated {
            UIView.animate(withDuration: 0.2) {
                rangeSliderView.setRange(lower: lowerValue, upper: upperValue)
            }
        } else {
            rangeSliderView.setRange(lower: lowerValue, upper: upperValue)
        }
    }
}


class RangeSliderView: UIView {
    var minimumValue: Float = 0
    var maximumValue: Float = 100
    var lowerValue: Float = 20
    var upperValue: Float = 80

    private var step: Float = 1.0
    private var configuration: AgeSliderConfiguration

    var onRangeChange: ((Float, Float) -> Void)?

    private var lowerThumbFrame: CGRect = .zero
    private var upperThumbFrame: CGRect = .zero
    private var trackRect: CGRect = .zero

    private var isDraggingLowerThumb: Bool = false
    private var isDraggingUpperThumb: Bool = false

    init(
        minimumValue: Float,
        maximumValue: Float,
        lowerValue: Float,
        upperValue: Float,
        step: Float,
        configuration: AgeSliderConfiguration
    ) {
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.step = step
        self.configuration = configuration
        self.lowerValue = lowerValue
        self.upperValue = upperValue
        super.init(frame: .zero)
        
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true
        self.contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateThumbFrames()
    }

    private func updateThumbFrames() {
        let thumbSize = configuration.thumbSize
        let trackHeight: CGFloat = 4.0
        let trackY = (bounds.height - trackHeight) / 2.0
        
        trackRect = CGRect(x: thumbSize / 2.0, y: trackY, width: bounds.width - thumbSize, height: trackHeight)

        let lowerX = positionForValue(lowerValue) - thumbSize / 2.0
        let upperX = positionForValue(upperValue) - thumbSize / 2.0

        lowerThumbFrame = CGRect(x: lowerX, y: (bounds.height - thumbSize) / 2.0, width: thumbSize, height: thumbSize)
        upperThumbFrame = CGRect(x: upperX, y: (bounds.height - thumbSize) / 2.0, width: thumbSize, height: thumbSize)
        
        setNeedsDisplay()
    }

    private func positionForValue(_ value: Float) -> CGFloat {
        let range = maximumValue - minimumValue
        let thumbSize = configuration.thumbSize
        if range == 0 { return thumbSize / 2.0 }
        
        let normalizedValue = (value - minimumValue) / range
        let usableWidth = bounds.width - thumbSize
        
        return thumbSize / 2.0 + CGFloat(normalizedValue) * usableWidth
    }

    private func valueForPosition(_ position: CGFloat) -> Float {
        let thumbSize = configuration.thumbSize
        let usableWidth = bounds.width - thumbSize
        
        var normalizedPosition = position - thumbSize / 2.0
        normalizedPosition = max(0, min(normalizedPosition, usableWidth))
        
        let normalizedValue = Float(normalizedPosition / usableWidth)
        let value = minimumValue + normalizedValue * (maximumValue - minimumValue)
        
        return round(value / step) * step
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let trackPath = UIBezierPath(roundedRect: trackRect, cornerRadius: trackRect.height / 2.0)
        configuration.sliderTintColor.withAlphaComponent(0.3).setFill()
        trackPath.fill()

        let activeTrackRect = CGRect(
            x: lowerThumbFrame.midX,
            y: trackRect.origin.y,
            width: upperThumbFrame.midX - lowerThumbFrame.midX,
            height: trackRect.height
        )
        let activeTrackPath = UIBezierPath(roundedRect: activeTrackRect, cornerRadius: activeTrackRect.height / 2.0)
        configuration.sliderTintColor.setFill()
        activeTrackPath.fill()

        drawThumb(frame: lowerThumbFrame, in: context)
        drawThumb(frame: upperThumbFrame, in: context)
    }

    private func drawThumb(frame: CGRect, in context: CGContext) {
        let borderRect = frame.insetBy(dx: 1, dy: 1)
        let path = UIBezierPath(ovalIn: borderRect)
        
        context.setStrokeColor(configuration.thumbBorderColor.cgColor)
        context.setLineWidth(configuration.borderWidth)
        context.addPath(path.cgPath)
        context.strokePath()

        let innerRect = frame.insetBy(dx: configuration.borderWidth, dy: configuration.borderWidth)
        let innerPath = UIBezierPath(ovalIn: innerRect)
        
        context.setFillColor(configuration.thumbInnerColor.cgColor)
        context.addPath(innerPath.cgPath)
        context.fillPath()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        let expandedLower = lowerThumbFrame.insetBy(dx: -15, dy: -15)
        let expandedUpper = upperThumbFrame.insetBy(dx: -15, dy: -15)

        if expandedLower.contains(location) {
            isDraggingLowerThumb = true
        } else if expandedUpper.contains(location) {
            isDraggingUpperThumb = true
        } else {
            let lowerDistance = abs(location.x - lowerThumbFrame.midX)
            let upperDistance = abs(location.x - upperThumbFrame.midX)
            if lowerDistance < upperDistance {
                isDraggingLowerThumb = true
            } else {
                isDraggingUpperThumb = true
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if isDraggingLowerThumb {
            let newValue = valueForPosition(location.x)
            let clampedValue = max(minimumValue, min(newValue, upperValue - step))
            if clampedValue != lowerValue {
                lowerValue = clampedValue
                updateThumbFrames()
                onRangeChange?(lowerValue, upperValue)
            }
        } else if isDraggingUpperThumb {
            let newValue = valueForPosition(location.x)
            let clampedValue = min(maximumValue, max(newValue, lowerValue + step))
            if clampedValue != upperValue {
                upperValue = clampedValue
                updateThumbFrames()
                onRangeChange?(lowerValue, upperValue)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingLowerThumb = false
        isDraggingUpperThumb = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        isDraggingLowerThumb = false
        isDraggingUpperThumb = false
    }

    func setRange(lower: Float, upper: Float) {
        self.lowerValue = max(minimumValue, min(lower, upper - step))
        self.upperValue = min(maximumValue, max(upper, lower + step))
        updateThumbFrames()
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
        let normalImage = UIImage(bundleImageName: "Components/Checkbox")
        let selectedImage = UIImage(bundleImageName: "Components/CheckboxSelected")
        
        self.setImage(normalImage, for: .normal)
        self.setImage(selectedImage, for: .selected)
        self.setImage(selectedImage, for: .highlighted)
    }
}
