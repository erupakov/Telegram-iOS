import UIKit
import Display
import DivoCore
import DivoUIKit

/// Финальный экран: отправка собранных данных и переход к завершению.
///
/// Реализован по канону state-машины DIVO (см. `docs/CODE_REVIEW.md` §6):
/// одно перечисление `Phase` хранит текущее состояние, `applyPhase()` атомарно
/// расставляет видимости / спиннеры / снекбары. Никаких разрозненных `isLoading`,
/// `hasError`, и т.п.
public final class OnboardingSubmitViewController: UIViewController {

    public protocol Delegate: AnyObject {
        /// Coordinator должен дёрнуть submit-сервис и сообщить о результате через
        /// `applyCompletion(_:)`/`applyError(_:)`. Сам контроллер сети не делает —
        /// он только показывает состояние.
        func submitControllerDidRequestStart(_ controller: OnboardingSubmitViewController)
        func submitControllerDidFinish(_ controller: OnboardingSubmitViewController)
    }

    public enum Phase: Equatable {
        case idle
        case submitting
        case success
        case failed(message: String, networkError: Bool)
    }

    public weak var delegate: Delegate?

    private var phase: Phase = .idle {
        didSet {
            if oldValue != phase { applyPhase() }
        }
    }

    private let titleLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let snackbar = DivoSnackbar()
    private let primaryButton = DivoButton()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DivoColorPalette.screenBackground
        setupUI()
        applyPhase()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if phase == .idle {
            startSubmit()
        }
    }

    public func startSubmit() {
        phase = .submitting
        delegate?.submitControllerDidRequestStart(self)
    }

    public func applySuccess() {
        phase = .success
        delegate?.submitControllerDidFinish(self)
    }

    public func applyFailure(error: Error) {
        let userMsg = (error as? DivoAPIError)?.userFacingMessage
            ?? error.localizedDescription
        let isNetwork: Bool = {
            if let api = error as? DivoAPIError, case .noInternetConnection = api { return true }
            return false
        }()
        phase = .failed(message: userMsg, networkError: isNetwork)
    }

    // MARK: - UI

    private func setupUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Font.helveticaNeue(20)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = DivoColorPalette.accent

        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        primaryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(spinner)
        view.addSubview(primaryButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.l),

            primaryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            primaryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            primaryButton.heightAnchor.constraint(equalToConstant: 56),
            primaryButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
        ])
    }

    // MARK: - applyPhase

    private func applyPhase() {
        switch phase {
        case .idle:
            titleLabel.text = ""
            spinner.stopAnimating()
            primaryButton.isHidden = true
            snackbar.hide(animated: false)

        case .submitting:
            titleLabel.text = "Setting up your profile…"
            spinner.startAnimating()
            primaryButton.isHidden = true
            snackbar.hide(animated: false)

        case .success:
            titleLabel.text = "You're all set"
            spinner.stopAnimating()
            primaryButton.isHidden = true
            snackbar.hide(animated: false)

        case .failed(let message, _):
            titleLabel.text = "We couldn't finish that"
            spinner.stopAnimating()
            primaryButton.isHidden = false
            primaryButton.makeDivoButton(title: OnboardingStrings.resolve("onboarding.button.continue"))
            primaryButton.setTitle(DivoStrings.retry, for: .normal)
            // Persistent snackbar с описанием ошибки.
            let bottomInset = view.safeAreaInsets.bottom + 80
            snackbar.show(
                in: view,
                message: message,
                style: .error,
                bottomInset: bottomInset,
                retryTitle: nil,
                retryAction: nil,
                persistent: true
            )
        }
    }

    @objc private func retryTapped() {
        startSubmit()
    }
}
