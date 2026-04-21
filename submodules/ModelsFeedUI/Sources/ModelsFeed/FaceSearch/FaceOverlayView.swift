import UIKit
import DivoCore
import DivoUIKit

final class FaceOverlayView: UIView {

    var onFaceSelected: ((Int) -> Void)?

    private var faces: [FRFace] = []
    private var imageSize: CGSize = .zero
    private var selectedIndex: Int?
    private var bracketLayers: [(index: Int, layers: [CAShapeLayer])] = []
    private var dimmingLayer: CAShapeLayer?
    private var selectionBorderLayer: CAShapeLayer?
    private var errorBorderLayer: CAShapeLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public

    func configure(faces: [FRFace], imageSize: CGSize, selectedIndex: Int?) {
        self.faces = faces
        self.imageSize = imageSize
        self.selectedIndex = selectedIndex
        setNeedsLayout()
    }

    func setSelectedIndex(_ index: Int?) {
        self.selectedIndex = index
        rebuildOverlay()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildOverlay()
        if errorBorderLayer != nil {
            rebuildErrorBorder()
        }
    }

    // MARK: - Drawing

    private func rebuildOverlay() {
        bracketLayers.forEach { $0.layers.forEach { $0.removeFromSuperlayer() } }
        bracketLayers.removeAll()
        dimmingLayer?.removeFromSuperlayer()
        dimmingLayer = nil
        selectionBorderLayer?.removeFromSuperlayer()
        selectionBorderLayer = nil
        gestureRecognizers?.forEach { removeGestureRecognizer($0) }

        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let hasSelection = selectedIndex != nil

        if hasSelection {
            rebuildDimming()
        }

        for face in faces {
            let rect = convertBBoxToViewRect(face.bbox)
            let isSelected = face.index == selectedIndex

            if isSelected {
                let cornerRadius = min(rect.width, rect.height) * 0.12
                let border = CAShapeLayer()
                border.path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
                border.strokeColor = DivoColorPalette.accent.cgColor
                border.fillColor = nil
                border.lineWidth = 3
                layer.addSublayer(border)
                selectionBorderLayer = border
            } else {
                let color: UIColor = hasSelection ? .white : DivoColorPalette.accent
                let layers = createCornerBrackets(in: rect, color: color)
                layers.forEach { layer.addSublayer($0) }
                bracketLayers.append((index: face.index, layers: layers))
            }
        }

        if faces.count > 1 {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            addGestureRecognizer(tap)
        }
    }

    private func rebuildDimming() {
        guard let selectedIndex = selectedIndex,
              let selectedFace = faces.first(where: { $0.index == selectedIndex }) else { return }

        let selectedRect = convertBBoxToViewRect(selectedFace.bbox)
        let cornerRadius = min(selectedRect.width, selectedRect.height) * 0.12

        let fullPath = UIBezierPath(rect: bounds)
        let cutoutPath = UIBezierPath(roundedRect: selectedRect, cornerRadius: cornerRadius)
        fullPath.append(cutoutPath)
        fullPath.usesEvenOddFillRule = true

        let dimming = CAShapeLayer()
        dimming.path = fullPath.cgPath
        dimming.fillRule = .evenOdd
        dimming.fillColor = UIColor.black.withAlphaComponent(0.56).cgColor
        layer.addSublayer(dimming)
        dimmingLayer = dimming
    }

    private func convertBBoxToViewRect(_ bbox: FRBoundingBox) -> CGRect {
        let scaleX = bounds.width / imageSize.width
        let scaleY = bounds.height / imageSize.height
        let scale = max(scaleX, scaleY)

        let scaledW = imageSize.width * scale
        let scaledH = imageSize.height * scale
        let offsetX = (bounds.width - scaledW) / 2
        let offsetY = (bounds.height - scaledH) / 2

        let x = offsetX + bbox.x1 * scale
        let y = offsetY + bbox.y1 * scale
        let w = (bbox.x2 - bbox.x1) * scale
        let h = (bbox.y2 - bbox.y1) * scale

        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func createCornerBrackets(in rect: CGRect, color: UIColor) -> [CAShapeLayer] {
        let bracketLength = min(rect.width, rect.height) * 0.25
        let cornerRadius = min(rect.width, rect.height) * 0.06
        let lineWidth: CGFloat = 3

        let corners: [(arm1End: CGPoint, arcCenter: CGPoint, arm2End: CGPoint, startAngle: CGFloat, endAngle: CGFloat)] = [
            (arm1End: CGPoint(x: rect.minX, y: rect.minY + bracketLength),
             arcCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
             arm2End: CGPoint(x: rect.minX + bracketLength, y: rect.minY),
             startAngle: .pi, endAngle: -.pi / 2),
            (arm1End: CGPoint(x: rect.maxX - bracketLength, y: rect.minY),
             arcCenter: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
             arm2End: CGPoint(x: rect.maxX, y: rect.minY + bracketLength),
             startAngle: -.pi / 2, endAngle: 0),
            (arm1End: CGPoint(x: rect.maxX, y: rect.maxY - bracketLength),
             arcCenter: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
             arm2End: CGPoint(x: rect.maxX - bracketLength, y: rect.maxY),
             startAngle: 0, endAngle: .pi / 2),
            (arm1End: CGPoint(x: rect.minX + bracketLength, y: rect.maxY),
             arcCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
             arm2End: CGPoint(x: rect.minX, y: rect.maxY - bracketLength),
             startAngle: .pi / 2, endAngle: .pi),
        ]

        return corners.map { corner in
            let path = UIBezierPath()
            path.move(to: corner.arm1End)
            path.addLine(to: CGPoint(
                x: corner.arcCenter.x + cornerRadius * cos(corner.startAngle),
                y: corner.arcCenter.y + cornerRadius * sin(corner.startAngle)
            ))
            path.addArc(
                withCenter: corner.arcCenter,
                radius: cornerRadius,
                startAngle: corner.startAngle,
                endAngle: corner.endAngle,
                clockwise: true
            )
            path.addLine(to: corner.arm2End)

            let shape = CAShapeLayer()
            shape.path = path.cgPath
            shape.strokeColor = color.cgColor
            shape.fillColor = nil
            shape.lineWidth = lineWidth
            shape.lineCap = .round
            return shape
        }
    }

    // MARK: - Tap

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        var bestFace: FRFace?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for face in faces {
            let rect = convertBBoxToViewRect(face.bbox)
            let expandedRect = rect.insetBy(dx: -20, dy: -20)
            if expandedRect.contains(point) {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let distance = hypot(point.x - center.x, point.y - center.y)
                if distance < bestDistance {
                    bestDistance = distance
                    bestFace = face
                }
            }
        }

        if let face = bestFace {
            onFaceSelected?(face.index)
        }
    }
}

// MARK: - Error border

extension FaceOverlayView {

    func showErrorBorder() {
        faces = []
        selectedIndex = nil
        bracketLayers.forEach { $0.layers.forEach { $0.removeFromSuperlayer() } }
        bracketLayers.removeAll()
        dimmingLayer?.removeFromSuperlayer()
        dimmingLayer = nil
        selectionBorderLayer?.removeFromSuperlayer()
        selectionBorderLayer = nil

        rebuildErrorBorder()
    }

    func clearErrorBorder() {
        errorBorderLayer?.removeFromSuperlayer()
        errorBorderLayer = nil
    }

    private func rebuildErrorBorder() {
        errorBorderLayer?.removeFromSuperlayer()

        let inset: CGFloat = 60
        let rect = bounds.insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else { return }

        let shape = CAShapeLayer()
        let cornerRadius = min(rect.width, rect.height) * 0.06
        shape.path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        shape.strokeColor = DivoColorPalette.errorState.cgColor
        shape.fillColor = nil
        shape.lineWidth = 2
        layer.addSublayer(shape)
        errorBorderLayer = shape
    }
}
