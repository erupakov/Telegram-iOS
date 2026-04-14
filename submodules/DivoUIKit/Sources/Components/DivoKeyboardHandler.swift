import UIKit
import DivoCore

public final class DivoKeyboardHandler {

    private weak var scrollView: UIScrollView?
    private weak var buttonConstraint: NSLayoutConstraint?
    private weak var overlayConstraint: NSLayoutConstraint?
    private weak var hostView: UIView?

    private let defaultButtonOffset: CGFloat
    private let defaultScrollInset: CGFloat
    private let scrollToActiveField: (() -> Void)?

    private static let overlayKeyboardGap: CGFloat = 26
    private static let scrollInsetPadding: CGFloat = 90

    public init(
        scrollView: UIScrollView,
        buttonConstraint: NSLayoutConstraint,
        overlayConstraint: NSLayoutConstraint,
        hostView: UIView,
        defaultButtonOffset: CGFloat = -40,
        defaultScrollInset: CGFloat = 80,
        scrollToActiveField: (() -> Void)? = nil
    ) {
        self.scrollView = scrollView
        self.buttonConstraint = buttonConstraint
        self.overlayConstraint = overlayConstraint
        self.hostView = hostView
        self.defaultButtonOffset = defaultButtonOffset
        self.defaultScrollInset = defaultScrollInset
        self.scrollToActiveField = scrollToActiveField
    }

    public func subscribe() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    public func unsubscribe() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }

        let height = frame.height

        scrollView?.contentInset.bottom = height + Self.scrollInsetPadding
        scrollView?.verticalScrollIndicatorInsets.bottom = height + Self.scrollInsetPadding

        buttonConstraint?.constant = -(height + DivoDesignTokens.Spacing.m)
        overlayConstraint?.constant = -(height - Self.overlayKeyboardGap)

        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
            self.hostView?.layoutIfNeeded()
            self.scrollToActiveField?()
        }, completion: nil)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }

        buttonConstraint?.constant = defaultButtonOffset
        overlayConstraint?.constant = 0

        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
            self.scrollView?.contentInset.bottom = self.defaultScrollInset
            self.scrollView?.verticalScrollIndicatorInsets.bottom = 0
            self.hostView?.layoutIfNeeded()
        }, completion: nil)
    }
}
