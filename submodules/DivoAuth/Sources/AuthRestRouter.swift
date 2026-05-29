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
            divoLog(
                "login-social OK: divoUserId=\(token.user.id) telegramLinked=\(token.user.telegramLinked ?? false)",
                level: .info
            )

            let info = try await AuthRestService.shared.userInfo()
            divoLog(
                "user/info: phone=\(info.phone ?? "nil") isRegistrationFinished=\(info.isRegistrationFinished ?? false) role=\(info.role ?? "nil")",
                level: .info
            )

            let telegramLinked = token.user.telegramLinked ?? false
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
        } catch let DivoAPIError.httpError(statusCode, _) where statusCode == 404 {
            divoLog("login-social 404 → branch D (new user)", level: .info)
            return .newUser(firebaseUid: uid, providerId: providerId)
        } catch {
            divoLog("login-social failed: \(error)", level: .error)
            return .failed(error)
        }
    }
}
