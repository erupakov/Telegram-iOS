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
        let phone = DivoConfig.pendingPhoneNumber
        let email = phone.map { PhoneAuthLinker.syntheticEmail(for: $0) }
        let firstName = formString("firstName", state: state, registry: registry)
        let lastName = formString("lastName", state: state, registry: registry)

        // Фото грузим в storage ДО регистрации (Android шлёт photoUuid/photoUrl прямо в профиле).
        // Фейл аплоада — РЕТРАЕБЕЛЬНЫЙ и НЕ откатывает teamgram: throw здесь идёт мимо
        // onboardingChainFailedNotification (постится только в do/catch ниже), поэтому submit-экран
        // покажет снек ошибки + кнопку Retry (снек уже поднят над кнопкой, bottomInset+80), а по
        // Retry submit перезапустится и фото зальётся снова. Аккаунт не разлогинивается.
        var photoUuid: String?
        var photoUrl: String?
        if let photoPath = FormSerializer.photoAssetPath(state: state, registry: registry) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: photoPath))
                let resp: FileUploadResponse = try await DivoAPIClient.shared.upload(path: "/file/upload-file", fileData: data)
                photoUuid = resp.data?.uuid
                photoUrl = resp.data?.fullUrl
                divoLog("Onboarding submit: photo uploaded uuid=\(photoUuid ?? "nil")", level: .info)
            } catch {
                divoLog("Onboarding submit: photo upload FAILED (ретраебельно, без отката): \(error)", level: .error)
                throw error
            }
        }

        // Плоский профиль под контракт бэка (ключи как у Android) — все поля онбординга в additionalInfo.
        let profile = FormSerializer.registrationProfile(
            state: state, registry: registry, phone: phone, email: email,
            photoUuid: photoUuid, photoUrl: photoUrl
        )
        let additionalInfo = DivoJSONValue.object(from: profile)

        // Что уходит в профиль (ключи без значений — без PII): удобно сверять маппинг по ролям.
        divoLog("Onboarding submit: profile fields=[\(profile.keys.sorted().joined(separator: ","))]", level: .info)

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

        // updateProfile для НОВЫХ (soc/phone) — ВНЕ цепочки, BEST-EFFORT. Регистрация кладёт всё в
        // additionalInfo (opaque), а структурные fullName/avatar бэк из него НЕ заполняет → в DIVO-профиле
        // имя/фото не видны. Дотягиваем как Android. Фейл/422 (агентство) не роняет вход (профиль тогда
        // держится на фолбеке бэка из additionalInfo). Legacy-ветка свой updateProfile уже сделала выше.
        let isNewUserRegistration = DivoConfig.pendingSocialRegistration != nil || phone != nil
        if isNewUserRegistration {
            let fullName = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            if !fullName.isEmpty || photoUuid != nil {
                let bio = UpdateBiographyPageRequest(
                    fullName: fullName.isEmpty ? nil : fullName,
                    gender: formString("gender", state: state, registry: registry),
                    birthday: formDate("dateOfBirth", state: state, registry: registry),
                    avatar: photoUuid.map { UpdateBiographyPageRequest.AvatarUuid(uuid: $0) }
                )
                do {
                    try await AuthRestService.shared.updateProfile(bio)
                    divoLog("Onboarding submit: updateProfile OK (структурный профиль DIVO: имя/фото)", level: .info)
                } catch {
                    divoLog("Onboarding submit: updateProfile FAILED (best-effort, профиль из additionalInfo): \(error)", level: .error)
                }
            }
        }

        // telegram-link (phone-флоу) — ВНЕ атомарной цепочки, BEST-EFFORT: бэк ставит структурное
        // user.phone (его читают DIVO-настройки) + сшивает DIVO↔teamgram. НЕ блокирует вход и НЕ
        // откатывает — DIVO-аккаунт уже создан (откат был бы иллюзорным, на бэке он не удаляется).
        // Фейл → оп в очередь ретраев (.telegramLink), дренится на старте.
        if let phone, let divoUserId = DivoConfig.currentDivoUserId {
            await Self.linkTelegramBestEffort(phone: phone, divoUserId: divoUserId)
        }
    }

    /// telegram-link для phone-флоу. `telegramUserId` приходит из `DivoTeamgramSync` (ставит AppDelegate
    /// при поднятии authorized-контекста). Успех → новый токен; фейл/нет id → оп в очередь ретраев.
    private static func linkTelegramBestEffort(phone: String, divoUserId: Int) async {
        guard let telegramUserId = DivoTeamgramSync.shared.telegramUserId else {
            divoLog("Onboarding submit: telegram-link — нет telegramUserId → в очередь ретраев", level: .warning)
            PendingTelegramOpsQueue.shared.enqueue(.telegramLink(phone: phone, divoUserId: divoUserId))
            return
        }
        do {
            let linked = try await AuthRestService.shared.telegramLink(
                telegramUserId: telegramUserId, phone: phone, divoUserId: divoUserId
            )
            DivoConfig.accessToken = linked.accessToken
            divoLog("Onboarding submit: telegram-link OK → user.phone + DIVO↔teamgram, новый токен", level: .info)
        } catch {
            divoLog("Onboarding submit: telegram-link FAILED (best-effort) → в очередь ретраев: \(error)", level: .error)
            PendingTelegramOpsQueue.shared.enqueue(.telegramLink(phone: phone, divoUserId: divoUserId))
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
