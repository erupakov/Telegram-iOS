import UIKit

public final class DivoSnackbar {
    public enum Style {
        case success
        case error
    }

    // MARK: - Global keyboard tracking

    /// Глобальный трекер рамки клавиатуры в координатах окна.
    /// Нужен, чтобы `show` знал текущую позицию клавиатуры даже если был вызван между нотификациями.
    private static let keyboardTracker: KeyboardTracker = KeyboardTracker()

    /// Прогревает глобальный keyboard-трекер. Вызывать при `loadDisplayNode`/`viewDidLoad`
    /// экрана, где может одновременно быть клавиатура и snackbar, иначе при ленивой
    /// инициализации трекер пропустит первое `keyboardWillChangeFrame` и не поднимет снек.
    public static func prepareKeyboardTracking() {
        _ = keyboardTracker
    }

    private final class KeyboardTracker {
        private(set) var currentFrame: CGRect = .zero

        init() {
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                           name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
            nc.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                           name: UIResponder.keyboardWillHideNotification, object: nil)
        }

        @objc private func keyboardWillChange(_ note: Notification) {
            if let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                currentFrame = frame
            }
        }

        @objc private func keyboardWillHide(_ note: Notification) {
            currentFrame = .zero
        }
    }

    // MARK: - Instance state

    private weak var hostView: UIView?
    private var snackbarView: UIView?
    private var hidingSnackbarView: UIView?
    private var hideTimer: Foundation.Timer?
    private var retryAction: (() -> Void)?
    private var bottomConstraint: NSLayoutConstraint?
    private var baseBottomInset: CGFloat = 0
    private var keyboardObservers: [NSObjectProtocol] = []
    private var currentMessage: String?
    private var currentStyle: Style?

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
        // Убедимся, что глобальный трекер инициализирован
        _ = DivoSnackbar.keyboardTracker

        if snackbarView != nil, currentMessage == message, currentStyle == style {
            self.retryAction = retryAction
            hideTimer?.invalidate()
            if !persistent {
                hideTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    self?.hide(animated: true)
                }
            }
            return
        }

        hide(animated: false)
        if let hiding = hidingSnackbarView {
            hiding.layer.removeAllAnimations()
            hiding.removeFromSuperview()
            hidingSnackbarView = nil
        }

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
        self.currentMessage = message
        self.currentStyle = style
        self.baseBottomInset = bottomInset
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

        // Первичный layout + учёт клавиатуры, если она уже поднята к моменту show
        hostView.layoutIfNeeded()
        applyKeyboardOffset(animated: false, notification: nil)

        snack.alpha = 0
        snack.transform = CGAffineTransform(translationX: 0, y: 30)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3, options: []) {
            snack.alpha = 1
            snack.transform = .identity
        }

        registerKeyboardObservers()

        hideTimer?.invalidate()
        if !persistent {
            hideTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.hide(animated: true)
            }
        }
    }

    public func updateBottomInset(_ inset: CGFloat) {
        baseBottomInset = inset
        applyKeyboardOffset(animated: false, notification: nil)
    }

    public func bringToFront() {
        guard let snack = snackbarView, let host = hostView else { return }
        host.bringSubviewToFront(snack)
    }

    public func hide(animated: Bool = true) {
        hideTimer?.invalidate()
        hideTimer = nil
        removeKeyboardObservers()
        guard let snack = snackbarView else { return }
        snackbarView = nil
        retryAction = nil
        bottomConstraint = nil
        currentMessage = nil
        currentStyle = nil
        if animated {
            hidingSnackbarView = snack
            UIView.animate(withDuration: 0.2, animations: {
                snack.alpha = 0
                snack.transform = CGAffineTransform(translationX: 0, y: 20)
            }, completion: { [weak self] _ in
                snack.removeFromSuperview()
                if self?.hidingSnackbarView === snack {
                    self?.hidingSnackbarView = nil
                }
            })
        } else {
            snack.removeFromSuperview()
        }
    }

    // MARK: - Keyboard tracking

    /// Пересчитывает `bottomConstraint.constant` так, чтобы snack оказался не ниже
    /// `keyboardTop - baseBottomInset`. Работает независимо от того, какой anchor передан в show.
    private func applyKeyboardOffset(animated: Bool, notification: Notification?) {
        guard let hostView = hostView,
              let snack = snackbarView,
              let bottomConstraint = bottomConstraint else { return }

        // Сбрасываем на «нейтральное» значение, чтобы измерить естественную позицию snack
        bottomConstraint.constant = -baseBottomInset
        hostView.layoutIfNeeded()

        let keyboardFrameInWindow: CGRect
        if let notification,
           let endFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardFrameInWindow = endFrame
        } else {
            keyboardFrameInWindow = DivoSnackbar.keyboardTracker.currentFrame
        }

        let isKeyboardVisible = keyboardFrameInWindow != .zero
            && (notification?.name != UIResponder.keyboardWillHideNotification)

        var lift: CGFloat = 0
        if isKeyboardVisible {
            let keyboardInHost = hostView.convert(keyboardFrameInWindow, from: nil)
            let snackMaxY = snack.frame.maxY
            lift = max(0, snackMaxY - keyboardInHost.minY + baseBottomInset)
        }

        let newConstant = -(baseBottomInset + lift)
        guard abs(newConstant - bottomConstraint.constant) > 0.5 else { return }

        bottomConstraint.constant = newConstant

        if animated, let notification {
            let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
            let rawCurve = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue
                ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
            let options = UIView.AnimationOptions(rawValue: rawCurve << 16)
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                hostView.layoutIfNeeded()
            })
        } else {
            hostView.layoutIfNeeded()
        }
    }

    private func registerKeyboardObservers() {
        removeKeyboardObservers()
        let nc = NotificationCenter.default

        let change = nc.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification,
                                    object: nil, queue: .main) { [weak self] note in
            self?.applyKeyboardOffset(animated: true, notification: note)
        }
        let hideObs = nc.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                     object: nil, queue: .main) { [weak self] note in
            self?.applyKeyboardOffset(animated: true, notification: note)
        }
        keyboardObservers = [change, hideObs]
    }

    private func removeKeyboardObservers() {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
        keyboardObservers.removeAll()
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
