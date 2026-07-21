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
/// DIVO-аккаунт создан по REST, но authorized-контекст teamgram не поднялся (напр. недоступен teamgram /
/// нет VPN) → вход в таббар невозможен. Показываем ошибку + Retry на экране сабмита, а не молча выброс.
private struct OnboardingTeamgramUnreachableError: LocalizedError {
    var errorDescription: String? { DivoStrings.genericError }
}

public final class DivoOnboardingSubmitService: OnboardingSubmitService {

    public init() {}

    public func submit(state: OnboardingRegistrationState, registry: OnboardingRoleRegistry) async throws {
        let roleDef = state.selectedRoleId.flatMap { registry.definition(for: $0) }
        let rawRole = roleDef?.backendRoleRaw ?? "model"
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
                divoTrack(.signUpComplete(method: "social"))
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
                divoTrack(.signUpComplete(method: "phone"))
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

            // teamgram-имя вынесено в best-effort хвост (см. ниже): раньше фатальный await вешал весь
            // онбординг при флаки teamgram (пустой профиль + вечный спиннер). Атомарно теперь только
            // заведение DIVO-аккаунта — его фейл по-прежнему throw → откат.
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
            // ДИАГНОСТИКА (снять позже): реальная серверная роль vs отправленная — ловим случай, когда
            // бэк завёл talent'а как agency_employee (тогда профиль никуда не ложится). agencyId=nil = без агентства.
            divoLog("Onboarding submit: профиль per role — rawRole=\(rawRole) sentRole=\(role) serverRole=\(detail?.role ?? "nil") agencyId=\(detail?.agency?.id.map(String.init) ?? "nil")", level: .info)
            do {
                if role == "agency_employee" {
                    // Гейт по бэк-роли, а НЕ по категории онбординга: agency_employee — это companies,
                    // industry-pro и studio/location разом, и UI рендерит их всех как агентство (шапка/ава
                    // из agency.title/photo, Role(apiRole:) == .agency). Личный avatar через update-profile
                    // сервер для этой роли не сохраняет → имя+фото шлём в /agency/update (заводит черновик
                    // агентства). По agency.id гейтить нельзя — после регистрации он ещё nil (DIVI-84).
                    let title = formString("companyName", state: state, registry: registry)
                        ?? formString("studioName", state: state, registry: registry)
                        ?? detail?.agency?.title
                        ?? (fullName.isEmpty ? nil : fullName)
                    let site = formString("websiteUrl", state: state, registry: registry)
                    let cityId = formString("city", state: state, registry: registry).flatMap { Int($0) }
                    let req = UpdateDescriptionAgencyRequest(
                        agencyId: detail?.agency?.id,
                        title: title,
                        site: site,
                        description: nil,
                        photo: photoUuid.map { UpdateDescriptionAgencyRequest.AvatarUuid(uuid: $0) },
                        address: cityId.map { UpdateAgencyAddress(cityId: $0) }
                    )
                    try await AuthRestService.shared.updateAgency(req)
                    divoLog("Onboarding submit: agency create/update OK (agencyId=\(detail?.agency?.id.map(String.init) ?? "draft"), site=\(site ?? "nil"))", level: .info)
                } else {
                    // Модель/талант/fan/creative И индустрия-специалист (B, agency_employee без своего
                    // агентства): имя = fullName, фото = avatar через /user/update-profile. Индивид-специалист
                    // агентством не владеет → /agency/update ему не шлём (иначе завели бы лишнее агентство).
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

        // teamgram-имя и фото — best-effort в очередь: пробует сразу, при сбое докатывает на следующем
        // старте + reconcile при запуске. НЕ блокирует онбординг и не откатывает при флаки teamgram.
        // Роли без firstName (компания/индустрия) — companyName/contactName, иначе имя осталось бы "User".
        let teamgramFirstName = (firstName?.isEmpty == false ? firstName : nil)
            ?? formString("companyName", state: state, registry: registry)
            ?? formString("contactName", state: state, registry: registry)
        if let teamgramFirstName, !teamgramFirstName.isEmpty {
            DivoTeamgramName.syncToTeamgram(firstName: teamgramFirstName, lastName: lastName ?? "")
        }
        if photoUuid != nil {
            DivoTeamgramPhoto.syncToTeamgram()
        }

        // Гейт готовности ПЕРЕД таббаром: teamgram недоступен → контекст не поднят (telegramUserId nil),
        // раньше молча выбрасывало на авторизацию. Ждём ограниченно; не поднялся → ошибка + Retry
        // (аккаунт уже создан, повтор не пере-регистрирует).
        let gateTimeoutMs = 10_000, pollStepMs = 200
        var waitedMs = 0
        while DivoTeamgramSync.shared.telegramUserId == nil && waitedMs < gateTimeoutMs {
            try? await Task.sleep(nanoseconds: UInt64(pollStepMs) * 1_000_000)
            waitedMs += pollStepMs
        }
        if DivoTeamgramSync.shared.telegramUserId == nil {
            divoLog("Onboarding submit: teamgram-контекст не поднялся за \(gateTimeoutMs / 1000)с → ошибка + Retry", level: .error)
            throw OnboardingTeamgramUnreachableError()
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

    /// Маппит выбранный gender-ключ онбординга на id из `/dictionary/gender`: бэк ждёт словарный id,
    /// а наш ключ отвергает (422). Ключи мапим напрямую (preferNotToSay → "other"), id сверяем со
    /// словарём. Нет совпадения / словарь недоступен → nil (вызывающая сторона делает эхо с сервера
    /// или не шлёт — без регресса). Best-effort.
    private func mappedGenderId(state: OnboardingRegistrationState, registry: OnboardingRoleRegistry) async -> String? {
        guard let key = formString("gender", state: state, registry: registry) else { return nil }
        let mapped: String
        switch key {
        case "male": mapped = DivoGender.male
        case "female": mapped = DivoGender.female
        case "preferNotToSay": mapped = DivoGender.notSpecified
        default: return nil
        }
        guard let dict = try? await AuthRestService.shared.genderDictionary() else { return nil }
        return dict.contains(where: { $0.id == mapped }) ? mapped : nil
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
