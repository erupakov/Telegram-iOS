import UIKit

/// Универсальный splash-overlay, который показывается поверх rootController
/// на cold start приложения. Покрывает iOS системный crossfade между LaunchScreen
/// и первым кадром приложения и даёт пользователю ощущение бесшовного брендового splash.
///
/// Использовать через `addSubview` + `animateIn()` + `dismiss(after:)`.
public final class DivoSplashOverlayView: UIView {
    private static let overlayAlpha: CGFloat = 0.2
    private static let logoSize = CGSize(width: 160, height: 54)
    private static let logoFadeInDuration: TimeInterval = 0.3
    private static let dismissDuration: TimeInterval = 0.3

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = DivoImage.splashScreen
        return imageView
    }()

    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.shadow.withAlphaComponent(DivoSplashOverlayView.overlayAlpha)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = DivoImage.logo
        imageView.tintColor = DivoColorPalette.cardBackground
        return imageView
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DivoColorPalette.splashBackground
        setupViews()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(backgroundImageView)
        addSubview(overlayView)
        addSubview(logoImageView)

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),

            logoImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: Self.logoSize.width),
            logoImageView.heightAnchor.constraint(equalToConstant: Self.logoSize.height)
        ])
    }

    private var animateInTime: CFAbsoluteTime?

    public func animateIn() {
        self.animateInTime = CFAbsoluteTimeGetCurrent()
        logoImageView.alpha = 0
        UIView.animate(withDuration: Self.logoFadeInDuration) {
            self.logoImageView.alpha = 1
        }
    }

    public func dismiss(after delay: TimeInterval, completion: (() -> Void)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: Self.dismissDuration, animations: {
                self.alpha = 0
            }, completion: { _ in
                self.removeFromSuperview()
                completion?()
            })
        }
    }

    /// Снимает splash, как только rootController готов, но не раньше `minVisibleDuration`
    /// от момента `animateIn()`. Так гарантируется, что fade-in лого успеет проиграться
    /// даже при моментальной загрузке (warm start / быстрое устройство).
    public func dismissWhenReady(minVisibleDuration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        let elapsed = CFAbsoluteTimeGetCurrent() - (self.animateInTime ?? CFAbsoluteTimeGetCurrent())
        let remaining = max(0, minVisibleDuration - elapsed)
        self.dismiss(after: remaining, completion: completion)
    }
}
