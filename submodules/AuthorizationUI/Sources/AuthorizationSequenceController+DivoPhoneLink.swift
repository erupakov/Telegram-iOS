import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import DivoCore
import AccountContext
import AlertUI
import PresentationDataUtils
import OnboardingUI

// DIVO: после teamgram-входа по телефону заводим/находим DIVO-аккаунт (PhoneAuthLinker) и ставим
// accessToken ДО завершения авторизации — иначе главный экран поднимется без DIVO-сессии и
// tokenDidChange/popToRoot выкинет на welcome.
//
// Правило отката (Marina): teamgram-логин прошёл, но ЛЮБОЙ следующий шаг цепочки упал →
// РАЗЛОГИН teamgram (→ welcome). Никакого частичного входа, никакого retry с сохранением teamgram.
extension AuthorizationSequenceController {
    func divoCompleteAuthorizationWithDivoLink() {
        let complete = self.authorizationCompleted

        // Соц-новый (D, DIVO-аккаунта нет → registration-social в submit) ИЛИ соц-существующий-не-пройден
        // (C, change-role+update-profile в submit) → онбординг в этом же auth-overlay (он удержан).
        if DivoConfig.pendingSocialRegistration != nil || DivoConfig.pendingSocialExistingOnboarding {
            self.divoPushOnboarding()
            return
        }

        guard let phone = self.divoPendingPhone else {
            // Не phone-флоу. Ветка B (соц-миграция, telegramLinked=false): сшиваем свежий teamgram с
            // DIVO-аккаунтом + синк имени, потом завершаем. Ветка A (уже связан) — просто завершаем.
            if let socPhone = DivoConfig.pendingSocialLinkPhone, let divoUserId = DivoConfig.currentDivoUserId {
                self.divoFinishSocialMigration(phone: socPhone, divoUserId: divoUserId, complete: complete)
            } else {
                complete()
            }
            return
        }
        self.divoPendingPhone = nil

        let role = DivoConfig.currentUserRole.rawValue
        divoLog("[Auth UI] phone-link ДО завершения авторизации, phone=\(phone) role=\(role)", level: .info)

        self.divoRunPhoneLink(phone: phone, role: role, complete: complete)
    }

    /// Линк DIVO-аккаунта. На время работы остаётся лоадинг-экран (из divoHandleAutoSignUp).
    /// Успех → завершаем авторизацию; фейл → разлогин teamgram (правило отката).
    private func divoRunPhoneLink(phone: String, role: String, complete: @escaping () -> Void) {
        Task { @MainActor in
            let outcome = await PhoneAuthLinker.linkAfterTeamgram(phone: phone, telegramUserId: nil, role: role)
            switch outcome {
            case .ready:
                // Существующий, онбординг пройден (токен уже выставлен) — завершаем, в таббар.
                divoLog("[Auth UI] phone-link: существующий + онбординг пройден — завершаем", level: .info)
                self.divoFinishWithoutOnboarding(complete: complete)
            case .onboarding:
                // Новый (регистрация на submit) ИЛИ существующий-не-пройден (update-profile) → онбординг.
                divoLog("[Auth UI] phone-link: → онбординг (регистрация/профиль на submit)", level: .info)
                self.divoPushOnboarding()
            case let .failed(error):
                // teamgram прошёл, но DIVO-детект (login) упал → разлогин teamgram (→ welcome).
                divoLog("[Auth UI] phone-link FAILED → разлогин teamgram + welcome: \(error)", level: .error)
                let message = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.onboardingChainFailed
                self.divoLogoutTeamgram(failureText: message)
            }
        }
    }

    /// Ветка B (соц-миграция, `telegramLinked=false`): teamgram уже вошёл, DIVO-токен выставлен
    /// login-social'ом. Best-effort: сшиваем teamgram↔DIVO (`telegram-link`) + подтягиваем имя из
    /// DIVO-профиля в teamgram (было placeholder "User"). Фейл НЕ блокирует вход (аккаунт уже доступен,
    /// telegram-link уходит в очередь ретраев). По завершении снимаем удержанный overlay → таббар.
    private func divoFinishSocialMigration(phone: String, divoUserId: Int, complete: @escaping () -> Void) {
        Task { @MainActor in
            if let telegramUserId = DivoTeamgramSync.shared.telegramUserId {
                do {
                    let linked = try await AuthRestService.shared.telegramLink(telegramUserId: telegramUserId, phone: phone, divoUserId: divoUserId)
                    DivoConfig.accessToken = linked.accessToken
                    divoLog("[Auth UI] social B: telegram-link OK → DIVO↔teamgram, новый токен", level: .info)
                } catch {
                    divoLog("[Auth UI] social B: telegram-link FAILED (best-effort) → очередь ретраев: \(error)", level: .error)
                    PendingTelegramOpsQueue.shared.enqueue(.telegramLink(phone: phone, divoUserId: divoUserId))
                }
            } else {
                divoLog("[Auth UI] social B: нет telegramUserId → telegram-link в очередь ретраев", level: .warning)
                PendingTelegramOpsQueue.shared.enqueue(.telegramLink(phone: phone, divoUserId: divoUserId))
            }

            // Имя из DIVO-профиля → teamgram (placeholder "User" → настоящее). Best-effort.
            if let detail = try? await AuthRestService.shared.userDetail(), let full = detail.fullName, !full.isEmpty {
                let parts = full.split(separator: " ", maxSplits: 1).map(String.init)
                try? await DivoTeamgramSync.shared.updateName(firstName: parts.first ?? full, lastName: parts.count > 1 ? parts[1] : "")
                divoLog("[Auth UI] social B: teamgram name синхронизировано из DIVO-профиля", level: .info)
            }

            DivoConfig.pendingSocialLinkPhone = nil
            self.divoHoldOverlayForOnboarding = false
            complete()
            self.dismiss()
        }
    }

    /// Разлогин teamgram-аккаунта (правило отката Marina): auth-state станет unauthorized → observer
    /// покажет welcome. Чистим pending-флаги онбординга + сохранённый прогресс + снимаем overlay.
    /// `failureText != nil` → показываем сообщение перед откатом (фейл, не молча). nil → молчаливая
    /// отмена (юзер сам). `internal` — зовётся также из +DivoOnboarding.
    func divoLogoutTeamgram(failureText: String? = nil) {
        DivoConfig.resetDivoSessionForRollback() // токен + divoUserId + все pending-флаги (см. DivoConfig)
        self.divoHoldOverlayForOnboarding = false
        self.divoClearOnboardingChainObserver()
        // Снимаем модалку онбординга, если открыта (отмена/фейл цепочки). На phone-link-fail
        // онбординга ещё нет — no-op. Через прямую ссылку: viewControllers.last?.presentedViewController
        // == nil (презентация переназначена на nav-контейнер), см. divoOnboardingController.
        self.divoOnboardingController?.dismiss(animated: false)
        // Чистим сохранённый прогресс онбординга — следующий вход (новый юзер) стартует с нуля.
        // (app-kill НЕ логаутит, поэтому resume на cold-start не страдает.)
        OnboardingProgressStore().clear()

        if let failureText {
            self.currentWindow?.present(
                textAlertController(sharedContext: self.sharedContext, title: nil, text: failureText, actions: [
                    TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})
                ]),
                on: .root, blockInteraction: false, completion: {}
            )
        }

        let _ = logoutFromAccount(
            id: self.account.id,
            accountManager: self.sharedContext.accountManager,
            alreadyLoggedOutRemotely: false
        ).start()
        // Снимаем удержанный overlay — логаут поднимет новый welcome-контекст.
        self.dismiss()
    }
}
