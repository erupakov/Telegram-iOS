import Foundation
import Display
import DivoCore
import AccountContext
import AlertUI
import PresentationDataUtils

// DIVO: после успешного teamgram-входа по телефону СНАЧАЛА заводим/находим DIVO-аккаунт
// по этому телефону (PhoneAuthLinker) и ставим реальный accessToken, и ТОЛЬКО ПОТОМ завершаем
// авторизацию (переход в приложение).
//
// Почему именно в таком порядке: если завершить авторизацию первой, главный экран успевает
// подняться на хардкод-agency-токене, а реальный токен встаёт через ~секунды → летит
// tokenDidChangeNotification → resetNavigationOnTokenChange() (popToRoot) во время/после перехода
// → выкидывает на welcome. Делая линк ДО completion, токен готов до создания главного root'а —
// приложение сразу грузится под реальным аккаунтом, смены токена в главном экране нет.
//
// Если линк УПАЛ (нет сети / бэк лёг) — НЕ завершаем авторизацию молча: иначе accessToken-геттер
// отдаст хардкод agencyToken, и юзер тихо зайдёт под чужим тест-аккаунтом
// (feedback_no_silent_dictionary_fallbacks). Вместо этого держим лоадинг-экран и показываем
// алерт с «Повторить» — пускаем дальше только после реально успешного линка.
//
// Сейчас: роль нового юзера = текущая (default/debug) до role-picker; telegramUserId = nil
// (telegram-link пропускается) — протащим userId позже.
extension AuthorizationSequenceController {
    func divoCompleteAuthorizationWithDivoLink() {
        let complete = self.authorizationCompleted

        guard let phone = self.divoPendingPhone else {
            // Не phone-флоу (соц/прочее) — DIVO-токен уже выставлен своим путём, просто завершаем.
            complete()
            return
        }
        self.divoPendingPhone = nil

        let role = DivoConfig.currentUserRole.rawValue
        divoLog("[Auth UI] phone-link ДО завершения авторизации, phone=\(phone) role=\(role)", level: .info)

        self.divoRunPhoneLink(phone: phone, role: role, complete: complete)
    }

    /// Один прогон линка. На время работы остаётся показанный ранее лоадинг-экран
    /// (из divoHandleAutoSignUp). Успех → завершаем авторизацию; фейл → алерт с retry.
    private func divoRunPhoneLink(phone: String, role: String, complete: @escaping () -> Void) {
        Task { @MainActor in
            let outcome = await PhoneAuthLinker.linkAfterTeamgram(phone: phone, telegramUserId: nil, role: role)
            switch outcome {
            case let .linked(divoUserId, linkedRole):
                divoLog("[Auth UI] phone-link OK divoUserId=\(divoUserId) role=\(linkedRole ?? "nil") — завершаем авторизацию", level: .info)
                // Линк довёлся — снимаем cold-start страховку, если она была поставлена прошлым фейлом.
                PendingTelegramOpsQueue.shared.remove(.phoneLink(phone: phone))
                complete()
            case let .failed(error):
                divoLog("[Auth UI] phone-link FAILED — авторизацию НЕ завершаем, показываем retry: \(error)", level: .error)
                // Страховка на случай force-quit на алерте: на следующем старте линк допроведётся сам.
                PendingTelegramOpsQueue.shared.persist(.phoneLink(phone: phone))
                self.divoPresentPhoneLinkFailure(error: error, phone: phone, role: role, complete: complete)
            }
        }
    }

    private func divoPresentPhoneLinkFailure(error: Error, phone: String, role: String, complete: @escaping () -> Void) {
        let strings = self.presentationData.strings
        // Отдельный текст про сеть — самый частый кейс (кейс 7). Прочее (бэк 5xx/валидация) — generic.
        let text = isNetworkError(error) ? strings.Login_NetworkError : strings.Login_UnknownError

        self.currentWindow?.present(
            textAlertController(sharedContext: self.sharedContext, title: nil, text: text, actions: [
                TextAlertAction(type: .defaultAction, title: strings.ChatImportActivity_Retry, action: { [weak self] in
                    self?.divoRunPhoneLink(phone: phone, role: role, complete: complete)
                })
            ]),
            on: .root,
            blockInteraction: false,
            completion: {}
        )
    }
}
