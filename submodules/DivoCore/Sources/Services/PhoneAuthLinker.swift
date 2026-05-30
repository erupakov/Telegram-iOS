import Foundation
import CryptoKit

// DIVO: мост «телефон → DIVO-аккаунт».
//
// Teamgram даёт вход по телефону (real, работает), но DIVO REST — email/social-centric:
// телефон НЕ является DIVO-идентичностью (`find-user`/`login` — по email). Поэтому после
// teamgram-логина заводим/находим DIVO-аккаунт по синтетическому email
// (= <цифры phone>@divo.global, контракт Alexandr) и ставим реальный accessToken вместо
// хардкод agencyToken — тогда профиль/лента/события сами перезагрузятся (tokenDidChangeNotification).
//
// telegram-link-мост «по номеру → токен» Eugene НЕ сделал, поэтому идём через registration/login —
// все эндпоинты уже есть. `registration` (НЕ registration-social) обходит вопрос providerId/uid.
//
//   login(email,pwd) → если «не найден» (404/401/422) → registration(role,email,pwd)
//     → DivoConfig.accessToken = real → (если есть telegramUserId) telegram-link → user/info → роль

public enum PhoneAuthLinkOutcome {
    case linked(divoUserId: Int, role: String?)
    case failed(Error)
}

public enum PhoneAuthLinker {
    /// Связать teamgram-вход по телефону с DIVO-аккаунтом. Ставит `DivoConfig.accessToken` и роль.
    /// - telegramUserId: если nil — `telegram-link` пропускается (добавим, когда протащим userId).
    /// - role: для `registration` нового юзера; существующему перетрётся из `user/info`.
    @discardableResult
    public static func linkAfterTeamgram(phone: String, telegramUserId: Int64?, role: String) async -> PhoneAuthLinkOutcome {
        let email = syntheticEmail(for: phone)
        let password = derivedPassword(for: phone)
        do {
            let token: AuthTokenWithUserData
            do {
                token = try await AuthRestService.shared.login(email: email, password: password)
                divoLog("phone-auth: login OK (существующий) divoUserId=\(token.user.id)", level: .info)
            } catch let DivoAPIError.httpError(statusCode, _) where statusCode == 404 || statusCode == 401 || statusCode == 422 {
                divoLog("phone-auth: login → не найден (\(statusCode)), регистрируем role=\(role)", level: .info)
                token = try await AuthRestService.shared.register(role: role, email: email, password: password)
                divoLog("phone-auth: registration OK divoUserId=\(token.user.id)", level: .info)
            }

            // Реальный токен вместо хардкод agencyToken → tokenDidChangeNotification → профиль перезагрузится.
            DivoConfig.accessToken = token.accessToken

            if let telegramUserId {
                do {
                    _ = try await AuthRestService.shared.telegramLink(telegramUserId: telegramUserId, phone: phone)
                    divoLog("phone-auth: telegram-link OK", level: .info)
                } catch {
                    divoLog("phone-auth: telegram-link failed (продолжаем): \(error)", level: .error)
                }
            } else {
                divoLog("phone-auth: telegram-link пропущен (нет telegramUserId — добавим в wiring)", level: .info)
            }

            // Реальная роль из профиля — вместо дебаг-флага.
            let info = try await AuthRestService.shared.userInfo()
            if let roleString = info.role, let parsed = DivoConfig.UserRole(rawValue: roleString) {
                DivoConfig.currentUserRole = parsed
            } else {
                divoLog("phone-auth: user/info role=\(info.role ?? "nil") не маппится в DivoConfig.UserRole — оставляем текущую", level: .info)
            }

            divoLog("phone-auth: DONE divoUserId=\(token.user.id) role=\(info.role ?? "nil")", level: .info)
            return .linked(divoUserId: token.user.id, role: info.role)
        } catch {
            divoLog("phone-auth FAILED: \(error)", level: .error)
            return .failed(error)
        }
    }

    /// Синтетический email из телефона — по контракту Alexandr: `<цифры>@divo.global`.
    public static func syntheticEmail(for phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        return "\(digits)@divo.global"
    }

    /// ВРЕМЕННЫЙ детерминированный пароль для синтетического email — чтобы reinstall мог `login`,
    /// а не падал на конфликте `registration`. TODO: убрать, когда бэк добавит нормальный phone-вход.
    public static func derivedPassword(for phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        let hash = SHA256.hash(data: Data("divo-stage-pw::\(digits)".utf8))
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        // Префикс гарантирует upper/lower/digit/special на случай правил сложности пароля.
        return "Dv9!" + hex.prefix(20)
    }
}
