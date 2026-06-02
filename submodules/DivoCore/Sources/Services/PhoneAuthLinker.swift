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
    /// Существующий DIVO-аккаунт (login OK) → токен выставлен, сразу в таббар (существование = онбординг пройден).
    case ready
    /// Онбординга нет — DIVO-аккаунта нет (login 404); регистрация на submit (phone в `pendingPhoneNumber`).
    case onboarding
    case failed(Error)
}

public enum PhoneAuthLinker {
    /// ДЕТЕКТ DIVO-аккаунта после teamgram-входа по телефону. DIVO-запросы можно поздно, поэтому
    /// аккаунт НОВОГО юзера здесь НЕ заводим — регистрация уходит на submit онбординга (с реальной
    /// ролью + additionalInfo). Здесь только `login`, чтобы отличить существующего от нового.
    /// - Существующий (login OK) → ставим токен → `.ready` (аккаунт есть ⇒ онбординг пройден).
    /// - Новый (login 404/401/422) → НЕ регистрируем; запоминаем phone для submit → `.onboarding`.
    @discardableResult
    public static func linkAfterTeamgram(phone: String, telegramUserId: Int64?, role: String) async -> PhoneAuthLinkOutcome {
        let email = syntheticEmail(for: phone)
        let password = derivedPassword(for: phone)
        do {
            do {
                let token = try await AuthRestService.shared.login(email: email, password: password)
                // Существующий DIVO-2 (по синтетическому email) → ставим токен (главный экран увидит сессию).
                DivoConfig.accessToken = token.accessToken
                DivoConfig.currentDivoUserId = token.user.id
                divoLog("phone-auth: login OK (существующий DIVO-2) divoUserId=\(token.user.id)", level: .info)
                return await finishExisting(divoUserId: token.user.id)
            } catch let DivoAPIError.httpError(statusCode, _) where statusCode == 404 || statusCode == 401 || statusCode == 422 {
                // DIVO-2 по синт-email нет. DIVO-1 recovery: telegram-link by-phone (расширение Eugene) —
                // бэк ищет юзера по phone (divoId опущен), 404 если нет. Так подцепляем старый аккаунт,
                // который заведён на реальный email и синт-email-логином не находится.
                if let recovered = try await recoverByPhone(phone: phone, telegramUserId: telegramUserId) {
                    return recovered
                }
                // Ни по email, ни по phone — действительно новый. Аккаунт НЕ заводим: регистрация на
                // submit (реальная роль + additionalInfo). Токена пока нет — главный экран под онбордингом
                // грузит по fallback-токену, выкида нет.
                divoLog("phone-auth: не найден ни по email, ни по phone → новый, регистрация на submit", level: .info)
                DivoConfig.pendingPhoneNumber = phone
                DivoConfig.pendingPhoneOnboarding = true
                return .onboarding
            }
        } catch {
            divoLog("phone-auth FAILED (login): \(error)", level: .error)
            return .failed(error)
        }
    }

    /// DIVO-1 recovery через `telegram-link` by-phone (`divoId` опущен): 200 → юзер найден по номеру и
    /// связан с teamgram (токен выставлен) → решаем `.ready`/`.onboarding`; 404 → юзера по номеру нет
    /// (вернём nil → вызывающая сторона уходит в регистрацию). Прочие ошибки пробрасываем (→ `.failed`,
    /// чтобы не плодить дубль-аккаунт на транзиентном фейле). `telegramUserId` резолвим из
    /// `DivoTeamgramSync` (ставится при подъёме authorized-контекста) с коротким ретраем на гонку.
    private static func recoverByPhone(phone: String, telegramUserId passedId: Int64?) async throws -> PhoneAuthLinkOutcome? {
        guard let telegramUserId = await resolveTelegramUserId(passed: passedId) else {
            divoLog("phone-auth: recovery by-phone пропущен — нет telegramUserId", level: .warning)
            return nil
        }
        do {
            let linked = try await AuthRestService.shared.telegramLink(telegramUserId: telegramUserId, phone: phone, divoUserId: nil)
            DivoConfig.accessToken = linked.accessToken
            DivoConfig.currentDivoUserId = linked.user.id
            divoLog("phone-auth: telegram-link by-phone OK (recovery) divoUserId=\(linked.user.id)", level: .info)
            return await finishExisting(divoUserId: linked.user.id)
        } catch let DivoAPIError.httpError(statusCode, _) where statusCode == 404 {
            divoLog("phone-auth: telegram-link by-phone 404 — юзера по номеру нет", level: .info)
            return nil
        }
    }

    /// Существующий аккаунт (login/recovery) → таббар (в phone-флоу аккаунт заводится на submit, так что его существование = онбординг пройден).
    private static func finishExisting(divoUserId: Int) async -> PhoneAuthLinkOutcome {
        // Роль — часть DIVO-сессии: не дотянули user/info после ретраев → НЕ пускаем с дефолтной ролью, отдаём .failed (вызывающий разлогинит teamgram + покажет ошибку).
        let info: DivoUserInfoData
        do {
            info = try await AuthRestService.shared.userInfoWithRetry()
        } catch {
            divoLog("phone-auth: user/info не дотянулся после ретраев → .failed (разлогин)", level: .error)
            return .failed(error)
        }
        if let roleString = info.role, let parsed = DivoConfig.UserRole(rawValue: roleString) {
            DivoConfig.currentUserRole = parsed
        }
        DivoConfig.pendingPhoneOnboarding = false
        DivoConfig.pendingPhoneNumber = nil
        divoLog("phone-auth: existing DIVO-аккаунт (login OK, divoUserId=\(divoUserId)) → таббар", level: .info)
        return .ready
    }

    /// telegramUserId для telegram-link: переданный (если есть) либо из `DivoTeamgramSync` с коротким
    /// ретраем — флаг ставится при подъёме authorized-контекста и в момент детекта может ещё не успеть.
    private static func resolveTelegramUserId(passed: Int64?) async -> Int64? {
        if let passed { return passed }
        for _ in 0..<5 {
            if let id = DivoTeamgramSync.shared.telegramUserId { return id }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return DivoTeamgramSync.shared.telegramUserId
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
