import Foundation
import DivoCore
import DivoAuth

/// Presenter для DivoAuthOutcome после Firebase + REST routing. Все ветки заходят в teamgram через
/// `onAuthenticateTeamgram` (headless), DIVO-токен уже выставлен login-social'ом в роутере:
/// - A (telegramLinked=true) → signIn по user/info.phone → таббар (без онбординга/линка);
/// - B (аккаунт есть, teamgram не связан) → signUp + telegram-link + синк имени → таббар (без онбординга);
/// - D (новый, login-social 404/422) → dummy_phone + teamgram + онбординг (registration-social на submit).
public enum DivoAuthOutcomePresenter {
    @MainActor
    public static func present(_ outcome: DivoAuthOutcome, on controller: DivoAuthWelcomeController?) {
        switch outcome {
        case let .divo2Reinstall(divoUserId, phone):
            if let phone, !phone.isEmpty {
                divoLog("social → branch A (reinstall) divoUserId=\(divoUserId) → headless teamgram signIn", level: .info)
                startTeamgram(phone: phone, on: controller)
            } else {
                // Гугл без recoverable phone (user/info.phone=nil) → фейковый номер через dummy_phone + relink (как ветка B).
                divoLog("social → branch A без phone в user/info → dummy_phone + relink", level: .warning)
                DivoConfig.currentDivoUserId = divoUserId
                startTeamgramForLink(phone: nil, on: controller)
            }
        case let .divo1Migration(divoUserId, phone):
            // Ветка B (telegramLinked=false): headless teamgram + telegram-link (сшивка DIVO↔teamgram) после входа.
            divoLog("social → branch B (link) divoUserId=\(divoUserId) → headless teamgram + telegram-link", level: .info)
            DivoConfig.currentDivoUserId = divoUserId
            startTeamgramForLink(phone: phone, on: controller)
        case let .newUser(firebaseUid, providerId):
            // Ветка D (новый): DIVO-аккаунта ещё нет. Берём dummy phone → teamgram signUp ("User"),
            // запоминаем pending-регистрацию — после teamgram-входа онбординг пушится в auth-флоу и
            // доводит registration-social (см. AuthorizationSequenceController+DivoOnboarding).
            divoLog("social → branch D (new) → dummy_phone + teamgram + онбординг", level: .info)
            startNewUserRegistration(firebaseUid: firebaseUid, providerId: providerId, on: controller)
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
            DivoConfig.resetDivoSessionForRollback() // частичный auth (токен) без teamgram → откат
            divoLog("social outcome без phone в user/info — headless teamgram невозможен", level: .error)
            controller?.showError(message: DivoStrings.authSignInFailed)
            return
        }
        controller?.onAuthenticateTeamgram?(phone)
    }

    /// Ветка B: teamgram по `user/info.phone`, а нет его — генерим dummy. Номер → `pendingSocialLinkPhone` для telegram-link после входа. Фейл dummy → откат частичного auth.
    @MainActor
    private static func startTeamgramForLink(phone: String?, on controller: DivoAuthWelcomeController?) {
        if let phone, !phone.isEmpty {
            DivoConfig.pendingSocialLinkPhone = phone
            controller?.onAuthenticateTeamgram?(phone)
            return
        }
        Task { @MainActor in
            do {
                let dummy = try await AuthRestService.shared.dummyPhone()
                DivoConfig.pendingSocialLinkPhone = dummy
                divoLog("social branch B: dummy_phone=\(dummy) → headless teamgram", level: .info)
                controller?.onAuthenticateTeamgram?(dummy)
            } catch {
                DivoConfig.resetDivoSessionForRollback()
                divoLog("social branch B: dummy_phone failed: \(error)", level: .error)
                let message = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.authSignInFailed
                controller?.showError(message: message)
            }
        }
    }
}
