import UIKit

/// Progressive glass blur overlay with a gradient mask.
///
/// Edge where the blur is opaque depends on `Direction`:
/// - `.top` — opaque at top, fades down.
/// - `.bottom` — opaque at bottom, fades up.
///
/// `Falloff` controls the mask shape:
/// - `.anchored` — tight fade with an opaque band near the edge (used on image cards,
///   see `project_card_blur_settings`).
/// - `.linear` — simple linear gradient from clear to fully opaque across the length.
/// - `.soft` — eased onset with capped peak (peaks at ~0.75 alpha), for overlays where
///   a hard edge or full blur feels too aggressive.
///
/// `intensity` (0...1) uniformly scales the peak mask alpha — use it to dial the
/// blur strength down without changing the fade shape. `UIVisualEffectView` ignores
/// parent-view alpha on modern iOS, so masking is the reliable way to attenuate.
///
/// Defaults (`.systemUltraThinMaterialDark`, `.anchored`, `intensity = 1`) match the
/// working card implementation. Size is controlled by the parent via frame or Auto Layout.
public final class DivoGlassBlurView: UIView {
    public enum Direction {
        case top
        case bottom
    }

    public enum Falloff {
        case anchored
        case linear
        case soft
    }

    private let blurView: UIVisualEffectView
    private let maskLayer = CAGradientLayer()

    public init(
        direction: Direction,
        blurStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark,
        falloff: Falloff = .anchored,
        intensity: CGFloat = 1.0
    ) {
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        blurView.isUserInteractionEnabled = false
        addSubview(blurView)

        maskLayer.startPoint = CGPoint(x: 0.5, y: 0)
        maskLayer.endPoint = CGPoint(x: 0.5, y: 1)

        let k = max(0, min(1, intensity))
        let clear = UIColor.clear.cgColor
        func mask(_ alpha: CGFloat) -> CGColor {
            UIColor.white.withAlphaComponent(alpha * k).cgColor
        }
        let opaque = mask(1.0)
        // Soft ramp stops — eased onset, capped peak at ~0.75.
        let softStep1 = mask(0.1)
        let softStep2 = mask(0.4)
        let softPeak = mask(0.75)

        switch (direction, falloff) {
        case (.top, .anchored):
            maskLayer.colors = [opaque, opaque, clear]
            maskLayer.locations = [0, 0.3, 1.0]
        case (.bottom, .anchored):
            maskLayer.colors = [clear, opaque, opaque]
            maskLayer.locations = [0, 0.75, 1.0]
        case (.top, .linear):
            maskLayer.colors = [opaque, clear]
            maskLayer.locations = [0, 1.0]
        case (.bottom, .linear):
            maskLayer.colors = [clear, opaque]
            maskLayer.locations = [0, 1.0]
        case (.top, .soft):
            maskLayer.colors = [softPeak, softStep2, softStep1, clear]
            maskLayer.locations = [0, 0.2, 0.55, 1.0]
        case (.bottom, .soft):
            maskLayer.colors = [clear, softStep1, softStep2, softPeak]
            maskLayer.locations = [0, 0.45, 0.8, 1.0]
        }
        blurView.layer.mask = maskLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = bounds
        CATransaction.commit()
    }
}
