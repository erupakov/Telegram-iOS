import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import DivoCore
import OnboardingUI

// DIVO: пост-авторизационная интеграция очереди отложенных операций.
// Онбординг сам вшит в auth-флоу пушем (см. AuthorizationSequenceController+DivoOnboarding) —
// здесь его больше нет. Файл отдельный — минимизируем диф в гигантском AppDelegate.
extension AppDelegate {
    /// Перерегистрирует executor очереди отложенных операций с доступом к авторизованному
    /// teamgram-аккаунту: добавляет обработку `.nameUpdate` (имя после онбординга) поверх
    /// phone-link. registerExecutor сам дренит очередь — накопленные op'ы докатываются здесь.
    func divoRegisterPendingOpsExecutor(context: AuthorizedApplicationContext) {
        // Обновление teamgram-имени через авторизованный движок. Используется и очередью
        // (best-effort), и DivoTeamgramSync (await в атомарной submit-цепочке онбординга).
        let nameUpdate: (String, String) async throws -> Void = { [weak context] firstName, lastName in
            guard let context = context else { throw DivoTeamgramSync.SyncError.notReady }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let _ = context.context.engine.accountData.updateAccountPeerName(firstName: firstName, lastName: lastName).start(completed: {
                    continuation.resume(returning: ())
                })
            }
        }
        // DIVO: ВАЖЕН порядок — telegramUserId + nameUpdater ставим ДО registerExecutor, потому что он
        // СРАЗУ дренит очередь. Иначе отложенные .telegramLink/.nameUpdate падают opNotHandled и зависают
        // до следующего enqueue → на cold-start ретрай telegram-link (в т.ч. соц-ветка B) не докатывался.
        // telegram user id для telegram-link (структурный user.phone + сшивка DIVO↔teamgram); читается
        // на submit и в очереди ретраев (.telegramLink), см. DivoSocialOnboardingSubmitService.
        DivoTeamgramSync.shared.telegramUserId = context.context.account.peerId.id._internalGetInt64Value()
        // Атомарный name-update в submit-цепочке онбординга (await), см. DivoTeamgramSync.
        DivoTeamgramSync.shared.setNameUpdater(nameUpdate)
        PendingTelegramOpsQueue.shared.registerExecutor(DivoBootstrap.makeExecutor(nameUpdate: nameUpdate))
    }

    /// Cold-start resume прерванного онбординга. На холодном старте teamgram-сессия восстановлена → app
    /// строит authorized-контекст напрямую, минуя auth-флоу, поэтому незавершённый онбординг сам не
    /// покажется. Pending-флаги persist'ятся в UserDefaults — если прогон не завершён, показываем
    /// онбординг в его же submit-флоу ПОВЕРХ нативного window-root (НЕ Display-навигатора таббара —
    /// present на нём крэшит, см. reference_navigationcontroller_present_crash). Таббар построен под
    /// модалкой и скрыт; раскрывается только при успехе (dismiss). Отмена/фейл цепочки → logout teamgram.
    func divoResumeOnboardingOnColdStartIfNeeded(context: AuthorizedApplicationContext) {
        // Только настоящий cold-start. authContextValue == nil НЕ годится: при live-флоу с удержанным
        // overlay'ем authContextValue обнуляется (см. authContext-подписку), и хук мог бы показать ВТОРОЙ
        // онбординг поверх живого. Гейтим по in-memory флагу «auth-флоу был в этой сессии».
        guard !self.divoHadAuthContextThisLaunch else { return }
        let hasPending = DivoConfig.pendingSocialRegistration != nil
            || DivoConfig.pendingSocialExistingOnboarding
            || DivoConfig.pendingPhoneOnboarding
        guard hasPending else { return }
        // Защита от устаревшего флага: онбординг уже отмечен пройденным для этого юзера.
        if let userId = DivoConfig.currentDivoUserId, DivoConfig.isOnboardingCompleted(userId) { return }
        guard let host = self.window?.rootViewController, host.presentedViewController == nil else { return }

        divoLog("[Auth UI] cold-start: незавершённый онбординг → резюм поверх window-root", level: .info)

        var onboardingRef: UIViewController?
        var chainFailedObserver: NSObjectProtocol?
        let removeObserver = {
            if let observer = chainFailedObserver {
                NotificationCenter.default.removeObserver(observer)
                chainFailedObserver = nil
            }
        }
        // forceFresh: false — резюмим сохранённый прогресс (тот же экран, что бросил юзер).
        let onboarding = OnboardingRegistrationEntry.makeController(
            forceFresh: false,
            submitService: DivoOnboardingSubmitService(),
            onFinish: { [weak self] success in
                removeObserver()
                if success {
                    DivoConfig.clearPendingOnboardingFlags()
                    onboardingRef?.dismiss(animated: true)
                    divoLog("[Auth UI] cold-start онбординг завершён → таббар", level: .info)
                } else {
                    // Отмена крестиком → откат (logout teamgram → welcome).
                    self?.divoColdStartOnboardingLogout(context: context, onboarding: onboardingRef)
                }
            }
        )
        // Фейл submit-цепочки: сервис постит onboardingChainFailedNotification (onFinish не зовётся) →
        // по правилу атомарности откатываем teamgram + снимаем модалку.
        chainFailedObserver = NotificationCenter.default.addObserver(
            forName: DivoConfig.onboardingChainFailedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            removeObserver()
            divoLog("[Auth UI] cold-start онбординг-цепочка не прошла → logout teamgram", level: .error)
            self?.divoColdStartOnboardingLogout(context: context, onboarding: onboardingRef)
        }
        onboarding.modalPresentationStyle = .fullScreen
        onboardingRef = onboarding
        host.present(onboarding, animated: false)
    }

    /// Откат cold-start онбординга: чистим pending + сохранённый прогресс, снимаем модалку и логаутим
    /// teamgram → app вернётся в unauthorized-контекст (welcome). Зеркалит divoLogoutTeamgram из auth-флоу.
    private func divoColdStartOnboardingLogout(context: AuthorizedApplicationContext, onboarding: UIViewController?) {
        DivoConfig.resetDivoSessionForRollback() // токен + divoUserId + pending-флаги
        OnboardingProgressStore().clear()
        onboarding?.dismiss(animated: false)
        let _ = logoutFromAccount(
            id: context.context.account.id,
            accountManager: context.context.sharedContext.accountManager,
            alreadyLoggedOutRemotely: false
        ).start()
    }
}
