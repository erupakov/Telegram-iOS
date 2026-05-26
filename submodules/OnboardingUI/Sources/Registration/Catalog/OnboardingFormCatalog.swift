import Foundation
import DivoUIKit

/// Каталог FormSchema для всех 8 форм Phase 4. Возвращает схему по `OnboardingFormID`
/// с учётом текущего state — это нужно для немногих state-зависимых полей (например,
/// список специализаций в 4.D3 зависит от выбранной роли: actor/dancer/singer).
///
/// Чтобы поменять состав поля одной формы — правишь соответствующий `make…(state:)`.
/// Чтобы поменять состав форм целиком (например, объединить 4.D2 с 4.D1) — добавляешь/убираешь
/// case в `schema(for:state:)`. Контроллеры и валидация про это ничего не знают.
public struct OnboardingFormCatalog {

    private let registry: OnboardingRoleRegistry
    /// Список стран резолвится один раз при создании catalog'а — `CountryHelper.getAllCountries()`
    /// итерирует ~250 ISO-кодов с локализацией, повторять на каждую форму не имеет смысла.
    fileprivate let countryOptions: [FormPickerOption]

    public init(registry: OnboardingRoleRegistry) {
        self.registry = registry
        self.countryOptions = CountryHelper.getAllCountries().map {
            FormPickerOption(id: $0.id, titleKey: $0.title)
        }
    }

    // MARK: - Date of birth bounds

    /// Минимальный возраст для регистрации — 14 лет (зеркалит логику профиля).
    private static let minAgeYears: Int = 14
    /// Максимальный возраст для регистрации — 100 лет.
    private static let maxAgeYears: Int = 100

    /// Самая ранняя допустимая дата рождения (100 лет назад от сегодня).
    fileprivate var dateOfBirthMin: Date {
        return Calendar.current.date(byAdding: .year, value: -Self.maxAgeYears, to: Date()) ?? Date()
    }
    /// Самая поздняя допустимая дата рождения (14 лет назад от сегодня).
    fileprivate var dateOfBirthMax: Date {
        return Calendar.current.date(byAdding: .year, value: -Self.minAgeYears, to: Date()) ?? Date()
    }

    public func schema(for id: OnboardingFormID, state: OnboardingRegistrationState) -> FormSchema {
        switch id {
        case .companiesAndBrands:      return makeCompaniesAndBrands()
        case .industryProfessionals:   return makeIndustryProfessionals()
        case .creativeIndividual:      return makeCreativeIndividual()
        case .creativeStudio:          return makeCreativeStudio()
        case .talentModel:             return makeTalentModel()
        case .talentNewTalent:         return makeTalentNewTalent()
        case .talentActorDancerSinger: return makeTalentActorDancerSinger(state: state)
        case .fan:                     return makeFan()
        default:                       return makeEmptyPlaceholder(id: id)
        }
    }

    public func stepCount(for id: OnboardingFormID) -> Int {
        switch id {
        case .companiesAndBrands:      return 4
        case .industryProfessionals:   return 4
        case .creativeIndividual:      return 4
        case .creativeStudio:          return 3
        case .talentModel:             return 4
        case .talentNewTalent:         return 4
        case .talentActorDancerSinger: return 4
        case .fan:                     return 2
        default:                       return 1
        }
    }
}

// MARK: - Помощники

private extension OnboardingFormCatalog {

    func field(
        _ key: String,
        kind: FormFieldKind,
        title: String? = nil,
        placeholder: String? = nil,
        help: String? = nil,
        required: Bool = false
    ) -> FormField {
        return FormField(key: key, kind: kind, titleKey: title, placeholderKey: placeholder, helpTextKey: help, isRequired: required)
    }

    func progress(_ index: Int, of total: Int) -> String {
        return "onboarding.form.progress.\(index)of\(total)"
    }

    func makeEmptyPlaceholder(id: OnboardingFormID) -> FormSchema {
        return FormSchema(
            id: id, internalTitleKey: "onboarding.form.\(id.rawValue).title",
            steps: [
                FormStep(
                    titleKey: "onboarding.form.\(id.rawValue).step1.title",
                    fields: [],
                    primaryButtonKey: "onboarding.button.done"
                )
            ]
        )
    }
}

// MARK: - 4.A Companies & Brands (4 шага)

private extension OnboardingFormCatalog {

    func makeCompaniesAndBrands() -> FormSchema {
        // Список типов компаний строится из registry: один источник истины и для саб-пикера
        // Phase 3 (выбор «What best describes your company?»), и для поля Type на step 1 формы 4.A.
        let companyTypeOptions: [FormPickerOption] = registry.roles(in: .companies).map { def in
            FormPickerOption(id: def.id.rawValue, titleKey: def.displayNameKey)
        }
        return FormSchema(
            id: .companiesAndBrands,
            internalTitleKey: "onboarding.form.4A.title",
            steps: [
                FormStep(
                    titleKey: "onboarding.form.4A.step1.title",
                    stepProgressKey: progress(1, of: 4),
                    fields: [
                        field("companyName",
                              kind: .text(minLength: 1, maxLength: 120),
                              placeholder: "onboarding.form.4A.companyName.placeholder",
                              required: true),
                        field("companyType",
                              kind: .picker(options: companyTypeOptions),
                              title: "onboarding.form.4A.companyType.title",
                              placeholder: "onboarding.form.4A.companyType.placeholder",
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                FormStep(
                    titleKey: "onboarding.form.4A.step2.title",
                    stepProgressKey: progress(2, of: 4),
                    fields: [
                        field("country", 
                              kind: .country(options: countryOptions), 
                              title: "onboarding.form.field.country.title", 
                              placeholder: "onboarding.form.field.country.placeholder", 
                              required: true),
                        field("city",    
                              kind: .city,                                                                           
                              placeholder: "onboarding.form.field.city.placeholder",    
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                FormStep(
                    titleKey: "onboarding.form.4A.step3.title",
                    stepProgressKey: progress(3, of: 4),
                    fields: [
                        field("websiteUrl",
                              kind: .url(scheme: .anyHttp),
                              placeholder: "onboarding.form.4A.websiteUrl.placeholder",
                              help: "onboarding.form.4A.websiteUrl.help",
                              required: true),
                        field("contactFirstName",
                              kind: .text(minLength: 1, maxLength: 60),
                              placeholder: "onboarding.form.4A.contactFirstName.placeholder",
                              required: true),
                        field("contactLastName",
                              kind: .text(minLength: 1, maxLength: 60),
                              placeholder: "onboarding.form.4A.contactLastName.placeholder",
                              required: true),
                        field("contactRole",
                              kind: .text(minLength: 1, maxLength: 60),
                              placeholder: "onboarding.form.4A.contactRole.placeholder"),
                    ],
                    primaryButtonKey: "onboarding.button.continue",
                    groupedRendering: true
                ),
                FormStep(
                    titleKey: "onboarding.form.4A.step4.title",
                    stepProgressKey: progress(4, of: 4),
                    fields: [
                        field("logo",
                              kind: .photo(aspect: .square),
                              placeholder: "onboarding.form.field.logoPhoto.placeholder",
                              help: "onboarding.form.field.logoPhoto.help",
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.done"
                ),
            ]
        )
    }
}

// MARK: - 4.B Industry Professionals (4 шага)

private extension OnboardingFormCatalog {

    func makeIndustryProfessionals() -> FormSchema {
        // Список ролей строится из registry — добавится новый Industry Pro в registry,
        // он автоматически появится и в саб-пикере, и в поле Role на step 1 формы 4.B.
        let roleOptions: [FormPickerOption] = registry.roles(in: .industryProfessionals).map { def in
            FormPickerOption(id: def.id.rawValue, titleKey: def.displayNameKey)
        }
        return FormSchema(
            id: .industryProfessionals,
            internalTitleKey: "onboarding.form.4B.title",
            steps: [
                FormStep(
                    titleKey: "onboarding.form.4B.step1.title",
                    stepProgressKey: progress(1, of: 4),
                    fields: [
                        field("firstName", kind: .text(minLength: 1, maxLength: 60), placeholder: "onboarding.form.field.firstName.placeholder", required: true),
                        field("lastName",  kind: .text(minLength: 1, maxLength: 60), placeholder: "onboarding.form.field.lastName.placeholder",  required: true),
                        field("role",      
                              kind: .picker(options: roleOptions),  
                              title: "onboarding.form.4B.role.title",     
                              placeholder: "onboarding.form.4B.role.placeholder",         
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                personalDetailsStep(progressKey: progress(2, of: 4), includeCity: true),
                FormStep(
                    titleKey: "onboarding.form.4B.step3.title",
                    stepProgressKey: progress(3, of: 4),
                    fields: [
                        field("agency",
                              kind: .text(minLength: 1, maxLength: 120),
                              placeholder: "onboarding.form.4B.agency.placeholder",
                              help: "onboarding.form.4B.agency.help"),
                        field("instagramOrPortfolio",
                              kind: .url(scheme: .instagram),
                              placeholder: "onboarding.form.field.instagramOrPortfolio.placeholder"),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                profilePhotoStep(progressKey: progress(4, of: 4), buttonKey: "onboarding.button.done"),
            ]
        )
    }
}

// MARK: - 4.C1 Creative Individual (4 шага)

private extension OnboardingFormCatalog {

    func makeCreativeIndividual() -> FormSchema {
        // Список специализаций — все Creative-роли из registry КРОМЕ Studio (у неё своя форма 4.C2).
        // Добавится новый Creative-специалист (например, Set Designer) — автоматически появится здесь.
        let specialisationOptions: [FormPickerOption] = registry.roles(in: .creativeProfessionals)
            .filter { $0.id != .studioLocation }
            .map { def in
                FormPickerOption(id: def.id.rawValue, titleKey: def.displayNameKey)
            }
        return FormSchema(
            id: .creativeIndividual,
            internalTitleKey: "onboarding.form.4C1.title",
            steps: [
                FormStep(
                    titleKey: "onboarding.form.4C1.step1.title",
                    stepProgressKey: progress(1, of: 4),
                    fields: [
                        field("firstName",      kind: .text(minLength: 1, maxLength: 60), placeholder: "onboarding.form.field.firstName.placeholder", required: true),
                        field("lastName",       kind: .text(minLength: 1, maxLength: 60), placeholder: "onboarding.form.field.lastName.placeholder",  required: true),
                        field("specialisation", 
                              kind: .picker(options: specialisationOptions), 
                              title: "onboarding.form.4C1.specialisation.title", 
                              placeholder: "onboarding.form.4C1.specialisation.placeholder", 
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                personalDetailsStep(progressKey: progress(2, of: 4), includeCity: true),
                FormStep(
                    titleKey: "onboarding.form.4C1.step3.title",
                    subtitleKey: "onboarding.form.4C1.step3.subtitle",
                    stepProgressKey: progress(3, of: 4),
                    fields: [
                        field("instagramOrPortfolio",
                              kind: .url(scheme: .instagram),
                              placeholder: "onboarding.form.field.instagramOrPortfolio.placeholder",
                              help: "onboarding.form.4C1.portfolio.help"),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                profilePhotoStep(progressKey: progress(4, of: 4), buttonKey: "onboarding.button.done"),
            ]
        )
    }
}

// MARK: - 4.C2 Creative Studio (3 шага)

private extension OnboardingFormCatalog {

    func makeCreativeStudio() -> FormSchema {
        return FormSchema(
            id: .creativeStudio,
            internalTitleKey: "onboarding.form.4C2.title",
            steps: [
                FormStep(
                    titleKey: "onboarding.form.4C2.step1.title",
                    stepProgressKey: progress(1, of: 3),
                    fields: [
                        field("studioName",
                              kind: .text(minLength: 1, maxLength: 120),
                              placeholder: "onboarding.form.4C2.studioName.placeholder",
                              required: true),
                        field("country", 
                              kind: .country(options: countryOptions),
                              title: "onboarding.form.field.country.title", 
                              placeholder: "onboarding.form.field.country.placeholder", 
                              required: true),
                        field("city",    
                              kind: .city,    
                              placeholder: "onboarding.form.field.city.placeholder",    
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                FormStep(
                    titleKey: "onboarding.form.4C2.step2.title",
                    stepProgressKey: progress(2, of: 3),
                    fields: [
                        field("websiteOrInstagram",
                              kind: .url(scheme: .anyLink),
                              placeholder: "onboarding.form.4C2.websiteOrInstagram.placeholder",
                              help: "onboarding.form.4C2.websiteOrInstagram.help"),
                        field("contactName",
                              kind: .text(minLength: 1, maxLength: 80),
                              placeholder: "onboarding.form.4C2.contactName.placeholder",
                              help: "onboarding.form.4C2.contactName.help"),
                        field("contactPhoneOrEmail",
                              kind: .text(minLength: 1, maxLength: 120),
                              placeholder: "onboarding.form.4C2.contactPhoneOrEmail.placeholder",
                              help: "onboarding.form.4C2.contactPhoneOrEmail.help"),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                FormStep(
                    titleKey: "onboarding.form.4C2.step3.title",
                    subtitleKey: "onboarding.form.4C2.step3.subtitle",
                    stepProgressKey: progress(3, of: 3),
                    fields: [
                        field("mainSpacePhoto",
                              kind: .photo(aspect: .landscape),
                              placeholder: "onboarding.form.field.logoPhoto.placeholder",
                              help: "onboarding.form.field.logoPhoto.help",
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.done"
                ),
            ]
        )
    }
}

// MARK: - 4.D1 Model (4 шага)

private extension OnboardingFormCatalog {

    func makeTalentModel() -> FormSchema {
        return FormSchema(
            id: .talentModel,
            internalTitleKey: "onboarding.form.4D1.title",
            steps: [
                identityStep(progressKey: progress(1, of: 4)),
                locationStep(progressKey: progress(2, of: 4), titleKey: "onboarding.form.section.location.title"),
                FormStep(
                    titleKey: "onboarding.form.4D1.step3.title",
                    stepProgressKey: progress(3, of: 4),
                    fields: [
                        field("currentAgency",
                              kind: .text(minLength: 0, maxLength: 120),
                              placeholder: "onboarding.form.4D1.currentAgency.placeholder",
                              help: "onboarding.form.4D1.currentAgency.help"),
                        field("instagramHandle",
                              kind: .url(scheme: .instagram),
                              placeholder: "onboarding.form.field.instagramHandle.placeholder",
                              help: "onboarding.form.field.instagramHandle.help"),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                FormStep(
                    titleKey: "onboarding.form.4D1.step4.title",
                    subtitleKey: "onboarding.form.4D1.step4.subtitle",
                    stepProgressKey: progress(4, of: 4),
                    fields: [
                        field("profilePhoto",
                              kind: .photo(aspect: .portrait),
                              placeholder: "onboarding.form.field.profilePhoto.placeholder",
                              help: "onboarding.form.field.profilePhoto.help",
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.done"
                ),
            ]
        )
    }
}

// MARK: - 4.D2 New Talent (4 шага, последний step с TFP-блоком)

private extension OnboardingFormCatalog {

    func makeTalentNewTalent() -> FormSchema {
        return FormSchema(
            id: .talentNewTalent,
            internalTitleKey: "onboarding.form.4D2.title",
            steps: [
                identityStep(progressKey: progress(1, of: 4)),
                locationStep(progressKey: progress(2, of: 4), titleKey: "onboarding.form.section.location.title"),
                FormStep(
                    titleKey: "onboarding.form.4D2.step3.title",
                    stepProgressKey: progress(3, of: 4),
                    fields: [
                        field("instagramHandle",
                              kind: .url(scheme: .instagram),
                              placeholder: "onboarding.form.field.instagramHandle.placeholder",
                              help: "onboarding.form.field.instagramHandle.help"),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                FormStep(
                    titleKey: "onboarding.form.4D2.step4.title",
                    stepProgressKey: progress(4, of: 4),
                    fields: [
                        field("profilePhoto",
                              kind: .photo(aspect: .portrait),
                              placeholder: "onboarding.form.field.logoPhoto.placeholder",
                              help: "onboarding.form.field.profilePhoto.help",
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.letsGo",
                    bottomTitle: "onboarding.form.4D2.tfp.hint.title",
                    bottomSubtitle: "onboarding.form.4D2.tfp.hint.subtitle"
                ),
            ]
        )
    }
}

// MARK: - 4.D3 Actor / Dancer / Singer (4 шага, специализация зависит от роли)

private extension OnboardingFormCatalog {

    func makeTalentActorDancerSinger(state: OnboardingRegistrationState) -> FormSchema {
        let specialisationOptions = specialisationOptionsForActorDancerSinger(roleId: state.selectedRoleId)
        return FormSchema(
            id: .talentActorDancerSinger,
            internalTitleKey: "onboarding.form.4D3.title",
            steps: [
                identityStep(progressKey: progress(1, of: 4)),
                FormStep(
                    titleKey: "onboarding.form.section.location.title",
                    stepProgressKey: progress(2, of: 4),
                    fields: [
                        field("country", 
                              kind: .country(options: countryOptions), 
                              title: "onboarding.form.field.country.title", 
                              placeholder: "onboarding.form.field.country.placeholder", 
                              required: true),
                        field("city",    
                              kind: .city,    
                              placeholder: "onboarding.form.field.city.placeholder",    
                              required: true),
                        field("specialisation",
                              kind: .picker(options: specialisationOptions),
                              title: "onboarding.form.4D3.specialisation.title",
                              placeholder: "onboarding.form.4D3.specialisation.placeholder",
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                FormStep(
                    titleKey: "onboarding.form.4D3.step3.title",
                    stepProgressKey: progress(3, of: 4),
                    fields: [
                        field("showreelUrl",
                              kind: .url(scheme: .anyHttp),
                              placeholder: "onboarding.form.4D3.showreelUrl.placeholder"),
                        field("instagramOrCasting",
                              kind: .url(scheme: .anyLink),
                              placeholder: "onboarding.form.4D3.instagramOrCasting.placeholder"),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                profilePhotoStep(progressKey: progress(4, of: 4), buttonKey: "onboarding.button.done"),
            ]
        )
    }

    /// Список специализаций для 4.D3 строится по выбранной роли.
    /// Добавишь новую роль (или сменишь специализации) — правишь только здесь.
    func specialisationOptionsForActorDancerSinger(roleId: OnboardingRoleID?) -> [FormPickerOption] {
        guard let roleId = roleId else { return [] }
        switch roleId {
        case .actor:
            return [
                .init(id: "film",       titleKey: "onboarding.form.4D3.actor.specialisation.film"),
                .init(id: "theatre",    titleKey: "onboarding.form.4D3.actor.specialisation.theatre"),
                .init(id: "commercial", titleKey: "onboarding.form.4D3.actor.specialisation.commercial"),
                .init(id: "dubbing",    titleKey: "onboarding.form.4D3.actor.specialisation.dubbing"),
                .init(id: "tv",         titleKey: "onboarding.form.4D3.actor.specialisation.tv"),
                .init(id: "other",      titleKey: "onboarding.form.4D3.actor.specialisation.other"),
            ]
        case .dancer:
            return [
                .init(id: "contemporary", titleKey: "onboarding.form.4D3.dancer.specialisation.contemporary"),
                .init(id: "ballet",       titleKey: "onboarding.form.4D3.dancer.specialisation.ballet"),
                .init(id: "hiphop",       titleKey: "onboarding.form.4D3.dancer.specialisation.hiphop"),
                .init(id: "ballroom",     titleKey: "onboarding.form.4D3.dancer.specialisation.ballroom"),
                .init(id: "commercial",   titleKey: "onboarding.form.4D3.dancer.specialisation.commercial"),
                .init(id: "latin",        titleKey: "onboarding.form.4D3.dancer.specialisation.latin"),
                .init(id: "jazz",         titleKey: "onboarding.form.4D3.dancer.specialisation.jazz"),
                .init(id: "other",        titleKey: "onboarding.form.4D3.dancer.specialisation.other"),
            ]
        case .singerPerformer:
            return [
                .init(id: "pop",            titleKey: "onboarding.form.4D3.singer.specialisation.pop"),
                .init(id: "rnb",            titleKey: "onboarding.form.4D3.singer.specialisation.rnb"),
                .init(id: "jazz",           titleKey: "onboarding.form.4D3.singer.specialisation.jazz"),
                .init(id: "classical",      titleKey: "onboarding.form.4D3.singer.specialisation.classical"),
                .init(id: "musicalTheatre", titleKey: "onboarding.form.4D3.singer.specialisation.musicalTheatre"),
                .init(id: "opera",          titleKey: "onboarding.form.4D3.singer.specialisation.opera"),
                .init(id: "other",          titleKey: "onboarding.form.4D3.singer.specialisation.other"),
            ]
        default:
            return []
        }
    }
}

// MARK: - 4.E Fan (2 шага, второй с Skip)

private extension OnboardingFormCatalog {

    func makeFan() -> FormSchema {
        return FormSchema(
            id: .fan,
            internalTitleKey: "onboarding.form.4E.title",
            steps: [
                FormStep(
                    titleKey: "onboarding.form.4E.step1.title",
                    stepProgressKey: progress(1, of: 2),
                    fields: [
                        field("firstName",   kind: .text(minLength: 1, maxLength: 60), placeholder: "onboarding.form.field.firstName.placeholder", required: true),
                        field("lastName",    kind: .text(minLength: 1, maxLength: 60), placeholder: "onboarding.form.field.lastName.placeholder",  required: true),
                        field("dateOfBirth", 
                              kind: .date(min: dateOfBirthMin, max: dateOfBirthMax),  
                              title: "onboarding.form.field.dateOfBirth.title",     
                              placeholder: "onboarding.form.field.dateOfBirth.placeholder", 
                              required: true),
                        field("country",     
                              kind: .country(options: countryOptions), 
                              title: "onboarding.form.field.country.title",                           
                              placeholder: "onboarding.form.field.country.placeholder",   
                              required: true),
                    ],
                    primaryButtonKey: "onboarding.button.continue"
                ),
                FormStep(
                    titleKey: "onboarding.form.4E.step2.title",
                    subtitleKey: "onboarding.form.4E.step2.subtitle",
                    stepProgressKey: progress(2, of: 2),
                    fields: [
                        field("profilePhoto",
                              kind: .photo(aspect: .portrait),
                              placeholder: "onboarding.form.field.profilePhoto.placeholder",
                              help: "onboarding.form.field.profilePhoto.help"),
                    ],
                    primaryButtonKey: "onboarding.button.done",
                    allowSkip: true
                ),
            ]
        )
    }
}

// MARK: - Общие переиспользуемые шаги

private extension OnboardingFormCatalog {

    /// «YOUR IDENTITY» — общий шаг для 4.D1 / 4.D2 / 4.D3.
    func identityStep(progressKey: String) -> FormStep {
        return FormStep(
            titleKey: "onboarding.form.section.identity.title",
            stepProgressKey: progressKey,
            fields: [
                field("firstName",   kind: .text(minLength: 1, maxLength: 60), placeholder: "onboarding.form.field.firstName.placeholder", required: true),
                field("lastName",    kind: .text(minLength: 1, maxLength: 60), placeholder: "onboarding.form.field.lastName.placeholder",  required: true),
                field("dateOfBirth", 
                      kind: .date(min: dateOfBirthMin, max: dateOfBirthMax),  
                      title: "onboarding.form.field.dateOfBirth.title",      
                      placeholder: "onboarding.form.field.dateOfBirth.placeholder", 
                      required: true),
                field("gender",      
                      kind: .picker(options: genderOptions), 
                      title: "onboarding.form.field.gender.title",   
                      placeholder: "onboarding.form.field.gender.placeholder",     
                      required: true),
            ],
            primaryButtonKey: "onboarding.button.continue"
        )
    }

    /// «PERSONAL DETAILS» — общий шаг для 4.B / 4.C1.
    func personalDetailsStep(progressKey: String, includeCity: Bool) -> FormStep {
        var fields: [FormField] = [
            field("dateOfBirth", kind: .date(min: dateOfBirthMin, max: dateOfBirthMax),      title: "onboarding.form.field.dateOfBirth.title", placeholder: "onboarding.form.field.dateOfBirth.placeholder", required: true),
            field("gender",      kind: .picker(options: genderOptions),   title: "onboarding.form.field.gender.title",      placeholder: "onboarding.form.field.gender.placeholder",      required: true),
            field("country",     kind: .country(options: countryOptions), title: "onboarding.form.field.country.title",     placeholder: "onboarding.form.field.country.placeholder",     required: true),
        ]
        if includeCity {
            fields.append(field("city", kind: .city, placeholder: "onboarding.form.field.city.placeholder", required: true))
        }
        return FormStep(
            titleKey: "onboarding.form.section.personalDetails.title",
            stepProgressKey: progressKey,
            fields: fields,
            primaryButtonKey: "onboarding.button.continue"
        )
    }

    /// «LOCATION» — только country + city.
    func locationStep(progressKey: String, titleKey: String) -> FormStep {
        return FormStep(
            titleKey: titleKey,
            stepProgressKey: progressKey,
            fields: [
                field("country", 
                      kind: .country(options: countryOptions), 
                      title: "onboarding.form.field.country.title", 
                      placeholder: "onboarding.form.field.country.placeholder", 
                      required: true),
                field("city",    
                      kind: .city,    
                      placeholder: "onboarding.form.field.city.placeholder",    
                      required: true),
            ],
            primaryButtonKey: "onboarding.button.continue"
        )
    }

    /// Финальный шаг «ADD YOUR PROFILE PHOTO».
    func profilePhotoStep(progressKey: String, buttonKey: String) -> FormStep {
        return FormStep(
            titleKey: "onboarding.form.section.profilePhoto.title",
            subtitleKey: "onboarding.form.section.profilePhoto.subtitle",
            stepProgressKey: progressKey,
            fields: [
                field("profilePhoto",
                      kind: .photo(aspect: .portrait),
                      placeholder: "onboarding.form.field.logoPhoto.placeholder",
                      help: "onboarding.form.field.profilePhoto.help",
                      required: true),
            ],
            primaryButtonKey: buttonKey
        )
    }

    var genderOptions: [FormPickerOption] {
        return [
            .init(id: "female",      titleKey: "onboarding.form.gender.option.female"),
            .init(id: "male",        titleKey: "onboarding.form.gender.option.male"),
            .init(id: "nonbinary",   titleKey: "onboarding.form.gender.option.nonbinary"),
            .init(id: "preferNotToSay", titleKey: "onboarding.form.gender.option.preferNotToSay"),
        ]
    }
}
