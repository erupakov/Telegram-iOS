import Foundation
import DivoCore

/// Реальный submit онбординга — АТОМАРНАЯ цепочка. Путь определяется по pending-флагам
/// (teamgram уже авторизован, DIVO-аккаунт заводится ИМЕННО здесь — «DIVO поздно»):
/// - соц-новый (`pendingSocialRegistration`) → `registration-social`(uid, providerId, role, additionalInfo);
/// - phone-новый (`pendingPhoneNumber`)      → `registration`(role, синт. email/пароль, additionalInfo);
/// - существующий-не-пройден (legacy)         → `change-role` + `update-profile`.
/// Роль и профиль НОВОГО юзера уходят в `additionalInfo` при регистрации — поэтому ни `change-role`,
/// ни `update-profile` для новых не нужны (и обходим 422-валидацию `update-profile`).
/// Затем для всех: teamgram name-update (ФАТАЛЬНО, ждём). Любой шаг упал → постим
/// `onboardingChainFailedNotification` + throw → откат (logout teamgram). Частичного входа нет.
public final class DivoOnboardingSubmitService: OnboardingSubmitService {

    public init() {}

    public func submit(state: OnboardingRegistrationState, registry: OnboardingRoleRegistry) async throws {
        let role = state.selectedRoleId.flatMap { registry.definition(for: $0)?.backendRoleRaw } ?? "model"
        let additionalInfo = DivoJSONValue.object(from: FormSerializer.payload(state: state, registry: registry))
        let firstName = formString("firstName", state: state, registry: registry)
        let lastName = formString("lastName", state: state, registry: registry)

        do {
            if let creds = DivoConfig.pendingSocialRegistration {
                // Соц-новый (ветка D): заводим DIVO-аккаунт. Роль + профиль — в additionalInfo.
                divoLog("Onboarding submit: registration-social role=\(role) uid=\(creds.uid)", level: .info)
                let token = try await AuthRestService.shared.registerSocial(
                    uid: creds.uid, providerId: creds.providerId, role: role, additionalInfo: additionalInfo
                )
                DivoConfig.accessToken = token.accessToken
                DivoConfig.currentDivoUserId = token.user.id
                divoLog("Onboarding submit: registration-social OK divoUserId=\(token.user.id)", level: .info)
            } else if let phone = DivoConfig.pendingPhoneNumber {
                // Phone-новый: заводим DIVO-аккаунт по синтетическому email/паролю. Роль + профиль — в additionalInfo.
                let email = PhoneAuthLinker.syntheticEmail(for: phone)
                let password = PhoneAuthLinker.derivedPassword(for: phone)
                divoLog("Onboarding submit: registration (phone) role=\(role)", level: .info)
                let token = try await AuthRestService.shared.register(
                    role: role, email: email, password: password, additionalInfo: additionalInfo
                )
                DivoConfig.accessToken = token.accessToken
                DivoConfig.currentDivoUserId = token.user.id
                divoLog("Onboarding submit: registration OK divoUserId=\(token.user.id)", level: .info)
            } else {
                // Существующий-не-пройден (legacy): аккаунт уже есть → дорабатываем роль/профиль.
                divoLog("Onboarding submit: existing account — change-role + update-profile", level: .info)
                try await AuthRestService.shared.changeRole(role: role)
                let fullName = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                let profile = UpdateBiographyPageRequest(
                    fullName: fullName.isEmpty ? "User" : fullName,
                    gender: formString("gender", state: state, registry: registry) ?? "male",
                    birthday: formDate("dateOfBirth", state: state, registry: registry) ?? "1990-01-01"
                )
                try await AuthRestService.shared.updateProfile(profile)
                divoLog("Onboarding submit: change-role + update-profile OK", level: .info)
            }

            if let parsed = DivoConfig.UserRole(rawValue: role) {
                DivoConfig.currentUserRole = parsed
            }

            // Имя в teamgram (placeholder "User" → настоящее) — ФАТАЛЬНО и ДОЖИДАЕМСЯ
            // (часть атомарной цепочки: не прошло → throw → откат teamgram). Не best-effort.
            if let firstName, !firstName.isEmpty {
                try await DivoTeamgramSync.shared.updateName(firstName: firstName, lastName: lastName ?? "")
                divoLog("Onboarding submit: teamgram name update OK", level: .info)
            }

            // Цепочка пройдена целиком → помечаем онбординг пройденным локально (бэк не ставит флаг),
            // чтобы повторный вход этим аккаунтом НЕ показывал онбординг снова.
            if let userId = DivoConfig.currentDivoUserId {
                DivoConfig.markOnboardingCompleted(userId)
            }

            divoLog("Onboarding submit OK: role=\(role)", level: .info)
        } catch {
            // Цепочка не прошла целиком → откат (logout teamgram + welcome). Никакого частичного входа.
            divoLog("Onboarding submit FAILED (цепочка неполная) → откат: \(error)", level: .error)
            NotificationCenter.default.post(name: DivoConfig.onboardingChainFailedNotification, object: nil)
            throw error
        }
    }

    private func formString(_ key: String, state: OnboardingRegistrationState, registry: OnboardingRoleRegistry) -> String? {
        guard let formId = state.selectedRoleId.flatMap({ registry.definition(for: $0)?.formId }) else { return nil }
        switch state.value(forForm: formId, fieldKey: key) {
        case let .string(value)?: return value
        case let .option(id)?: return id // picker/gender кладёт id выбранной опции
        default: return nil
        }
    }

    /// Дата из формы (.date) → "yyyy-MM-dd" для бэка (формат `date`).
    private func formDate(_ key: String, state: OnboardingRegistrationState, registry: OnboardingRoleRegistry) -> String? {
        guard let formId = state.selectedRoleId.flatMap({ registry.definition(for: $0)?.formId }),
              case let .date(date)? = state.value(forForm: formId, fieldKey: key) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
