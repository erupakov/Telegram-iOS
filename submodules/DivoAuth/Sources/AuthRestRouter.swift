import Foundation
import DivoCore

public enum DivoAuthOutcome {
    /// Ветка A: DIVO 2 reinstall — login-social OK, telegramLinked=true. Дальше teamgram signIn по user.phone (шаг 5C).
    case divo2Reinstall(divoUserId: Int, phone: String?)
    /// Ветка B: DIVO 1 миграция — login-social OK, telegramLinked=false, isRegistrationFinished=true. Дальше teamgram signUp по user.phone + telegram-link (шаг 5C).
    case divo1Migration(divoUserId: Int, phone: String?)
    /// Ветка C: недозаведённый — login-social OK, telegramLinked=false, isRegistrationFinished=false. Дальше онбординг PROJ-004.
    case unfinishedRegistration(divoUserId: Int, phone: String?)
    /// Ветка D: новый юзер — login-social 404. Дальше онбординг + registration-social + teamgram signUp + telegram-link.
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

            // user/info с retry: транзиентный фейл не должен ронять уже успешный login-social в .failed.
            let info = try await userInfoWithRetry()
            divoLog(
                "user/info: phone=\(info.phone ?? "nil") isRegistrationFinished=\(info.isRegistrationFinished ?? false) role=\(info.role ?? "nil")",
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

            let isRegistrationFinished = info.isRegistrationFinished ?? false

            if telegramLinked {
                divoLog("→ branch A (DIVO 2 reinstall)", level: .info)
                return .divo2Reinstall(divoUserId: token.user.id, phone: info.phone)
            } else if isRegistrationFinished {
                divoLog("→ branch B (DIVO 1 migration)", level: .info)
                return .divo1Migration(divoUserId: token.user.id, phone: info.phone)
            } else {
                divoLog("→ branch C (unfinished registration)", level: .info)
                return .unfinishedRegistration(divoUserId: token.user.id, phone: info.phone)
            }
        } catch let DivoAPIError.httpError(statusCode, _) where statusCode == 404 || statusCode == 422 {
            // 422 на НОВОМ Firebase-uid — штатный ответ бэка (by design, не баг): юзера ещё нет.
            // Трактуем как 404 → ветка D (новый). Без этого новые соц-юзеры падали в .failed.
            divoLog("login-social \(statusCode) → branch D (new user)", level: .info)
            return .newUser(firebaseUid: uid, providerId: providerId)
        } catch {
            divoLog("login-social failed: \(error)", level: .error)
            return .failed(error)
        }
    }

    /// `user/info` с небольшим retry — транзиентный сетевой фейл не должен отменять
    /// уже успешный `login-social`. Возвращает данные либо пробрасывает последнюю ошибку.
    private static func userInfoWithRetry(attempts: Int = 3) async throws -> DivoUserInfoData {
        var lastError: Error?
        for attempt in 1...attempts {
            do {
                return try await AuthRestService.shared.userInfo()
            } catch {
                lastError = error
                divoLog("user/info attempt \(attempt)/\(attempts) failed: \(error)", level: .info)
                if attempt < attempts {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
        }
        throw lastError!
    }
}
