import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import DivoCore

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
        PendingTelegramOpsQueue.shared.registerExecutor(DivoBootstrap.makeExecutor(nameUpdate: nameUpdate))
        // DIVO: атомарный name-update в submit-цепочке онбординга (await), см. DivoTeamgramSync.
        DivoTeamgramSync.shared.setNameUpdater(nameUpdate)
        // DIVO: telegram user id для telegram-link (структурный user.phone + сшивка DIVO↔teamgram).
        // Читается на submit и в очереди ретраев (.telegramLink), см. DivoSocialOnboardingSubmitService.
        DivoTeamgramSync.shared.telegramUserId = context.context.account.peerId.id._internalGetInt64Value()
    }
}
