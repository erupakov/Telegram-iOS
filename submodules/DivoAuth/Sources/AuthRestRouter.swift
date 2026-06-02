import Foundation
import DivoCore

public enum DivoAuthOutcome {
    /// Ветка A: аккаунт есть и связан — login-social OK, telegramLinked=true. teamgram signIn по user.phone → таббар.
    case divo2Reinstall(divoUserId: Int, phone: String?)
    /// Ветка B: аккаунт есть, teamgram не связан (login-social 200, telegramLinked=false) → signUp + telegram-link, без онбординга (вкл. DIVO-1 миграцию).
    case divo1Migration(divoUserId: Int, phone: String?)
    /// Ветка D: пользователя в DIVO нет — login-social 404/422. Онбординг + registration-social + teamgram signUp + telegram-link.
    case newUser(firebaseUid: String, providerId: String)
    case failed(Error)
}

public enum AuthRestRouter {
    public static func route(firebaseUid uid: String, providerId: String) async -> DivoAuthOutcome {
        do {
            let token = try await AuthRestService.shared.loginSocial(uid: uid, providerId: providerId)
            DivoConfig.accessToken = token.accessToken
            // telegramLinked может прийти вложенным (user.telegramLinked, по контракту) либо
            // top-level — читаем оба, чтобы ветка A не ломалась на неожиданной форме ответа.
            let telegramLinked = token.user.telegramLinked ?? token.telegramLinked ?? false
            divoLog(
                "login-social OK: divoUserId=\(token.user.id) telegramLinked=\(telegramLinked)",
                level: .info
            )

            // user/info (с ретраем) — нужны phone (headless teamgram) и роль.
            let info = try await AuthRestService.shared.userInfoWithRetry()
            divoLog(
                "user/info: phone=\(info.phone ?? "nil") role=\(info.role ?? "nil")",
                level: .info
            )

            // DIVO: роль — source of truth с СЕРВЕРА. Для существующих (login-social 200) пишем
            // currentUserRole из user/info.role; setter постит roleDidChangeNotification только на реальное
            // изменение (ModelsFeed и др. перерисуются). Новый юзер (ветка D, 404) роль выбирает в
            // онбординге — там и пишется. `customer` и неизвестные строки → nil → роль не трогаем.
            if let roleString = info.role, let parsed = DivoConfig.UserRole(rawValue: roleString) {
                DivoConfig.currentUserRole = parsed
                divoLog("login-social: currentUserRole ← server '\(roleString)'", level: .info)
            }

            // login-social 200 = аккаунт есть ⇒ онбординга нет: связан → таббар (A), не связан → link (B).
            if telegramLinked {
                divoLog("→ branch A (reinstall)", level: .info)
                return .divo2Reinstall(divoUserId: token.user.id, phone: info.phone)
            } else {
                divoLog("→ branch B (teamgram не связан → link)", level: .info)
                return .divo1Migration(divoUserId: token.user.id, phone: info.phone)
            }
        } catch let DivoAPIError.httpError(statusCode, _) where statusCode == 404 || statusCode == 422 {
            // 422 на НОВОМ Firebase-uid — штатный ответ бэка (by design, не баг): юзера ещё нет.
            // Трактуем как 404 → ветка D (новый). Без этого новые соц-юзеры падали в .failed.
            divoLog("login-social \(statusCode) → branch D (new user)", level: .info)
            return .newUser(firebaseUid: uid, providerId: providerId)
        } catch {
            DivoConfig.resetDivoSessionForRollback() // неполная DIVO-авторизация → чистим сессию (токен/роль), презентер покажет ошибку
            divoLog("login-social failed: \(error)", level: .error)
            return .failed(error)
        }
    }
}
