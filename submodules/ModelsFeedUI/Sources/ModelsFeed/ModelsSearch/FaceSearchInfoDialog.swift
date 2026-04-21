import UIKit
import DivoCore
import DivoUIKit

final class FaceSearchInfoDialog: UIViewController {

    private static let shownKey = "Divo.faceSearchInfoShown"

    static var wasShown: Bool {
        UserDefaults.standard.bool(forKey: shownKey)
    }

    static func resetShownFlag() {
        UserDefaults.standard.removeObject(forKey: shownKey)
    }

    var onDismissed: (() -> Void)?

    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        return view
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.card
        view.clipsToBounds = true
        return view
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = DivoImage.faceSearchInfo
        imageView.tintColor = DivoColorPalette.accent
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = 22
        style.maximumLineHeight = 22
        label.attributedText = NSAttributedString(
            string: DivoStrings.faceSearchInfoTitle,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: DivoColorPalette.primaryText,
                .kern: -0.41,
                .paragraphStyle: style
            ]
        )
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0

        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.15
        style.paragraphSpacing = 4
        let text = DivoStrings.faceSearchInfoMessage.replacingOccurrences(of: "\n\n", with: "\n")
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: DivoColorPalette.secondaryText,
                .kern: -0.08,
                .paragraphStyle: style
            ]
        )
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(DivoStrings.faceSearchInfoButton, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = DivoColorPalette.accent
        button.layer.cornerRadius = 26
        button.addDivoPressState(.primary)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupLayout()
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        overlayView.addGestureRecognizer(tap)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.25) {
            self.overlayView.alpha = 1
            self.cardView.alpha = 1
        }
    }

    private func setupLayout() {
        overlayView.alpha = 0
        cardView.alpha = 0

        view.addSubview(overlayView)
        view.addSubview(cardView)
        cardView.addSubview(iconView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(messageLabel)
        cardView.addSubview(actionButton)

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false

        let padding: CGFloat = DivoDesignTokens.Spacing.l

        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            iconView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: padding),
            iconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: padding),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: padding),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -padding),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.xs),
            messageLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: padding),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -padding),

            actionButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: padding),
            actionButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: padding),
            actionButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -padding),
            actionButton.heightAnchor.constraint(equalToConstant: 52),
            actionButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -padding),
        ])
    }

    @objc private func actionTapped() {
        UserDefaults.standard.set(true, forKey: Self.shownKey)
        dismissAnimated { [weak self] in
            self?.onDismissed?()
        }
    }

    @objc private func overlayTapped() {
        dismissAnimated(completion: nil)
    }

    private func dismissAnimated(completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.2, animations: {
            self.overlayView.alpha = 0
            self.cardView.alpha = 0
        }) { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }
}
