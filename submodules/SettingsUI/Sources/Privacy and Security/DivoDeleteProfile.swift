import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import DivoCore
import DivoUIKit

// DIVO: удаление профиля (DIVO + teamgram). Пункт живёт в «Настройки → Конфиденциальность и безопасность»
// (раньше был в меню редактирования своего профиля). Файл отдельный — минимизируем диф в апстрим-контроллере.

/// Заголовок пункта (DivoStrings не импортим в апстрим-контроллер — меньше диф и риск коллизий имён).
func divoDeleteProfileTitle() -> String {
    return DivoStrings.deleteProfile
}

/// Подтверждение → удаление профиля. `hostController` — экран, поверх которого показываем алерт и
/// блокирующий лоадер (на время удаления юзер не должен уйти с экрана / тапать).
func divoPresentDeleteProfileConfirmation(context: AccountContext, hostController: UIViewController) {
    let alert = UIAlertController(
        title: DivoStrings.deleteProfile,
        message: DivoStrings.deleteProfileConfirmMessage,
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: DivoStrings.cancel, style: .cancel))
    alert.addAction(UIAlertAction(title: DivoStrings.delete, style: .destructive) { [weak hostController] _ in
        guard let hostController else { return }
        divoDeleteProfile(context: context, hostController: hostController)
    })
    hostController.present(alert, animated: true)
}

private func divoDeleteProfile(context: AccountContext, hostController: UIViewController) {
    // Лоадер — на view контроллера (в Display навбар — её сабвью, «назад» тоже перекрыт). Не на окно:
    // окно у приложения одно и переживает логаут — оверлей остался бы поверх экрана входа.
    let overlay = DivoLoadingOverlay()
    overlay.show(in: hostController.view, message: DivoStrings.deleting)
    Task { @MainActor in
        do {
            // Деструктивный эндпоинт: успех определяем по HTTP-статусу (2xx), тело не декодим —
            // на пустом/неожиданном ответе жёсткий decode упал бы уже ПОСЛЕ удаления аккаунта.
            _ = try await DivoAPIClient.shared.requestRawData(
                path: "/user/delete-account",
                method: "DELETE"
            )
        } catch {
            overlay.hide()
            let failed = UIAlertController(title: nil, message: DivoStrings.deleteProfileFailed, preferredStyle: .alert)
            failed.addAction(UIAlertAction(title: DivoStrings.ok, style: .default))
            hostController.present(failed, animated: true)
            return
        }

        // DIVO-аккаунт удалён. Бэк не каскадит на teamgram — сам удаляем и Telegram-аккаунт
        // (MTProto account.deleteAccount), иначе осиротевшая teamgram-учётка переживёт удаление.
        // Лоадер не прячем: logout уводит с экрана, оверлей уходит вместе с контроллером.
        let accountId = context.account.id
        let accountManager = context.sharedContext.accountManager
        // Полная чистка локальной DIVO-сессии (токен, роль, userId, pending-опы, teamgram-sync,
        // история поиска по лицу) + снятие записи аккаунта. alreadyLoggedOutRemotely=true — когда
        // Telegram-аккаунт реально удалён на сервере; false — fallback-разлогин, если не вышло.
        let finishLogout: (Bool) -> Void = { alreadyLoggedOutRemotely in
            DivoConfig.resetDivoSessionForRollback()
            // Future-auth-токены удалённого аккаунта переживают логаут (DIVI-87) — чистим, чтобы
            // следующий вход по этому номеру не делал fast-relogin в старую teamgram-учётку.
            let _ = (accountManager.transaction { transaction -> Void in
                transaction.setStoredLoginTokens([])
            }).startStandalone()
            let _ = logoutFromAccount(
                id: accountId,
                accountManager: accountManager,
                alreadyLoggedOutRemotely: alreadyLoggedOutRemotely
            ).start()
        }
        // Таймаут страхует от зависшего ответа teamgram — иначе блокирующий оверлей завис бы навсегда.
        // Один повтор: если teamgram-удаление не пройдёт, осиротевшая teamgram-учётка (старые
        // ава/имя/истории) подцепится при следующем входе по этому номеру.
        let deleteTeamgram = context.engine.auth.deleteAccount(reason: "DIVO", password: nil)
        |> timeout(15.0, queue: Queue.mainQueue(), alternate: .fail(.generic))
        let _ = (deleteTeamgram
        |> `catch` { error -> Signal<Never, DeleteAccountError> in
            if case .alreadyDeleted = error {
                return .fail(error)
            }
            divoLog("[DELETE ACCOUNT] MTProto account.deleteAccount: первая попытка не прошла — повтор", level: .warning)
            return deleteTeamgram
        }
        |> deliverOnMainQueue).start(error: { error in
            if case .alreadyDeleted = error {
                // 401: сессия уже отвязана — первый вызов на самом деле удалил аккаунт (ответ потерялся).
                divoLog("[DELETE ACCOUNT] MTProto: сессия уже отвязана (401) — аккаунт удалён")
                finishLogout(true)
                return
            }
            // teamgram не подтвердил удаление — DIVO уже удалён, юзера не бросаем: обычный разлогин.
            divoLog("[DELETE ACCOUNT] MTProto account.deleteAccount не подтверждён (ошибка/таймаут) — fallback-разлогин", level: .error)
            finishLogout(false)
        }, completed: {
            divoLog("[DELETE ACCOUNT] Telegram-аккаунт удалён через MTProto account.deleteAccount")
            finishLogout(true)
        })
    }
}
