import Foundation
import DivoCore
import DivoAuth

/// Presenter для DivoAuthOutcome после Firebase + REST routing.
///
/// Ветки A/B (существующий юзер) → headless teamgram-вход по известному phone
/// (DIVO-токен уже выставлен login-social'ом в роутере). Ветки C/D (новый/недозаведённый)
/// → онбординг, который вшивается последним шагом — пока info-заглушка.
public enum DivoAuthOutcomePresenter {
    @MainActor
    public static func present(_ outcome: DivoAuthOutcome, on controller: DivoAuthWelcomeController?) {
        switch outcome {
        case let .divo2Reinstall(divoUserId, phone):
            divoLog("social → branch A (reinstall) divoUserId=\(divoUserId) → headless teamgram signIn", level: .info)
            startTeamgram(phone: phone, on: controller)
        case let .divo1Migration(divoUserId, phone):
            // TODO: после headless signUp ветке B нужен ещё telegram-link (DIVO↔teamgram).
            // Пока пропускается — та же дыра, что в phone-флоу (нет telegramUserId в точке).
            divoLog("social → branch B (migration) divoUserId=\(divoUserId) → headless teamgram signUp", level: .info)
            startTeamgram(phone: phone, on: controller)
        case .unfinishedRegistration, .newUser:
            // Новый / недозаведённый → онбординг (вставляется последним шагом). Пока заглушка.
            divoLog("social → branch C/D → ждёт онбординг-вставку", level: .info)
            controller?.showInfo(message: DivoStrings.authComingSoon)
        case .failed(let error):
            let message = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.authSignInFailed
            controller?.showError(message: message)
        }
    }

    @MainActor
    private static func startTeamgram(phone: String?, on controller: DivoAuthWelcomeController?) {
        guard let phone, !phone.isEmpty else {
            divoLog("social outcome без phone в user/info — headless teamgram невозможен", level: .error)
            controller?.showError(message: DivoStrings.authSignInFailed)
            return
        }
        controller?.onAuthenticateTeamgram?(phone)
    }
}
