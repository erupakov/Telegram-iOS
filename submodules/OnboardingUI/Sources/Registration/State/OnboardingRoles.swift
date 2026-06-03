import Foundation

// MARK: - Стабильные перечисления (меняются редко)

/// Категория верхнего уровня — что юзер выбирает на самом первом экране онбординга.
/// По дизайну — 3 двери (`getHired` / `lookingForTalent` / `hereToFollow`).
/// По PDF v3.0 — 5 дверей; при смене схемы добавятся новые кейсы плюс правка
/// `OnboardingRegistrationStateMachine.nextStep` для `.topLevelChoice`.
public enum OnboardingTopLevelCategory: String, Codable, Hashable, CaseIterable {
    case getHired
    case lookingForTalent
    case hereToFollow
}

/// Внутренняя «дверь» внутри `lookingForTalent`: представляю компанию или я профессионал.
/// Если PDF приживётся, этот enum может вообще исчезнуть.
public enum OnboardingIndustryDoor: String, Codable, Hashable, CaseIterable {
    case representCompany
    case industryProfessional
}

/// Высокоуровневая категория роли. Меняется очень редко (5 крупных групп платформы).
public enum OnboardingRoleCategory: String, Codable, Hashable, CaseIterable {
    case companies
    case industryProfessionals
    case creativeProfessionals
    case talent
    case audience
}

/// Какой sub-role picker отображает данную роль как одну из опций.
/// Сейчас пикеров три (Talent + Creative объединены в один — дизайн);
/// при переходе на PDF добавится `creative` отдельным пикером, и роли C* переедут в него.
public enum OnboardingSubRolePicker: String, Codable, Hashable, CaseIterable {
    case talent
    case industryPro
    case companies
}

/// Что предшествует result-экрану роли. Используется state-машиной при back-навигации
/// с result-экрана: «куда возвращаться?». Не путать с `OnboardingSubRolePicker` —
/// тут указывается шаг, после которого СРАЗУ показывается result, без промежуточных.
public enum OnboardingDiscoverySource: String, Codable, Hashable, CaseIterable {
    /// Result показан сразу после top-level выбора (Fan: hereToFollow → result).
    case topLevel
    case talentSubRolePicker
    case industryProSubRolePicker
    case companiesSubRolePicker
    /// Model / New Talent — после Question 2 of 2 experience quiz.
    case experienceQuiz
}

// MARK: - Идентификаторы (RawRepresentable над String)

/// ID роли. Не enum, чтобы добавление/переименование роли не ломало код, который про неё ничего не знает.
/// Известные ID документированы константами ниже для удобства IDE.
public struct OnboardingRoleID: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

extension OnboardingRoleID {
    // A — Companies & Brands
    public static let modelingAgency      = OnboardingRoleID("A1")
    public static let fashionBrand        = OnboardingRoleID("A2")
    public static let brandOrBusiness     = OnboardingRoleID("A3")
    public static let beautyBrand         = OnboardingRoleID("A4")
    public static let eventAgency         = OnboardingRoleID("A5")
    public static let magazinePublication = OnboardingRoleID("A6")

    // B — Industry Professionals
    public static let scout            = OnboardingRoleID("B1")
    public static let booker           = OnboardingRoleID("B2")
    public static let castingDirector  = OnboardingRoleID("B3")
    public static let talentManager    = OnboardingRoleID("B4")

    // C — Creative Professionals
    public static let photographer     = OnboardingRoleID("C1")
    public static let stylist          = OnboardingRoleID("C2")
    public static let makeupArtist     = OnboardingRoleID("C3")
    public static let hairStylist      = OnboardingRoleID("C4")
    public static let videographer     = OnboardingRoleID("C5")
    public static let creativeDirector = OnboardingRoleID("C6")
    public static let fashionDesigner  = OnboardingRoleID("C7")
    public static let studioLocation   = OnboardingRoleID("C8")

    // D — Talent
    public static let model            = OnboardingRoleID("D1")
    public static let newTalent        = OnboardingRoleID("D2")
    public static let actor            = OnboardingRoleID("D3")
    public static let dancer           = OnboardingRoleID("D4")
    public static let singerPerformer  = OnboardingRoleID("D5")

    // E — Audience
    public static let fan              = OnboardingRoleID("E1")
}

/// ID формы Phase 4. Не enum — формы добавляются/убираются дёшево.
public struct OnboardingFormID: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

extension OnboardingFormID {
    public static let companiesAndBrands       = OnboardingFormID("4.A")
    public static let industryProfessionals    = OnboardingFormID("4.B")
    public static let creativeIndividual       = OnboardingFormID("4.C1")
    public static let creativeStudio           = OnboardingFormID("4.C2")
    public static let talentModel              = OnboardingFormID("4.D1")
    public static let talentNewTalent          = OnboardingFormID("4.D2")
    public static let talentActorDancerSinger  = OnboardingFormID("4.D3")
    public static let fan                      = OnboardingFormID("4.E")
}

/// ID result-экрана «YOU'RE A …». 9 уникальных экранов; группа ролей делит общий экран.
public struct OnboardingRoleResultID: RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

extension OnboardingRoleResultID {
    public static let modelVariant          = OnboardingRoleResultID("3.3.D.model")
    public static let newTalentVariant      = OnboardingRoleResultID("3.3.D.newTalent")
    public static let actor                 = OnboardingRoleResultID("3.3.D.actor")
    public static let dancer                = OnboardingRoleResultID("3.3.D.dancer")
    public static let singerPerformer       = OnboardingRoleResultID("3.3.D.singer")
    public static let creativeProfessional  = OnboardingRoleResultID("3.3.C")
    public static let companiesBrands       = OnboardingRoleResultID("3.3.A")
    public static let industryProfessional  = OnboardingRoleResultID("3.3.B")
    public static let fan                   = OnboardingRoleResultID("3.3.E")
}

// MARK: - Описание роли

/// Полное описание одной роли. Источник всей информации — массив таких структур
/// в `OnboardingRoleRegistry.defaultRoles`. State-машина и каталоги читают только отсюда.
///
/// Чтобы добавить новую роль — добавь сюда новую запись и (если нужен новый result-экран)
/// добавь его в `OnboardingResultCatalog`. Никакого кода в state-машине, контроллерах или
/// валидации трогать не надо.
public struct OnboardingRoleDefinition: Equatable {
    public let id: OnboardingRoleID
    public let category: OnboardingRoleCategory

    /// Локализационный ключ заголовка роли в саб-пикере (например, «MODEL», «PHOTOGRAPHER»).
    public let displayNameKey: String
    /// Опциональный подзаголовок под названием в саб-пикере («Model, performer, creative pro»).
    public let pickerSubtitleKey: String?
    /// Иконка в саб-пикере (SF Symbol name или ассет из DivoImage).
    public let pickerIconAssetName: String?

    /// В каком саб-пикере роль показывается как опция. `nil` — роль доступна сразу из top-level
    /// без пикера (Fan).
    public let presentedIn: OnboardingSubRolePicker?

    /// Локализационный ключ заголовка секции внутри саб-пикера, под которой отображается роль.
    /// `nil` — секционного заголовка нет (роль попадает в безымянную дефолтную секцию,
    /// все роли без `pickerSectionKey` группируются в одну).
    ///
    /// Talent picker по дизайну делится на две секции: «TALENTS» (model/actor/dancer/singer)
    /// и «CREATIVE» (photographer/.../studio). Остальные пикеры одна-секционные.
    public let pickerSectionKey: String?

    /// Что предшествует result-экрану этой роли при back-навигации.
    public let discoveredFrom: OnboardingDiscoverySource

    /// На какой result-экран ведёт выбор этой роли.
    public let resultId: OnboardingRoleResultID

    /// Какую форму Phase 4 эта роль открывает после result-экрана.
    public let formId: OnboardingFormID

    /// На какую бэковую роль маппится при submit. Сейчас бэк знает 4 роли —
    /// agency_employee / fan / model / new_face. Когда бэк расширится — поменяем значения.
    public let backendRoleRaw: String

    public init(
        id: OnboardingRoleID,
        category: OnboardingRoleCategory,
        displayNameKey: String,
        pickerSubtitleKey: String? = nil,
        pickerIconAssetName: String? = nil,
        presentedIn: OnboardingSubRolePicker?,
        pickerSectionKey: String? = nil,
        discoveredFrom: OnboardingDiscoverySource,
        resultId: OnboardingRoleResultID,
        formId: OnboardingFormID,
        backendRoleRaw: String
    ) {
        self.id = id
        self.category = category
        self.displayNameKey = displayNameKey
        self.pickerSubtitleKey = pickerSubtitleKey
        self.pickerIconAssetName = pickerIconAssetName
        self.presentedIn = presentedIn
        self.pickerSectionKey = pickerSectionKey
        self.discoveredFrom = discoveredFrom
        self.resultId = resultId
        self.formId = formId
        self.backendRoleRaw = backendRoleRaw
    }
}

// MARK: - Registry

/// Единая таблица ролей онбординга и операции над ней.
///
/// Регистри иммутабельный — создаётся один раз в `OnboardingCoordinator.make(...)` и пробрасывается
/// в state-машину, каталоги и контроллеры. Тесты могут конструировать собственный регистри с произвольным
/// набором ролей — это сделано осознанно, чтобы был возможен любой эксперимент с навигацией.
public final class OnboardingRoleRegistry {

    public let roles: [OnboardingRoleDefinition]
    private let byId: [OnboardingRoleID: OnboardingRoleDefinition]

    public init(roles: [OnboardingRoleDefinition]) {
        self.roles = roles
        var byId: [OnboardingRoleID: OnboardingRoleDefinition] = [:]
        for r in roles { byId[r.id] = r }
        self.byId = byId
    }

    public func definition(for id: OnboardingRoleID) -> OnboardingRoleDefinition? {
        return byId[id]
    }

    /// Все роли указанной категории, в порядке объявления.
    public func roles(in category: OnboardingRoleCategory) -> [OnboardingRoleDefinition] {
        return roles.filter { $0.category == category }
    }

    /// Все роли, отображаемые как опции в данном саб-пикере, в порядке объявления.
    /// Этим методом саб-пикеры в `OnboardingQuizCatalog` собирают свой список опций.
    public func roles(presentedIn picker: OnboardingSubRolePicker) -> [OnboardingRoleDefinition] {
        return roles.filter { $0.presentedIn == picker }
    }

    /// Default-регистри с 25 ролями v3.0. Хочешь поменять список ролей или их маппинги —
    /// правишь массив ниже.
    public static var `default`: OnboardingRoleRegistry {
        return OnboardingRoleRegistry(roles: defaultRoles)
    }
}

// MARK: - 25 ролей DIVO v3.0

extension OnboardingRoleRegistry {

    /// 25 ролей платформы DIVO по DIVO_Roles_v3_full.pdf, апрель 2026, отсортированы под порядок
    /// в Figma. Этот же порядок становится порядком отображения в саб-пикерах (`registry.roles(presentedIn:)`
    /// фильтрует, но порядка не меняет).
    ///
    /// `pickerSectionKey` группирует роли по секциям внутри одного пикера. В talent-пикере по дизайну
    /// две секции: «TALENTS» (D-роли) и «CREATIVE» (C-роли). В остальных пикерах — одна безымянная секция.
    /// Порядок секций в выдаче catalog-а — порядок первого появления секции в этом массиве.
    ///
    /// `discoveredFrom` отражает обратную навигацию с result-экрана — куда возвращаемся
    /// при нажатии «Choose a different role» или системного Back.
    public static let defaultRoles: [OnboardingRoleDefinition] = [

        // MARK: A — Companies & Brands → 3.3.A → 4.A
        OnboardingRoleDefinition(
            id: .modelingAgency, category: .companies,
            displayNameKey: "onboarding.role.modelingAgency.name",
            pickerSubtitleKey: "onboarding.role.modelingAgency.name.subtitle", pickerIconAssetName: "building.2",
            presentedIn: .companies, discoveredFrom: .companiesSubRolePicker,
            resultId: .companiesBrands, formId: .companiesAndBrands,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .fashionBrand, category: .companies,
            displayNameKey: "onboarding.role.fashionBrand.name",
            pickerSubtitleKey: "onboarding.role.fashionBrand.name.subtitle", pickerIconAssetName: "bag",
            presentedIn: .companies, discoveredFrom: .companiesSubRolePicker,
            resultId: .companiesBrands, formId: .companiesAndBrands,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .beautyBrand, category: .companies,
            displayNameKey: "onboarding.role.beautyBrand.name",
            pickerSubtitleKey: "onboarding.role.beautyBrand.name.subtitle", pickerIconAssetName: "sparkles",
            presentedIn: .companies, discoveredFrom: .companiesSubRolePicker,
            resultId: .companiesBrands, formId: .companiesAndBrands,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .brandOrBusiness, category: .companies,
            displayNameKey: "onboarding.role.brandOrBusiness.name",
            pickerSubtitleKey: "onboarding.role.brandOrBusiness.name.subtitle", pickerIconAssetName: "briefcase",
            presentedIn: .companies, discoveredFrom: .companiesSubRolePicker,
            resultId: .companiesBrands, formId: .companiesAndBrands,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .eventAgency, category: .companies,
            displayNameKey: "onboarding.role.eventAgency.name",
            pickerSubtitleKey: "onboarding.role.eventAgency.name.subtitle", pickerIconAssetName: "ticket",
            presentedIn: .companies, discoveredFrom: .companiesSubRolePicker,
            resultId: .companiesBrands, formId: .companiesAndBrands,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .magazinePublication, category: .companies,
            displayNameKey: "onboarding.role.magazinePublication.name",
            pickerSubtitleKey: "onboarding.role.magazinePublication.name.subtitle", pickerIconAssetName: "newspaper",
            presentedIn: .companies, discoveredFrom: .companiesSubRolePicker,
            resultId: .companiesBrands, formId: .companiesAndBrands,
            backendRoleRaw: "agency_employee"
        ),

        // MARK: B — Industry Professionals → 3.3.B → 4.B
        OnboardingRoleDefinition(
            id: .scout, category: .industryProfessionals,
            displayNameKey: "onboarding.role.scout.name",
            pickerSubtitleKey: "onboarding.role.scout.subtitle",
            pickerIconAssetName: "onboarding.quiz.topLevel.option.circle",
            presentedIn: .industryPro, discoveredFrom: .industryProSubRolePicker,
            resultId: .industryProfessional, formId: .industryProfessionals,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .booker, category: .industryProfessionals,
            displayNameKey: "onboarding.role.booker.name",
            pickerSubtitleKey: "onboarding.role.booker.subtitle",
            pickerIconAssetName: "onboarding.quiz.topLevel.option.circle",
            presentedIn: .industryPro, discoveredFrom: .industryProSubRolePicker,
            resultId: .industryProfessional, formId: .industryProfessionals,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .castingDirector, category: .industryProfessionals,
            displayNameKey: "onboarding.role.castingDirector.name",
            pickerSubtitleKey: "onboarding.role.castingDirector.subtitle",
            pickerIconAssetName: "onboarding.quiz.topLevel.option.circle",
            presentedIn: .industryPro, discoveredFrom: .industryProSubRolePicker,
            resultId: .industryProfessional, formId: .industryProfessionals,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .talentManager, category: .industryProfessionals,
            displayNameKey: "onboarding.role.talentManager.name",
            pickerSubtitleKey: "onboarding.role.talentManager.subtitle",
            pickerIconAssetName: "onboarding.quiz.topLevel.option.circle",
            presentedIn: .industryPro, discoveredFrom: .industryProSubRolePicker,
            resultId: .industryProfessional, formId: .industryProfessionals,
            backendRoleRaw: "agency_employee"
        ),

        // MARK: D — Talent → 3.3.D variants → 4.D1 / 4.D2 / 4.D3 (секция «TALENTS» в Talent picker)
        // D-блок объявлен перед C-блоком — это даёт нужный порядок секций в Talent picker'е.
        OnboardingRoleDefinition(
            id: .model, category: .talent,
            displayNameKey: "onboarding.role.model.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.model.name",
            // Model в пикере есть, но result показывается после experience quiz, не сразу — поэтому
            // discoveredFrom = experienceQuiz (back с result ведёт в квиз, а не в пикер).
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.talents",
            discoveredFrom: .experienceQuiz,
            resultId: .modelVariant, formId: .talentModel,
            backendRoleRaw: "model"
        ),
        OnboardingRoleDefinition(
            id: .newTalent, category: .talent,
            displayNameKey: "onboarding.role.newTalent.name",
            // Прямой опции в пикере нет — попадается через квиз «нет опыта»; presentedIn = nil.
            pickerSubtitleKey: nil, pickerIconAssetName: nil,
            presentedIn: nil,
            pickerSectionKey: nil,
            discoveredFrom: .experienceQuiz,
            resultId: .newTalentVariant, formId: .talentNewTalent,
            backendRoleRaw: "new_face"
        ),
        OnboardingRoleDefinition(
            id: .actor, category: .talent,
            displayNameKey: "onboarding.role.actor.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.actor.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.talents",
            discoveredFrom: .talentSubRolePicker,
            resultId: .actor, formId: .talentActorDancerSinger,
            // Talent (дверь 1) без агентства = New Talent → new_face. Model требует agency_id на
            // /user/update-profile (Model = «есть агентство»), у свежего таланта его нет → 422.
            backendRoleRaw: "new_face"
        ),
        OnboardingRoleDefinition(
            id: .dancer, category: .talent,
            displayNameKey: "onboarding.role.dancer.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.dancer.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.talents",
            discoveredFrom: .talentSubRolePicker,
            resultId: .dancer, formId: .talentActorDancerSinger,
            // Talent (дверь 1) без агентства = New Talent → new_face. Model требует agency_id на
            // /user/update-profile (Model = «есть агентство»), у свежего таланта его нет → 422.
            backendRoleRaw: "new_face"
        ),
        OnboardingRoleDefinition(
            id: .singerPerformer, category: .talent,
            displayNameKey: "onboarding.role.singerPerformer.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.singerPerformer.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.talents",
            discoveredFrom: .talentSubRolePicker,
            resultId: .singerPerformer, formId: .talentActorDancerSinger,
            // Talent (дверь 1) без агентства = New Talent → new_face. Model требует agency_id на
            // /user/update-profile (Model = «есть агентство»), у свежего таланта его нет → 422.
            backendRoleRaw: "new_face"
        ),

        // MARK: C — Creative Professionals → 3.3.C → 4.C1 (или 4.C2 для Studio) — секция «CREATIVE» в Talent picker
        OnboardingRoleDefinition(
            id: .photographer, category: .creativeProfessionals,
            displayNameKey: "onboarding.role.photographer.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.photographer.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.creative",
            discoveredFrom: .talentSubRolePicker,
            resultId: .creativeProfessional, formId: .creativeIndividual,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .stylist, category: .creativeProfessionals,
            displayNameKey: "onboarding.role.stylist.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.stylist.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.creative",
            discoveredFrom: .talentSubRolePicker,
            resultId: .creativeProfessional, formId: .creativeIndividual,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .makeupArtist, category: .creativeProfessionals,
            displayNameKey: "onboarding.role.makeupArtist.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.makeupArtist.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.creative",
            discoveredFrom: .talentSubRolePicker,
            resultId: .creativeProfessional, formId: .creativeIndividual,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .hairStylist, category: .creativeProfessionals,
            displayNameKey: "onboarding.role.hairStylist.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.hairStylist.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.creative",
            discoveredFrom: .talentSubRolePicker,
            resultId: .creativeProfessional, formId: .creativeIndividual,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .videographer, category: .creativeProfessionals,
            displayNameKey: "onboarding.role.videographer.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.videographer.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.creative",
            discoveredFrom: .talentSubRolePicker,
            resultId: .creativeProfessional, formId: .creativeIndividual,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .creativeDirector, category: .creativeProfessionals,
            displayNameKey: "onboarding.role.creativeDirector.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.creativeDirector.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.creative",
            discoveredFrom: .talentSubRolePicker,
            resultId: .creativeProfessional, formId: .creativeIndividual,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .fashionDesigner, category: .creativeProfessionals,
            displayNameKey: "onboarding.role.fashionDesigner.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.fashionDesigner.name",
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.creative",
            discoveredFrom: .talentSubRolePicker,
            resultId: .creativeProfessional, formId: .creativeIndividual,
            backendRoleRaw: "agency_employee"
        ),
        OnboardingRoleDefinition(
            id: .studioLocation, category: .creativeProfessionals,
            displayNameKey: "onboarding.role.studioLocation.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "onboarding.role.studioLocation.name",
            // Дизайнер подтвердил: Studio — 12-й (последний) пункт в Creative-секции Talent picker'а.
            // Иконка в Figma спрятана за кнопкой Continue, исправят в следующей итерации.
            presentedIn: .talent,
            pickerSectionKey: "onboarding.quiz.talentPicker.section.creative",
            discoveredFrom: .talentSubRolePicker,
            resultId: .creativeProfessional, formId: .creativeStudio,
            backendRoleRaw: "agency_employee"
        ),

        // MARK: E — Audience → 3.3.E → 4.E
        OnboardingRoleDefinition(
            id: .fan, category: .audience,
            displayNameKey: "onboarding.role.fan.name",
            pickerSubtitleKey: nil, pickerIconAssetName: "heart",
            // Fan не в пикере — попадается прямо из top-level (`hereToFollow`).
            presentedIn: nil, discoveredFrom: .topLevel,
            resultId: .fan, formId: .fan,
            backendRoleRaw: "fan"
        ),
    ]
}
