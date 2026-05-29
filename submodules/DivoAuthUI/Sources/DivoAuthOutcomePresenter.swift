import Foundation
import DivoCore
import DivoAuth

/// Временный presenter для DivoAuthOutcome — показывает snackbar пользователю
/// после Firebase + REST routing.
///
/// Шаг 5C заменит snackbar для веток A/B на автозапуск teamgram phone-entry,
/// а C/D — на онбординг (PROJ-004). Сейчас все ветки → "Coming soon".
public enum DivoAuthOutcomePresenter {
    @MainActor
    public static func present(_ outcome: DivoAuthOutcome, on controller: DivoAuthWelcomeController?) {
        switch outcome {
        case .divo2Reinstall, .divo1Migration, .unfinishedRegistration, .newUser:
            controller?.showInfo(message: DivoStrings.authComingSoon)
        case .failed(let error):
            let message = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.authSignInFailed
            controller?.showError(message: message)
        }
    }
}
