import UIKit
import Display

public final class SimilarityStepSlider: UIControl {
    public var steps: [CGFloat] = [] {
        didSet {
            rebuildStepLabels()
            clampIndexToSteps()
            setNeedsLayout()
        }
    }

    public var selectedIndex: Int = 0 {
        didSet {
            clampIndexToSteps()
            if oldValue != selectedIndex {
                updateLayerFrames(animated: true)
                sendActions(for: .valueChanged)
            }
        }
    }

    public var value: CGFloat {
        guard !steps.isEmpty else { return 0 }
        return steps[selectedIndex]
    }

    public var labelFormatter: (CGFloat) -> String = { value in
        "\(Int((value * 100).rounded()))%"
    }

    private let trackLayer = CALayer()
    private let highlightLayer = CALayer()
    private let thumbLayer = CALayer()
    private var markLayers: [CALayer] = []
    private var stepLabels: [UILabel] = []

    private let thumbWidth: CGFloat = 24
    private let trackHeight: CGFloat = 4
    private let markDiameter: CGFloat = 10
    private let labelTopOffset: CGFloat = 14

    private var previousLocation: CGPoint = .zero
    private var isDragging = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    public required init?(coder: NSCoder) { fatalError() }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 40)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrames(animated: false)
        layoutStepLabels()
    }

    private func setupLayers() {
        trackLayer.backgroundColor = DivoColorPalette.accent.withAlphaComponent(0.2).cgColor
        trackLayer.cornerRadius = trackHeight / 2
        layer.addSublayer(trackLayer)

        highlightLayer.backgroundColor = DivoColorPalette.accent.cgColor
        highlightLayer.cornerRadius = trackHeight / 2
        layer.addSublayer(highlightLayer)

        thumbLayer.backgroundColor = DivoColorPalette.accent.cgColor
        thumbLayer.cornerRadius = thumbWidth / 2
        thumbLayer.applyDivoShadow(
            opacity: 0.15,
            radius: DivoDesignTokens.Shadow.thumbRadius,
            offset: DivoDesignTokens.Shadow.thumbOffset
        )
        layer.addSublayer(thumbLayer)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    private func rebuildStepLabels() {
        stepLabels.forEach { $0.removeFromSuperview() }
        stepLabels = steps.map { stepValue in
            let label = UILabel()
            label.text = labelFormatter(stepValue)
            label.font = Font.regular(12)
            label.textColor = DivoColorPalette.systemLabelPlaceholder
            label.textAlignment = .center
            label.lineBreakMode = .byClipping
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            return label
        }

        markLayers.forEach { $0.removeFromSuperlayer() }
        markLayers = steps.map { _ in
            let markLayer = CALayer()
            markLayer.backgroundColor = DivoColorPalette.accent.withAlphaComponent(0.4).cgColor
            markLayer.cornerRadius = markDiameter / 2
            markLayer.applyDivoShadow(
                opacity: 0.15,
                radius: DivoDesignTokens.Shadow.thumbRadius,
                offset: DivoDesignTokens.Shadow.thumbOffset
            )
            layer.insertSublayer(markLayer, above: trackLayer)
            return markLayer
        }

        updateLabelHighlight()
    }

    private func clampIndexToSteps() {
        guard !steps.isEmpty else {
            if selectedIndex != 0 { selectedIndex = 0 }
            return
        }
        let clamped = max(0, min(selectedIndex, steps.count - 1))
        if clamped != selectedIndex {
            selectedIndex = clamped
        }
    }

    private func positionForIndex(_ index: Int) -> CGFloat {
        guard steps.count > 1 else { return bounds.width / 2 }
        let n = (bounds.width - 30) / 7
        return CGFloat(index + 1) * n + CGFloat(index) * 6
    }

    private func indexNearest(to x: CGFloat) -> Int {
        guard steps.count > 1 else { return 0 }
        var closest = 0
        var closestDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<steps.count {
            let dist = abs(x - positionForIndex(i))
            if dist < closestDist {
                closestDist = dist
                closest = i
            }
        }
        return closest
    }

    private func updateLayerFrames(animated: Bool) {
        guard bounds.width > 0 else { return }

        let trackY = (thumbWidth - trackHeight) / 2
        let trackRect = CGRect(x: 0, y: trackY, width: bounds.width, height: trackHeight)

        let thumbCenter = positionForIndex(selectedIndex)
        let highlightRect = CGRect(x: 0, y: trackY, width: thumbCenter, height: trackHeight)
        let thumbRect = CGRect(x: thumbCenter - thumbWidth / 2, y: 0, width: thumbWidth, height: thumbWidth)

        if animated {
            let timing = CAMediaTimingFunction(controlPoints: 0.25, 1.0, 0.5, 1.0)

            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3)
            CATransaction.setAnimationTimingFunction(timing)

            self.trackLayer.frame = trackRect
            self.highlightLayer.frame = highlightRect
            self.thumbLayer.frame = thumbRect

            for (i, markLayer) in self.markLayers.enumerated() {
                let center = self.positionForIndex(i)
                markLayer.frame = CGRect(
                    x: center - self.markDiameter / 2,
                    y: (self.thumbWidth - self.markDiameter) / 2,
                    width: self.markDiameter,
                    height: self.markDiameter
                )
                markLayer.backgroundColor = (i < self.selectedIndex
                    ? DivoColorPalette.accent
                    : UIColor.white
                ).cgColor
            }

            CATransaction.commit()

            let pop = CAKeyframeAnimation(keyPath: "transform.scale")
            pop.values = [1.0, 1.15, 0.95, 1.0]
            pop.keyTimes = [0, 0.35, 0.7, 1.0]
            pop.duration = 0.3
            pop.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            thumbLayer.add(pop, forKey: "thumbPop")
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)

            self.trackLayer.frame = trackRect
            self.highlightLayer.frame = highlightRect
            self.thumbLayer.frame = thumbRect

            for (i, markLayer) in self.markLayers.enumerated() {
                let center = self.positionForIndex(i)
                markLayer.frame = CGRect(
                    x: center - self.markDiameter / 2,
                    y: (self.thumbWidth - self.markDiameter) / 2,
                    width: self.markDiameter,
                    height: self.markDiameter
                )
                markLayer.backgroundColor = (i < self.selectedIndex
                    ? DivoColorPalette.accent
                    : UIColor.white
                ).cgColor
            }

            CATransaction.commit()
        }
    }

    private func layoutStepLabels() {
        for (i, label) in stepLabels.enumerated() {
            let center = positionForIndex(i)
            let text = label.text ?? ""
            let mediumSize = (text as NSString).size(withAttributes: [.font: Font.medium(12)])
            let width = max(ceil(mediumSize.width) + 10, 24)
            let height = ceil(mediumSize.height)
            let trackBottom = (thumbWidth - trackHeight) / 2 + trackHeight
            label.frame = CGRect(
                x: center - 14,
                y: trackBottom + labelTopOffset,
                width: width,
                height: height
            )
        }
        updateLabelHighlight()
    }

    private func updateLabelHighlight(animated: Bool = false) {
        for (i, label) in stepLabels.enumerated() {
            let isSelected = i == selectedIndex
            let targetColor = isSelected ? DivoColorPalette.primaryText : DivoColorPalette.systemLabelPlaceholder
            let targetFont = isSelected ? Font.medium(12) : Font.regular(12)
            let targetScale: CGFloat = isSelected ? 1.15 : 1.0

            if animated {
                UIView.animate(
                    withDuration: 0.35,
                    delay: 0,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 0.5,
                    options: [.curveEaseOut]
                ) {
                    label.transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
                    label.textColor = targetColor
                }
                label.font = targetFont
            } else {
                label.textColor = targetColor
                label.font = targetFont
                label.transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
            }
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            isDragging = true
            previousLocation = location
            UISelectionFeedbackGenerator().selectionChanged()
        case .changed:
            let newIndex = indexNearest(to: location.x)
            if newIndex != selectedIndex {
                selectedIndex = newIndex
                updateLabelHighlight(animated: true)
                UISelectionFeedbackGenerator().selectionChanged()
            }
            previousLocation = location
        case .ended, .cancelled, .failed:
            isDragging = false
        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let newIndex = indexNearest(to: location.x)
        if newIndex != selectedIndex {
            selectedIndex = newIndex
            updateLabelHighlight(animated: true)
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

extension SimilarityStepSlider: UIGestureRecognizerDelegate {
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
