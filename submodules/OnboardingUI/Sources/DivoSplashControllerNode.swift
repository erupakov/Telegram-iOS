import UIKit
import AsyncDisplayKit
import Display
import DivoUIKit

final class DivoSplashControllerNode: ASDisplayNode {
    private static let overlayAlpha: CGFloat = 0.2
    private static let logoSize = CGSize(width: 160, height: 54)
    private static let logoFadeInDuration: TimeInterval = 0.3

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
        view.backgroundColor = DivoColorPalette.shadow.withAlphaComponent(DivoSplashControllerNode.overlayAlpha)
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

    override init() {
        super.init()
        self.backgroundColor = DivoColorPalette.splashBackground
    }

    override func didLoad() {
        super.didLoad()
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        setupViews()
    }

    private func setupViews() {
        self.view.addSubview(backgroundImageView)
        self.view.addSubview(overlayView)
        self.view.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: self.view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            logoImageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: Self.logoSize.width),
            logoImageView.heightAnchor.constraint(equalToConstant: Self.logoSize.height)
        ])
    }

    func animateIn() {
        logoImageView.alpha = 0
        UIView.animate(withDuration: Self.logoFadeInDuration) {
            self.logoImageView.alpha = 1
        }
    }
}
