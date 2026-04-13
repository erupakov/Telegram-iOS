import UIKit

public final class DivoSnackbar {
    public enum Style {
        case success
        case error
    }

    private weak var hostView: UIView?
    private var snackbarView: UIView?
    private var hideTimer: Foundation.Timer?
    private var retryAction: (() -> Void)?
    private var bottomConstraint: NSLayoutConstraint?

    public init() {}

    public func show(
        in hostView: UIView,
        message: String,
        style: Style,
        bottomInset: CGFloat,
        bottomAnchor: NSLayoutYAxisAnchor? = nil,
        retryTitle: String? = nil,
        retryAction: (() -> Void)? = nil,
        persistent: Bool = false
    ) {
        hide(animated: false)

        let snack = UIView()
        snack.backgroundColor = style == .error
            ? DivoColorPalette.snackbarError
            : DivoColorPalette.snackbarSuccess
        snack.layer.cornerRadius = 8
        snack.layer.masksToBounds = true
        snack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = message
        titleLabel.font = UIFont(name: "HelveticaNeue", size: 14) ?? UIFont.systemFont(ofSize: 14)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        snack.addSubview(titleLabel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(snackbarTapped))
        snack.addGestureRecognizer(tap)

        self.hostView = hostView
        self.retryAction = retryAction
        self.snackbarView = snack
        hostView.addSubview(snack)
        hostView.bringSubviewToFront(snack)

        let anchor = bottomAnchor ?? hostView.bottomAnchor
        let bottom = snack.bottomAnchor.constraint(equalTo: anchor, constant: -bottomInset)
        self.bottomConstraint = bottom
        NSLayoutConstraint.activate([
            snack.leadingAnchor.constraint(equalTo: hostView.leadingAnchor, constant: 8),
            snack.trailingAnchor.constraint(equalTo: hostView.trailingAnchor, constant: -8),
            bottom,
            snack.heightAnchor.constraint(equalToConstant: 50)
        ])

        if style == .error, retryAction != nil, let retryTitle, !retryTitle.isEmpty {
            let retryButton = UIButton(type: .system)
            retryButton.setTitle(retryTitle, for: .normal)
            retryButton.titleLabel?.font = UIFont(name: "HelveticaNeue-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
            retryButton.setTitleColor(.white, for: .normal)
            retryButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
            retryButton.addTarget(self, action: #selector(snackbarRetryTapped), for: .touchUpInside)
            retryButton.translatesAutoresizingMaskIntoConstraints = false
            snack.addSubview(retryButton)

            NSLayoutConstraint.activate([
                retryButton.trailingAnchor.constraint(equalTo: snack.trailingAnchor, constant: -4),
                retryButton.topAnchor.constraint(equalTo: snack.topAnchor),
                retryButton.bottomAnchor.constraint(equalTo: snack.bottomAnchor),

                titleLabel.leadingAnchor.constraint(equalTo: snack.leadingAnchor, constant: 16),
                titleLabel.trailingAnchor.constraint(equalTo: retryButton.leadingAnchor, constant: -12),
                titleLabel.topAnchor.constraint(equalTo: snack.topAnchor),
                titleLabel.bottomAnchor.constraint(equalTo: snack.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: snack.leadingAnchor, constant: 16),
                titleLabel.trailingAnchor.constraint(equalTo: snack.trailingAnchor, constant: -16),
                titleLabel.topAnchor.constraint(equalTo: snack.topAnchor),
                titleLabel.bottomAnchor.constraint(equalTo: snack.bottomAnchor)
            ])
        }

        snack.alpha = 0
        snack.transform = CGAffineTransform(translationX: 0, y: 30)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: []) {
            snack.alpha = 1
            snack.transform = .identity
        }

        hideTimer?.invalidate()
        if !persistent {
            hideTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.hide(animated: true)
            }
        }
    }

    public func updateBottomInset(_ inset: CGFloat) {
        bottomConstraint?.constant = -inset
    }

    public func bringToFront() {
        guard let snack = snackbarView, let host = hostView else { return }
        host.bringSubviewToFront(snack)
    }

    public func hide(animated: Bool = true) {
        hideTimer?.invalidate()
        hideTimer = nil
        guard let snack = snackbarView else { return }
        snackbarView = nil
        retryAction = nil
        bottomConstraint = nil
        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                snack.alpha = 0
                snack.transform = CGAffineTransform(translationX: 0, y: 20)
            }, completion: { _ in
                snack.removeFromSuperview()
            })
        } else {
            snack.removeFromSuperview()
        }
    }

    @objc private func snackbarTapped() {
        hide(animated: true)
    }

    @objc private func snackbarRetryTapped() {
        let action = retryAction
        hide(animated: true)
        action?()
    }
}
