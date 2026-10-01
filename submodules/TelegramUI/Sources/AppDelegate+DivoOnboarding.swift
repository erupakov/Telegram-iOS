import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import DivoCore
import OnboardingUI

// DIVI-109: удерживаем подписку на штатный foreground-сигнал — по нему очередь отложенных операций
// гейтит запись в Postbox по фону (фоновая SQLite-запись под suspend держит лок → 0xdead10cc).
private var divoPendingOpsForegroundDisposable: Disposable?

private enum DivoPhotoSyncError: Error {
    case uploadFailed
}

// AddContactError (TelegramCore) не конформит к Error — оборачиваем, чтобы бросить в continuation
// и оставить op на ретрай очередью.
private enum DivoAddContactError: Error {
    case failed
}

/// Удаляет ВСЕ фото профиля teamgram-аккаунта (история + текущая ава). Best-effort: ошибки глотаются
/// в TelegramCore (`removeAccountPhoto` — Signal<Void, NoError>), зависание режем таймаутом — иначе
/// op `.photoUpdate` навсегда застрял бы in-flight.
private func divoRemoveAllTeamgramPhotos(context: AccountContext) async {
    let engine = context.engine
    let photos: [TelegramPeerPhoto] = await withCheckedContinuation { continuation in
        var finished = false
        let _ = (engine.peers.requestPeerPhotos(peerId: context.account.peerId)
        |> take(1)
        |> timeout(15.0, queue: Queue.concurrentDefaultQueue(), alternate: .single([]))).start(next: { photos in
            if finished { return }
            finished = true
            continuation.resume(returning: photos)
        }, completed: {
            if finished { return }
            finished = true
            continuation.resume(returning: [])
        })
    }
    divoLog("[ava] reset: удаляю \(photos.count) старых teamgram-фото", level: .info)
    for photo in photos {
        guard let reference = photo.reference else { continue }
        await divoAwaitCompletion(engine.accountData.removeAccountPhoto(reference: reference))
    }
    // Текущая ава → пустая (на случай, если её не было в выдаче getUserPhotos).
    await divoAwaitCompletion(engine.accountData.removeAccountPhoto(reference: nil))
}

private func divoAwaitCompletion(_ signal: Signal<Void, NoError>) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        let _ = (signal
        |> timeout(15.0, queue: Queue.concurrentDefaultQueue(), alternate: .complete())).start(completed: {
            continuation.resume()
        })
    }
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
            // Осиротевший teamgram (phone-вход в существующий teamgram без DIVO-аккаунта): старые
            // ава/фото не должны перейти в новый профиль. Чистим ДО заливки новой авы — только при
            // DIVO-сессии (флаг ставится до регистрации, а сброс нужен уже под новым аккаунтом).
            if DivoConfig.pendingTeamgramProfileReset && DivoConfig.hasDivoSession {
                await divoRemoveAllTeamgramPhotos(context: context.context)
                DivoConfig.pendingTeamgramProfileReset = false
            }
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
        // DIVI-103: follow → контакт Telegram. По DIVO userId тянем /user/{id}, резолвим teamgram-пира
        // по telegramId (нет telegramId → штатно выходим, op снимается) и заводим контакт через движок.
        let addContact: (Int) async throws -> Void = { [weak context] divoUserId in
            guard let context = context else { throw DivoTeamgramSync.SyncError.notReady }
            let detail = try await AuthRestService.shared.userDetail(id: divoUserId)
            guard let telegramId = detail.telegramId else {
                divoLog("[contact] divoUserId=\(divoUserId) без telegramId — пропускаю", level: .info)
                return
            }
            // teamgram требует непустое имя контакта (пустое → CONTACT_NAME_EMPTY), поэтому заводим
            // с именем на момент follow (снапшот). Живое имя контакта на клиенте недостижимо.
            let (firstName, lastName) = DivoTeamgramName.split(fullName: detail.fullName ?? "")
            let engine = context.context.engine
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64(telegramId)))

            // teamgram-пир может быть не в Postbox → дорезолвим с сервера (access_hash 0 проходит).
            let resolved: EnginePeer? = try await withCheckedThrowingContinuation { continuation in
                var done = false
                let signal = engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
                    if let peer = peer { return .single(peer) }
                    return engine.peers.updatedRemotePeer(peer: .user(id: Int64(telegramId), accessHash: 0))
                    |> map { peer -> EnginePeer? in EnginePeer(peer) }
                    |> `catch` { _ -> Signal<EnginePeer?, NoError> in .single(nil) }
                }
                let _ = signal.start(next: { peer in
                    if done { return }
                    done = true
                    continuation.resume(returning: peer)
                })
            }
            guard resolved != nil else {
                // Пир не резолвится (нет сети / сервер) — оставляем op на ретрай.
                throw DivoTeamgramSync.SyncError.notReady
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var finished = false
                let _ = engine.contacts.addContactInteractively(
                    peerId: peerId,
                    firstName: firstName,
                    lastName: lastName,
                    // Номер не шлём: пир определяется по telegramId, а телефон из DIVO-профиля
                    // может быть реальным — подписка не должна раздавать чужой номер.
                    phoneNumber: "",
                    noteText: "",
                    noteEntities: [],
                    addToPrivacyExceptions: false
                ).start(error: { _ in
                    if finished { return }
                    finished = true
                    continuation.resume(throwing: DivoAddContactError.failed)
                }, completed: {
                    if finished { return }
                    finished = true
                    continuation.resume(returning: ())
                })
            }
            divoLog("[contact] заведён контакт telegramId=\(telegramId) для divoUserId=\(divoUserId)", level: .info)
        }
        // DIVO: ВАЖЕН порядок — telegramUserId + nameUpdater ставим ДО registerExecutor, потому что он
        // СРАЗУ дренит очередь. Иначе отложенные .telegramLink/.nameUpdate падают opNotHandled и зависают
        // до следующего enqueue → на cold-start ретрай telegram-link (в т.ч. соц-ветка B) не докатывался.
        // telegram user id для telegram-link (структурный user.phone + сшивка DIVO↔teamgram); читается
        // на submit и в очереди ретраев (.telegramLink), см. DivoSocialOnboardingSubmitService.
        DivoTeamgramSync.shared.telegramUserId = context.context.account.peerId.id._internalGetInt64Value()
        // Атомарный name-update в submit-цепочке онбординга (await), см. DivoTeamgramSync.
        DivoTeamgramSync.shared.setNameUpdater(nameUpdate)
        // Подпись teamgram для POST /auth/telegram-link: свежий help.getAppConfig (hash 0) этого аккаунта.
        DivoTeamgramSync.shared.setLinkProofProvider({ [weak context] in
            guard let context = context else { return nil }
            let proof: DivoLinkProof? = await withCheckedContinuation { continuation in
                var finished = false
                let _ = (context.context.engine.accountData.divoLinkProof()
                |> take(1)
                |> timeout(10.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))).start(next: { value in
                    if finished { return }
                    finished = true
                    continuation.resume(returning: value)
                }, completed: {
                    if finished { return }
                    finished = true
                    continuation.resume(returning: nil)
                })
            }
            return proof.map { DivoTeamgramSync.LinkProof(proof: $0.proof, phone: $0.phone) }
        })
        // DIVI-109: очередь пишет в Postbox только на переднем плане (фоновая SQLite-транзакция под
        // suspend держит лок в app-group контейнере → 0xdead10cc). applicationInForeground — тот же
        // сигнал, что гейтит стоковые транзакции; setForeground(true) сам докатит отложенное.
        divoPendingOpsForegroundDisposable?.dispose()
        divoPendingOpsForegroundDisposable = (context.context.sharedContext.applicationBindings.applicationInForeground
        |> deliverOnMainQueue).start(next: { inForeground in
            PendingTelegramOpsQueue.shared.setForeground(inForeground)
        })
        PendingTelegramOpsQueue.shared.registerExecutor(DivoBootstrap.makeExecutor(nameUpdate: nameUpdate, photoUpdate: photoUpdate, addContact: addContact))

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
                    // access_hash self-пира → в additionalInfo при регистрации (сшивка DIVO↔teamgram, как Android).
                    DivoTeamgramSync.shared.telegramAccessHash = user.accessHash?.value
                    // Номер self-пира (для соц-ветки D — dummy) → telegram-link на submit идёт с ним, а не с nil.
                    DivoTeamgramSync.shared.telegramSelfPhone = user.phone
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
