import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import DivoCore
import OnboardingUI

private enum DivoPhotoSyncError: Error {
    case uploadFailed
}

// DIVO: пост-авторизационная интеграция очереди отложенных операций.
// Онбординг сам вшит в auth-флоу пушем (см. AuthorizationSequenceController+DivoOnboarding) —
// здесь его больше нет. Файл отдельный — минимизируем диф в гигантском AppDelegate.
extension AppDelegate {
    /// Перерегистрирует executor очереди отложенных операций с доступом к авторизованному
    /// teamgram-аккаунту: добавляет обработку `.nameUpdate` (имя после онбординга) и `.photoUpdate`
    /// (ава) поверх phone-link. registerExecutor сам дренит очередь — накопленные op'ы докатываются
    /// здесь. В конце — reconcile авы: если teamgram-ава пуста, досылаем её из DIVO-профиля.
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
        // Заливка авы в teamgram (best-effort): байты из REST в mediaBox → uploadProfilePhoto.
        // resolveAvatarForSync вернул nil (авы нет) → op снимается без заливки.
        let photoUpdate: () async throws -> Void = { [weak context] in
            guard let context = context else { throw DivoTeamgramSync.SyncError.notReady }
            guard let data = try await DivoTeamgramPhoto.resolveAvatarForSync() else { return }
            let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
            context.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
            divoLog("[ava] заливаю аву в teamgram через uploadProfilePhoto…", level: .info)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // updateAccountPhoto эмитит .progress, затем .complete (либо ошибку) — резолвим один раз.
                var finished = false
                let finish: (Result<Void, Error>) -> Void = { result in
                    if finished { return }
                    finished = true
                    continuation.resume(with: result)
                }
                let _ = context.context.engine.accountData.updateAccountPhoto(
                    resource: resource,
                    videoResource: nil,
                    videoStartTimestamp: nil,
                    markup: nil,
                    mapResourceToAvatarSizes: { _, _ in .single([:]) }
                ).start(next: { status in
                    if case .complete = status { finish(.success(())) }
                }, error: { _ in
                    finish(.failure(DivoPhotoSyncError.uploadFailed))
                }, completed: {
                    finish(.failure(DivoPhotoSyncError.uploadFailed))
                })
            }
            divoLog("[ava] ава залита в teamgram", level: .info)
        }
        // DIVO: ВАЖЕН порядок — telegramUserId + nameUpdater ставим ДО registerExecutor, потому что он
        // СРАЗУ дренит очередь. Иначе отложенные .telegramLink/.nameUpdate падают opNotHandled и зависают
        // до следующего enqueue → на cold-start ретрай telegram-link (в т.ч. соц-ветка B) не докатывался.
        // telegram user id для telegram-link (структурный user.phone + сшивка DIVO↔teamgram); читается
        // на submit и в очереди ретраев (.telegramLink), см. DivoSocialOnboardingSubmitService.
        DivoTeamgramSync.shared.telegramUserId = context.context.account.peerId.id._internalGetInt64Value()
        // Атомарный name-update в submit-цепочке онбординга (await), см. DivoTeamgramSync.
        DivoTeamgramSync.shared.setNameUpdater(nameUpdate)
        PendingTelegramOpsQueue.shared.registerExecutor(DivoBootstrap.makeExecutor(nameUpdate: nameUpdate, photoUpdate: photoUpdate))

        // reconcile: если teamgram-ава пуста, досылаем из DIVO-профиля. Гейтим по isReady — иначе
        // self-peer ещё не загружен (getPeer = nil) и заливка тихо пропускается на старте (гонка).
        let _ = (context.isReady.get()
        |> filter { $0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak context] _ in
            guard let context = context else { return }
            let peerId = context.context.account.peerId
            let _ = (context.context.account.postbox.transaction { transaction -> Bool in
                if let user = transaction.getPeer(peerId) as? TelegramUser {
                    return user.photo.isEmpty
                }
                return false
            }).start(next: { isEmpty in
                divoLog("[ava] reconcile: teamgram-ава пустая=\(isEmpty)", level: .info)
                if isEmpty {
                    DivoTeamgramPhoto.syncToTeamgram()
                }
            })

            // reconcile имени: teamgram-имя вторично к DIVO (как ава) — если разошлись, досылаем DIVO-имя.
            let _ = (context.context.account.postbox.transaction { transaction -> (String, String) in
                if let user = transaction.getPeer(peerId) as? TelegramUser {
                    return (user.firstName ?? "", user.lastName ?? "")
                }
                return ("", "")
            }).start(next: { names in
                Task { await DivoTeamgramName.reconcileToTeamgram(teamgramFirstName: names.0, teamgramLastName: names.1) }
            })
        })
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
            || DivoConfig.pendingPhoneOnboarding
        guard hasPending else { return }
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
        // Соц-регистрация: префилл имени/фото из провайдера (для phone pendingSocialRegistration nil → nil).
        let socialPrefill = DivoConfig.pendingSocialRegistration.flatMap {
            OnboardingSocialPrefill(displayName: $0.displayName, photoUrl: $0.photoUrl)
        }
        // forceFresh: false — резюмим сохранённый прогресс (тот же экран, что бросил юзер).
        let onboarding = OnboardingRegistrationEntry.makeController(
            forceFresh: false,
            submitService: DivoOnboardingSubmitService(),
            prefill: socialPrefill,
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
