import UIKit
import DivoCore
import DivoUIKit

final class FaceOverlayView: UIView {

    var onFaceSelected: ((Int) -> Void)?

    private var faces: [FRFace] = []
    private var imageSize: CGSize = .zero
    private var selectedIndex: Int?
    private var bracketLayers: [(index: Int, layers: [CAShapeLayer])] = []
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
        updateBracketAppearance()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildBrackets()
        if errorBorderLayer != nil {
            rebuildErrorBorder()
        }
    }

    // MARK: - Drawing

    private func rebuildBrackets() {
        bracketLayers.forEach { $0.layers.forEach { $0.removeFromSuperlayer() } }
        bracketLayers.removeAll()
        gestureRecognizers?.forEach { removeGestureRecognizer($0) }

        guard imageSize.width > 0, imageSize.height > 0 else { return }

        for face in faces {
            let rect = convertBBoxToViewRect(face.bbox)
            let layers = createCornerBrackets(in: rect)
            layers.forEach { layer.addSublayer($0) }
            bracketLayers.append((index: face.index, layers: layers))
        }

        updateBracketAppearance()

        if faces.count > 1 {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            addGestureRecognizer(tap)
        }
    }

    private func convertBBoxToViewRect(_ bbox: FRBoundingBox) -> CGRect {
        let scaleX = bounds.width / imageSize.width
        let scaleY = bounds.height / imageSize.height
        // aspectFill: image is scaled by max, centered, clipped
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

    private func createCornerBrackets(in rect: CGRect) -> [CAShapeLayer] {
        let bracketLength = min(rect.width, rect.height) * 0.25
        let cornerRadius = min(rect.width, rect.height) * 0.06
        let lineWidth: CGFloat = 3

        let corners: [(arm1End: CGPoint, arcCenter: CGPoint, arm2End: CGPoint, startAngle: CGFloat, endAngle: CGFloat)] = [
            // top-left: vertical arm goes down, arc turns, horizontal arm goes right
            (arm1End: CGPoint(x: rect.minX, y: rect.minY + bracketLength),
             arcCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
             arm2End: CGPoint(x: rect.minX + bracketLength, y: rect.minY),
             startAngle: .pi, endAngle: -.pi / 2),
            // top-right: horizontal arm goes left, arc turns, vertical arm goes down
            (arm1End: CGPoint(x: rect.maxX - bracketLength, y: rect.minY),
             arcCenter: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
             arm2End: CGPoint(x: rect.maxX, y: rect.minY + bracketLength),
             startAngle: -.pi / 2, endAngle: 0),
            // bottom-right: vertical arm goes up, arc turns, horizontal arm goes left
            (arm1End: CGPoint(x: rect.maxX, y: rect.maxY - bracketLength),
             arcCenter: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
             arm2End: CGPoint(x: rect.maxX - bracketLength, y: rect.maxY),
             startAngle: 0, endAngle: .pi / 2),
            // bottom-left: horizontal arm goes right, arc turns, vertical arm goes up
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
            shape.strokeColor = DivoColorPalette.accent.cgColor
            shape.fillColor = nil
            shape.lineWidth = lineWidth
            shape.lineCap = .round
            return shape
        }
    }

    private func updateBracketAppearance() {
        let hasSelection = selectedIndex != nil
        for entry in bracketLayers {
            let isSelected = entry.index == selectedIndex
            let alpha: Float = hasSelection && !isSelected ? 0.3 : 1.0
            for shape in entry.layers {
                shape.opacity = alpha
            }
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
