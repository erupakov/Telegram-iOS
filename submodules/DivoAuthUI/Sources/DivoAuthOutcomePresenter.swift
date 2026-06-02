import Foundation
import DivoCore
import DivoAuth

/// Presenter для DivoAuthOutcome после Firebase + REST routing. Все ветки заходят в teamgram через
/// `onAuthenticateTeamgram` (headless), DIVO-токен уже выставлен login-social'ом в роутере:
/// - A (reinstall, telegramLinked=true) → signIn по user/info.phone → таббар (без онбординга/линка);
/// - B (migration, finished, не связан) → signUp + telegram-link + синк имени → таббар;
/// - C (unfinished) → teamgram + онбординг (выбор роли + change-role/update-profile на submit) + линк;
/// - D (новый) → dummy_phone + teamgram + онбординг (registration-social на submit).
public enum DivoAuthOutcomePresenter {
    @MainActor
    public static func present(_ outcome: DivoAuthOutcome, on controller: DivoAuthWelcomeController?) {
        switch outcome {
        case let .divo2Reinstall(divoUserId, phone):
            divoLog("social → branch A (reinstall) divoUserId=\(divoUserId) → headless teamgram signIn", level: .info)
            startTeamgram(phone: phone, on: controller)
        case let .divo1Migration(divoUserId, phone):
            // Ветка B (telegramLinked=false, регистрация завершена): headless teamgram + telegram-link
            // (сшивка DIVO↔свежий teamgram) + синк имени из DIVO-профиля — делает
            // divoCompleteAuthorizationWithDivoLink по pendingSocialLinkPhone. Онбординга нет.
            divoLog("social → branch B (migration) divoUserId=\(divoUserId) → headless teamgram + telegram-link", level: .info)
            DivoConfig.currentDivoUserId = divoUserId
            DivoConfig.pendingSocialLinkPhone = phone
            startTeamgram(phone: phone, on: controller)
        case let .newUser(firebaseUid, providerId):
            // Ветка D (новый): DIVO-аккаунта ещё нет. Берём dummy phone → teamgram signUp ("User"),
            // запоминаем pending-регистрацию — после teamgram-входа онбординг пушится в auth-флоу и
            // доводит registration-social (см. AuthorizationSequenceController+DivoOnboarding).
            divoLog("social → branch D (new) → dummy_phone + teamgram + онбординг", level: .info)
            startNewUserRegistration(firebaseUid: firebaseUid, providerId: providerId, on: controller)
        case let .unfinishedRegistration(divoUserId, phone):
            // Ветка C: DIVO-аккаунт есть, регистрация НЕ завершена → headless teamgram + онбординг
            // (выбор роли + профиль), submit доводит через change-role + update-profile (аккаунт уже
            // есть, registration-social НЕ зовём). telegramLinked=false → линкуем после онбординга.
            divoLog("social → branch C (unfinished) divoUserId=\(divoUserId) → headless teamgram + онбординг (resume)", level: .info)
            DivoConfig.currentDivoUserId = divoUserId
            DivoConfig.pendingSocialExistingOnboarding = true
            startTeamgramForExisting(phone: phone, on: controller)
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

    /// Ветка C (существующий-не-пройден): teamgram по `user/info.phone`, а если бэк его ещё не отдал —
    /// генерим dummy (как ветка D). Запоминаем номер в `pendingSocialLinkPhone` для telegram-link после
    /// онбординга. Онбординг покажет `divoCompleteAuthorizationWithDivoLink` (overlay удержан в headless).
    @MainActor
    private static func startTeamgramForExisting(phone: String?, on controller: DivoAuthWelcomeController?) {
        if let phone, !phone.isEmpty {
            DivoConfig.pendingSocialLinkPhone = phone
            controller?.onAuthenticateTeamgram?(phone)
            return
        }
        Task { @MainActor in
            do {
                let dummy = try await AuthRestService.shared.dummyPhone()
                DivoConfig.pendingSocialLinkPhone = dummy
                divoLog("social branch C: dummy_phone=\(dummy) → headless teamgram", level: .info)
                controller?.onAuthenticateTeamgram?(dummy)
            } catch {
                DivoConfig.pendingSocialExistingOnboarding = false
                DivoConfig.pendingSocialLinkPhone = nil
                divoLog("social branch C: dummy_phone failed: \(error)", level: .error)
                let message = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.authSignInFailed
                controller?.showError(message: message)
            }
        }
    }
}
