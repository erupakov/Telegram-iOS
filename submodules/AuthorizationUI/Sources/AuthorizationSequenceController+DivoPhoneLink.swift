import Foundation
import DivoCore

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

        Task { @MainActor in
            // На время линка остаётся показанный ранее лоадинг-экран (из divoHandleAutoSignUp).
            await PhoneAuthLinker.linkAfterTeamgram(phone: phone, telegramUserId: nil, role: role)
            complete()
        }
    }
}
