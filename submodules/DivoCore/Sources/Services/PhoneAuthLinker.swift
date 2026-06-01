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
    /// Существующий DIVO-аккаунт, онбординг пройден → токен выставлен, идём сразу в таббар.
    case ready
    /// Онбординг нужен (новый ИЛИ существующий-не-пройден). Регистрация/доработка профиля —
    /// на submit онбординга (детали в `DivoConfig.pendingPhoneNumber`: non-nil = новый, регаемся;
    /// nil = аккаунт уже есть, update-profile).
    case onboarding
    case failed(Error)
}

public enum PhoneAuthLinker {
    /// ДЕТЕКТ DIVO-аккаунта после teamgram-входа по телефону. DIVO-запросы можно поздно, поэтому
    /// аккаунт НОВОГО юзера здесь НЕ заводим — регистрация уходит на submit онбординга (с реальной
    /// ролью + additionalInfo). Здесь только `login`, чтобы отличить существующего от нового.
    /// - Существующий (login OK) → ставим токен; если онбординг пройден → `.ready`, иначе `.onboarding`.
    /// - Новый (login 404/401/422) → НЕ регистрируем; запоминаем phone для submit → `.onboarding`.
    @discardableResult
    public static func linkAfterTeamgram(phone: String, telegramUserId: Int64?, role: String) async -> PhoneAuthLinkOutcome {
        let email = syntheticEmail(for: phone)
        let password = derivedPassword(for: phone)
        do {
            do {
                let token = try await AuthRestService.shared.login(email: email, password: password)
                // Существующий → ставим токен (главный экран увидит DIVO-сессию).
                DivoConfig.accessToken = token.accessToken
                DivoConfig.currentDivoUserId = token.user.id
                divoLog("phone-auth: login OK (существующий) divoUserId=\(token.user.id)", level: .info)

                let info = try await AuthRestService.shared.userInfo()
                if let roleString = info.role, let parsed = DivoConfig.UserRole(rawValue: roleString) {
                    DivoConfig.currentUserRole = parsed
                }

                if DivoConfig.isOnboardingCompleted(token.user.id) {
                    DivoConfig.pendingPhoneOnboarding = false
                    DivoConfig.pendingPhoneNumber = nil
                    divoLog("phone-auth: existing + onboardingDone → в таббар", level: .info)
                    return .ready
                } else {
                    // Аккаунт есть, но онбординг не пройден (legacy/orphaned) → онбординг доводит профиль
                    // через update-profile (регистрация не нужна — аккаунт уже есть).
                    DivoConfig.pendingPhoneNumber = nil
                    DivoConfig.pendingPhoneOnboarding = true
                    divoLog("phone-auth: existing, онбординг НЕ пройден → онбординг", level: .info)
                    return .onboarding
                }
            } catch let DivoAPIError.httpError(statusCode, _) where statusCode == 404 || statusCode == 401 || statusCode == 422 {
                // Новый: аккаунт НЕ заводим. Регистрация — на submit (реальная роль + additionalInfo).
                // Токена пока нет — главный экран под онбордингом грузит по fallback-токену, выкида нет.
                divoLog("phone-auth: login → не найден (\(statusCode)) → новый, регистрация на submit", level: .info)
                DivoConfig.pendingPhoneNumber = phone
                DivoConfig.pendingPhoneOnboarding = true
                return .onboarding
            }
        } catch {
            divoLog("phone-auth FAILED (login): \(error)", level: .error)
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
