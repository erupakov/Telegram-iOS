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
        "\(Int((value * 100).rounded()))"
    }

    private let trackLayer = CALayer()
    private let highlightLayer = CALayer()
    private let thumbLayer = CALayer()
    private var markLayers: [CALayer] = []
    private var stepLabels: [UILabel] = []

    private let thumbWidth: CGFloat = 28
    private let trackHeight: CGFloat = 4
    private let markDiameter: CGFloat = 8
    private let labelTopOffset: CGFloat = 14

    private var previousLocation: CGPoint = .zero
    private var isDragging = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    public required init?(coder: NSCoder) { fatalError() }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 58)
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

        thumbLayer.backgroundColor = UIColor.white.cgColor
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
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            return label
        }

        markLayers.forEach { $0.removeFromSuperlayer() }
        markLayers = steps.map { _ in
            let markLayer = CALayer()
            markLayer.backgroundColor = DivoColorPalette.accent.withAlphaComponent(0.4).cgColor
            markLayer.cornerRadius = markDiameter / 2
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
        guard steps.count > 1 else { return thumbWidth / 2 }
        let usableWidth = bounds.width - thumbWidth
        let percent = CGFloat(index) / CGFloat(steps.count - 1)
        return thumbWidth / 2 + usableWidth * percent
    }

    private func indexNearest(to x: CGFloat) -> Int {
        guard !steps.isEmpty else { return 0 }
        let usableWidth = bounds.width - thumbWidth
        guard usableWidth > 0 else { return 0 }
        let clampedX = min(max(x, thumbWidth / 2), bounds.width - thumbWidth / 2)
        let percent = (clampedX - thumbWidth / 2) / usableWidth
        let raw = percent * CGFloat(steps.count - 1)
        return max(0, min(steps.count - 1, Int(raw.rounded())))
    }

    private func updateLayerFrames(animated: Bool) {
        guard bounds.width > 0 else { return }

        let trackY = (thumbWidth - trackHeight) / 2
        let trackRect = CGRect(x: thumbWidth / 2, y: trackY, width: bounds.width - thumbWidth, height: trackHeight)

        let thumbCenter = positionForIndex(selectedIndex)
        let highlightRect = CGRect(x: thumbWidth / 2, y: trackY, width: max(0, thumbCenter - thumbWidth / 2), height: trackHeight)
        let thumbRect = CGRect(x: thumbCenter - thumbWidth / 2, y: 0, width: thumbWidth, height: thumbWidth)

        let apply = {
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
                markLayer.backgroundColor = (i <= self.selectedIndex
                    ? UIColor.white
                    : DivoColorPalette.accent.withAlphaComponent(0.4)
                ).cgColor
            }
        }

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.2)
            apply()
            CATransaction.commit()
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            apply()
            CATransaction.commit()
        }
    }

    private func layoutStepLabels() {
        for (i, label) in stepLabels.enumerated() {
            let center = positionForIndex(i)
            label.sizeToFit()
            let width = max(label.bounds.width, 24)
            label.frame = CGRect(
                x: center - width / 2,
                y: thumbWidth + labelTopOffset,
                width: width,
                height: label.bounds.height
            )
        }
        updateLabelHighlight()
    }

    private func updateLabelHighlight() {
        for (i, label) in stepLabels.enumerated() {
            let isSelected = i == selectedIndex
            label.textColor = isSelected ? DivoColorPalette.primaryText : DivoColorPalette.systemLabelPlaceholder
            label.font = isSelected ? Font.medium(12) : Font.regular(12)
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
                updateLabelHighlight()
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
            updateLabelHighlight()
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

extension SimilarityStepSlider: UIGestureRecognizerDelegate {
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
