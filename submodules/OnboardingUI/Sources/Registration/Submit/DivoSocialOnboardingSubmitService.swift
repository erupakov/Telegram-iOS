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
        let rawRole = state.selectedRoleId.flatMap { registry.definition(for: $0)?.backendRoleRaw } ?? "model"
        // Инвариант: `model` шлём ТОЛЬКО когда есть `agency_id` (бэк требует агентство для модели на
        // /user/update-profile). Онбординг агентство пока НЕ собирает → отправляем `new_face` (Model без
        // агентства = New Talent по квизу). Иначе update-profile даёт 422 по agency_id, имя/фото не лягут.
        // Когда добавим сбор агентства в model-путь (беклог Option B) — слать `model` + agency_id.
        let role = rawRole == "model" ? "new_face" : rawRole
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
                // Существующий-не-пройден (соц-C / phone-existing): аккаунт уже есть → МЕНЯЕМ только роль
                // (атомарно). Имя/фото/gender — структурным блоком ниже (per role, gender через словарь),
                // как у новых: иначе сырой gender-ключ ловил 422 и ронял всю цепочку в откат.
                divoLog("Onboarding submit: existing account — change-role (профиль структурным блоком)", level: .info)
                try await AuthRestService.shared.changeRole(role: role)
            }

            if let parsed = DivoConfig.UserRole(rawValue: role) {
                DivoConfig.currentUserRole = parsed
            }

            // Аккаунт создан → снимаем pending СРАЗУ: kill на дальнейших шагах не должен оставить флаг (иначе cold-start заново покажет онбординг и пере-регистрирует существующий аккаунт).
            DivoConfig.clearPendingOnboardingFlags()

            // Имя в teamgram (placeholder "User" → настоящее) — ФАТАЛЬНО и ДОЖИДАЕМСЯ
            // (часть атомарной цепочки: не прошло → throw → откат teamgram). Не best-effort.
            // Роли без firstName (компания/индустрия) — берём companyName/contactName, иначе teamgram-имя
            // осталось бы "User" навсегда (онбординг помечается пройденным → не переспросит).
            let teamgramFirstName = (firstName?.isEmpty == false ? firstName : nil)
                ?? formString("companyName", state: state, registry: registry)
                ?? formString("contactName", state: state, registry: registry)
            if let teamgramFirstName, !teamgramFirstName.isEmpty {
                try await DivoTeamgramSync.shared.updateName(firstName: teamgramFirstName, lastName: lastName ?? "")
                divoLog("Onboarding submit: teamgram name update OK", level: .info)
            }

            divoLog("Onboarding submit OK: role=\(role)", level: .info)
        } catch {
            // Цепочка не прошла целиком → откат (logout teamgram + welcome). Никакого частичного входа.
            divoLog("Onboarding submit FAILED (цепочка неполная) → откат: \(error)", level: .error)
            NotificationCenter.default.post(name: DivoConfig.onboardingChainFailedNotification, object: nil)
            throw error
        }

        // Структурный профиль DIVO (best-effort, как Android): ТЯНЕМ профиль с сервера (там после
        // регистрации уже есть agency.id) и обновляем ПРАВИЛЬНЫМ эндпоинтом per role. Делаем для ВСЕХ
        // путей (новый соц/phone И существующий-не-пройден соц-C) — у всех к этому моменту есть DIVO-сессия,
        // а бэк additionalInfo в структуру надёжно не мапит → имя/фото/gender(словарь) шлём явно. Фейл/422
        // вход НЕ роняет (вне атомарной цепочки).
        let shouldUpdateStructuredProfile = phone != nil || DivoConfig.currentDivoUserId != nil
        if shouldUpdateStructuredProfile {
            let fullName = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            let detail = try? await AuthRestService.shared.userDetail()
            let effectiveRole = detail?.role ?? role
            // ДИАГНОСТИКА (снять позже): реальная серверная роль vs отправленная — ловим случай, когда
            // бэк завёл talent'а как agency_employee (тогда профиль никуда не ложится). agencyId=nil = без агентства.
            divoLog("Onboarding submit: профиль per role — rawRole=\(rawRole) sentRole=\(role) serverRole=\(detail?.role ?? "nil") agencyId=\(detail?.agency?.id.map(String.init) ?? "nil")", level: .info)
            do {
                if effectiveRole == "agency_employee", let agencyId = detail?.agency?.id {
                    // Агентство СО своим agency.id: профиль через /agency/update (имя = title, фото = agency photo).
                    let title = formString("companyName", state: state, registry: registry)
                        ?? detail?.agency?.title
                        ?? (fullName.isEmpty ? nil : fullName)
                    let req = UpdateDescriptionAgencyRequest(
                        agencyId: agencyId,
                        title: title,
                        description: nil,
                        photo: photoUuid.map { UpdateDescriptionAgencyRequest.AvatarUuid(uuid: $0) }
                    )
                    try await AuthRestService.shared.updateAgency(req)
                    divoLog("Onboarding submit: agency profile OK (title/photo, agencyId=\(agencyId))", level: .info)
                } else {
                    // Модель/талант/fan И индивид-специалист (agency_employee БЕЗ своего agency.id):
                    // имя = fullName, фото = avatar через /user/update-profile. Раньше у индивид-специалиста
                    // профиль пропускался → имя/фото не подтягивались; теперь шлём best-effort.
                    // gender — маппим выбранный вариант на id из /dictionary/gender (бэк ждёт словарный id,
                    // не наш ключ → иначе 422); нет совпадения/словаря → эхо с сервера / не шлём.
                    let genderId = await mappedGenderId(state: state, registry: registry) ?? detail?.gender?.id
                    // geoCityId шлём явно (как имя/фото/gender) — additionalInfo бэк в структуру надёжно не мапит.
                    let geoCityId = formString("city", state: state, registry: registry).flatMap { Int($0) }
                    let req = UpdateBiographyPageRequest(
                        fullName: fullName.isEmpty ? nil : fullName,
                        gender: genderId,
                        geoCityId: geoCityId,
                        birthday: formDate("dateOfBirth", state: state, registry: registry) ?? detail?.birthday,
                        avatar: photoUuid.map { UpdateBiographyPageRequest.AvatarUuid(uuid: $0) }
                    )
                    try await AuthRestService.shared.updateProfile(req)
                    divoLog("Onboarding submit: updateProfile OK (имя/фото, genderId=\(genderId ?? "nil"))", level: .info)
                }
            } catch {
                divoLog("Onboarding submit: profile update FAILED (best-effort): \(error)", level: .error)
            }
        }

        // telegram-link (phone-флоу) — ВНЕ атомарной цепочки, BEST-EFFORT: бэк ставит структурное
        // user.phone (его читают DIVO-настройки) + сшивает DIVO↔teamgram. НЕ блокирует вход и НЕ
        // откатывает — DIVO-аккаунт уже создан (откат был бы иллюзорным, на бэке он не удаляется).
        // Фейл → оп в очередь ретраев (.telegramLink), дренится на старте.
        if let phone, let divoUserId = DivoConfig.currentDivoUserId {
            await Self.linkTelegramBestEffort(phone: phone, divoUserId: divoUserId)
        }

        // Профиль (имя/фото/роль) полностью записан → просим экраны перечитать /user/info. Без этого
        // DIVO-настройки кешируют профиль, загруженный по раннему tokenDidChange (ДО updateProfile),
        // и имя/фото проявляются только после перезапуска приложения.
        NotificationCenter.default.post(name: DivoConfig.profileDidUpdateNotification, object: nil)
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

    /// Маппит выбранный gender-ключ онбординга (male/female/…) на id из `/dictionary/gender`: бэк ждёт
    /// словарный id, а наш ключ отвергает (422). Сопоставляем по локализованному заголовку (наш title ==
    /// title словаря, lowercased) — как EditProfile. Нет совпадения / словарь недоступен → nil (вызывающая
    /// сторона делает эхо с сервера или не шлёт — без регресса). Best-effort.
    private func mappedGenderId(state: OnboardingRegistrationState, registry: OnboardingRoleRegistry) async -> String? {
        guard let key = formString("gender", state: state, registry: registry),
              let dict = try? await AuthRestService.shared.genderDictionary() else { return nil }
        let title = OnboardingStrings.resolve("onboarding.form.gender.option.\(key)").lowercased()
        return dict.first(where: { $0.title.lowercased() == title })?.id
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
