import UIKit

/// Непрозрачный полноэкранный лоадер DIVO: фон `screenBackground` + центрированный medium-спиннер.
/// Единый визуал для «безэкранных» auth-шагов (соц-вход на welcome, headless signIn / signUp),
/// чтобы смена контроллеров шла без визуального разрыва. Размещение (frame/constraints) — на вызывающем.
public final class DivoFullscreenLoadingView: UIView {
    private let indicator = UIActivityIndicatorView(style: .medium)

    public init() {
        super.init(frame: .zero)
        backgroundColor = DivoColorPalette.screenBackground

        indicator.color = DivoColorPalette.primaryText
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        addSubview(indicator)

        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
