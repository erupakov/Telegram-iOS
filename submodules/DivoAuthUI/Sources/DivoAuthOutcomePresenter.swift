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
        case let .newUser(firebaseUid, providerId):
            // Ветка D (новый): DIVO-аккаунта ещё нет. Берём dummy phone → teamgram signUp ("User"),
            // запоминаем pending-регистрацию — после teamgram-входа онбординг пушится в auth-флоу и
            // доводит registration-social (см. AuthorizationSequenceController+DivoOnboarding).
            divoLog("social → branch D (new) → dummy_phone + teamgram + онбординг", level: .info)
            startNewUserRegistration(firebaseUid: firebaseUid, providerId: providerId, on: controller)
        case .unfinishedRegistration:
            // Ветка C: DIVO-аккаунт есть, регистрация не завершена → онбординг-update (отдельно). Пока заглушка.
            divoLog("social → branch C (unfinished) → ждёт онбординг-update", level: .info)
            controller?.showInfo(message: DivoStrings.authComingSoon)
        case .failed(let error):
            let message = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.authSignInFailed
            controller?.showError(message: message)
        }
    }

    /// Ветка D: соц-юзера в DIVO нет. Генерим dummy phone, запоминаем uid/providerId для онбординга
    /// (app-gate после входа), и запускаем headless teamgram signUp по этому номеру.
    @MainActor
    private static func startNewUserRegistration(firebaseUid: String, providerId: String, on controller: DivoAuthWelcomeController?) {
        DivoConfig.pendingSocialRegistration = .init(uid: firebaseUid, providerId: providerId)
        Task { @MainActor in
            do {
                let phone = try await AuthRestService.shared.dummyPhone()
                divoLog("social branch D: dummy_phone=\(phone) → headless teamgram signUp", level: .info)
                controller?.onAuthenticateTeamgram?(phone)
            } catch {
                DivoConfig.pendingSocialRegistration = nil
                divoLog("social branch D: dummy_phone failed: \(error)", level: .error)
                let message = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.authSignInFailed
                controller?.showError(message: message)
            }
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
