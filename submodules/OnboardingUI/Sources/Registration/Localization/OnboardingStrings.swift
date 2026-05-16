import Foundation
import DivoCore

/// Мост между string-key'ями каталога онбординга и локализованными строками `DivoStrings`.
///
/// Catalog файлы (QuizCatalog/ResultCatalog/FormCatalog) хранят string-keys типа
/// `"onboarding.role.scout.name"`. Контроллеры экранов при отрисовке зовут
/// `OnboardingStrings.resolve(_:)` — этот резолвер маппит ключ в `DivoStrings.<property>`.
///
/// Зачем такой мост:
/// - Catalog'и остаются декларативными и легко читаются (без захардкоженного UIKit-кода).
/// - При локализации/смене языка вся отрисовка автоматически использует свежие тексты.
/// - При добавлении/переименовании ключа правка идёт в двух местах: catalog (один key)
///   и DivoStrings (один property). Никаких разбегов между каталогом и контроллерами.
///
/// FIXME (PROJ-004): сейчас почти все ключи возвращают английский placeholder. Перед мержем
/// в dev для каждого ключа нужно:
///   1. Добавить property в `DivoStrings.swift` с `L(en:ru:es:pt:zh:)` в нужной MARK-секции.
///   2. Заменить case ниже на `return DivoStrings.<newProperty>`.
public enum OnboardingStrings {

    public static func resolve(_ key: String) -> String {
        if let mapped = mappedFromDivoStrings(key) { return mapped }
        return placeholder(forKey: key) ?? key
    }

    /// 1) Сначала пытаемся отрезолвить через DivoStrings — это финальная локализация.
    /// Все ключи онбординга мигрированы в `DivoStrings.swift` под MARK-секциями `// MARK: - Onboarding`.
    /// При добавлении нового ключа: дописываем property в DivoStrings и case сюда.
    private static func mappedFromDivoStrings(_ key: String) -> String? {
        // Динамические форматтеры — обрабатываем по префиксу.
        if let progress = formProgress(forKey: key) { return progress }
        if let progress = quizProgress(forKey: key) { return progress }

        switch key {
        // MARK: Buttons
        case "onboarding.button.continue":            return DivoStrings.continueButton
        case "onboarding.button.done":                return DivoStrings.onboardingButtonDone
        case "onboarding.button.skip":                return DivoStrings.onboardingButtonSkip
        case "onboarding.button.letsGo":              return DivoStrings.onboardingButtonLetsGo
        case "onboarding.result.button.primary":      return DivoStrings.onboardingResultButtonPrimary
        case "onboarding.result.button.secondary":    return DivoStrings.onboardingResultButtonSecondary

        // MARK: Quiz — top-level
        case "onboarding.quiz.topLevel.title":                                   return DivoStrings.onboardingQuizTopLevelTitle
        case "onboarding.quiz.topLevel.subtitle":                                return ""
        case "onboarding.quiz.topLevel.option.getHired.title":                   return DivoStrings.onboardingQuizTopLevelOptionGetHiredTitle
        case "onboarding.quiz.topLevel.option.getHired.subtitle":                return DivoStrings.onboardingQuizTopLevelOptionGetHiredSubtitle
        case "onboarding.quiz.topLevel.option.lookingForTalent.title":           return DivoStrings.onboardingQuizTopLevelOptionLookingForTalentTitle
        case "onboarding.quiz.topLevel.option.lookingForTalent.subtitle":        return DivoStrings.onboardingQuizTopLevelOptionLookingForTalentSubtitle
        case "onboarding.quiz.topLevel.option.hereToFollow.title":               return DivoStrings.onboardingQuizTopLevelOptionHereToFollowTitle
        case "onboarding.quiz.topLevel.option.hereToFollow.subtitle":            return DivoStrings.onboardingQuizTopLevelOptionHereToFollowSubtitle

        // MARK: Quiz — industry door
        case "onboarding.quiz.industryDoor.title":                                   return DivoStrings.onboardingQuizIndustryDoorTitle
        case "onboarding.quiz.industryDoor.subtitle":                                return DivoStrings.onboardingQuizIndustryDoorSubtitle
        case "onboarding.quiz.industryDoor.option.representCompany.title":           return DivoStrings.onboardingQuizIndustryDoorOptionRepresentCompanyTitle
        case "onboarding.quiz.industryDoor.option.representCompany.subtitle":        return DivoStrings.onboardingQuizIndustryDoorOptionRepresentCompanySubtitle
        case "onboarding.quiz.industryDoor.option.industryProfessional.title":       return DivoStrings.onboardingQuizIndustryDoorOptionIndustryProTitle
        case "onboarding.quiz.industryDoor.option.industryProfessional.subtitle":    return DivoStrings.onboardingQuizIndustryDoorOptionIndustryProSubtitle

        // MARK: Quiz — sub-role pickers + experience
        case "onboarding.quiz.talentPicker.title":           return DivoStrings.onboardingQuizTalentPickerTitle
        case "onboarding.quiz.industryProPicker.title":      return DivoStrings.onboardingQuizIndustryProPickerTitle
        case "onboarding.quiz.companiesPicker.title":        return DivoStrings.onboardingQuizCompaniesPickerTitle
        case "onboarding.quiz.experience.title":             return DivoStrings.onboardingQuizExperienceTitle
        case "onboarding.quiz.experience.subtitle":          return DivoStrings.onboardingQuizExperienceSubtitle
        case "onboarding.quiz.experience.option.yes.title":      return DivoStrings.onboardingQuizExperienceOptionYesTitle
        case "onboarding.quiz.experience.option.yes.subtitle":   return DivoStrings.onboardingQuizExperienceOptionYesSubtitle
        case "onboarding.quiz.experience.option.no.title":       return DivoStrings.onboardingQuizExperienceOptionNoTitle
        case "onboarding.quiz.experience.option.no.subtitle":    return DivoStrings.onboardingQuizExperienceOptionNoSubtitle

        // MARK: Role names
        case "onboarding.role.modelingAgency.name":      return DivoStrings.onboardingRoleModelingAgency
        case "onboarding.role.fashionBrand.name":        return DivoStrings.onboardingRoleFashionBrand
        case "onboarding.role.brandOrBusiness.name":     return DivoStrings.onboardingRoleBrandOrBusiness
        case "onboarding.role.beautyBrand.name":         return DivoStrings.onboardingRoleBeautyBrand
        case "onboarding.role.eventAgency.name":         return DivoStrings.onboardingRoleEventAgency
        case "onboarding.role.magazinePublication.name": return DivoStrings.onboardingRoleMagazineMedia
        case "onboarding.role.scout.name":               return DivoStrings.onboardingRoleScout
        case "onboarding.role.scout.subtitle":           return DivoStrings.onboardingRoleScoutSubtitle
        case "onboarding.role.booker.name":              return DivoStrings.onboardingRoleBooker
        case "onboarding.role.booker.subtitle":          return DivoStrings.onboardingRoleBookerSubtitle
        case "onboarding.role.castingDirector.name":     return DivoStrings.onboardingRoleCastingDirector
        case "onboarding.role.castingDirector.subtitle": return DivoStrings.onboardingRoleCastingDirectorSubtitle
        case "onboarding.role.talentManager.name":       return DivoStrings.onboardingRoleTalentManager
        case "onboarding.role.talentManager.subtitle":   return DivoStrings.onboardingRoleTalentManagerSubtitle
        case "onboarding.role.photographer.name":        return DivoStrings.onboardingRolePhotographer
        case "onboarding.role.stylist.name":             return DivoStrings.onboardingRoleStylist
        case "onboarding.role.makeupArtist.name":        return DivoStrings.onboardingRoleMakeupArtist
        case "onboarding.role.hairStylist.name":         return DivoStrings.onboardingRoleHairStylist
        case "onboarding.role.videographer.name":        return DivoStrings.onboardingRoleVideographer
        case "onboarding.role.creativeDirector.name":    return DivoStrings.onboardingRoleCreativeDirector
        case "onboarding.role.fashionDesigner.name":     return DivoStrings.onboardingRoleFashionDesigner
        case "onboarding.role.studioLocation.name":      return DivoStrings.onboardingRoleStudioLocation
        case "onboarding.role.model.name":               return DivoStrings.onboardingRoleModel
        case "onboarding.role.newTalent.name":           return DivoStrings.onboardingRoleNewTalent
        case "onboarding.role.actor.name":               return DivoStrings.onboardingRoleActor
        case "onboarding.role.dancer.name":              return DivoStrings.onboardingRoleDancer
        case "onboarding.role.singerPerformer.name":     return DivoStrings.onboardingRoleSingerPerformer
        case "onboarding.role.fan.name":                 return DivoStrings.onboardingRoleFan

        // MARK: Result screens
        case "onboarding.result.modelVariant.title":           return DivoStrings.onboardingResultModelTitle
        case "onboarding.result.modelVariant.description":     return DivoStrings.onboardingResultModelDescription
        case "onboarding.result.newTalentVariant.title":       return DivoStrings.onboardingResultNewTalentTitle
        case "onboarding.result.newTalentVariant.description": return DivoStrings.onboardingResultNewTalentDescription
        case "onboarding.result.actor.title":                  return DivoStrings.onboardingResultActorTitle
        case "onboarding.result.actor.description":            return DivoStrings.onboardingResultActorDescription
        case "onboarding.result.dancer.title":                 return DivoStrings.onboardingResultDancerTitle
        case "onboarding.result.dancer.description":           return DivoStrings.onboardingResultDancerDescription
        case "onboarding.result.singerPerformer.title":        return DivoStrings.onboardingResultSingerTitle
        case "onboarding.result.singerPerformer.description":  return DivoStrings.onboardingResultSingerDescription
        case "onboarding.result.creativeProfessional.title":   return DivoStrings.onboardingResultCreativeTitle
        case "onboarding.result.creativeProfessional.description": return DivoStrings.onboardingResultCreativeDescription
        case "onboarding.result.companiesBrands.title":        return DivoStrings.onboardingResultCompaniesTitle
        case "onboarding.result.companiesBrands.description":  return DivoStrings.onboardingResultCompaniesDescription
        case "onboarding.result.industryProfessional.title":   return DivoStrings.onboardingResultIndustryProTitle
        case "onboarding.result.industryProfessional.description": return DivoStrings.onboardingResultIndustryProDescription
        case "onboarding.result.fan.title":                    return DivoStrings.onboardingResultFanTitle
        case "onboarding.result.fan.description":              return DivoStrings.onboardingResultFanDescription

        // MARK: Common sections
        case "onboarding.form.section.identity.title":         return DivoStrings.onboardingSectionIdentityTitle
        case "onboarding.form.section.personalDetails.title":  return DivoStrings.onboardingSectionPersonalDetailsTitle
        case "onboarding.form.section.location.title":         return DivoStrings.onboardingSectionLocationTitle
        case "onboarding.form.section.profilePhoto.title":     return DivoStrings.onboardingSectionProfilePhotoTitle
        case "onboarding.form.section.profilePhoto.subtitle":  return DivoStrings.onboardingSectionProfilePhotoSubtitle

        // MARK: Field placeholders
        case "onboarding.form.field.firstName.placeholder":            return DivoStrings.onboardingFieldFirstNamePlaceholder
        case "onboarding.form.field.lastName.placeholder":             return DivoStrings.onboardingFieldLastNamePlaceholder
        case "onboarding.form.field.dateOfBirth.placeholder":          return DivoStrings.onboardingFieldDateOfBirthPlaceholder
        case "onboarding.form.field.gender.placeholder":               return DivoStrings.onboardingFieldGenderPlaceholder
        case "onboarding.form.field.country.placeholder":              return DivoStrings.onboardingFieldCountryPlaceholder
        case "onboarding.form.field.city.placeholder":                 return DivoStrings.onboardingFieldCityPlaceholder
        case "onboarding.form.field.instagramHandle.placeholder":      return DivoStrings.onboardingFieldInstagramHandlePlaceholder
        case "onboarding.form.field.instagramHandle.help":             return DivoStrings.onboardingFieldInstagramHandleHelp
        case "onboarding.form.field.instagramOrPortfolio.placeholder": return DivoStrings.onboardingFieldInstagramOrPortfolioPlaceholder
        case "onboarding.form.field.profilePhoto.placeholder":         return DivoStrings.onboardingFieldProfilePhotoPlaceholder
        case "onboarding.form.field.profilePhoto.help":                return DivoStrings.onboardingFieldProfilePhotoHelp
        case "onboarding.form.field.profilePhoto.selected":            return DivoStrings.onboardingFieldProfilePhotoSelected
        case "onboarding.form.field.logoPhoto.placeholder":            return DivoStrings.onboardingFieldLogoPhotoPlaceholder
        case "onboarding.form.field.logoPhoto.help":                   return DivoStrings.onboardingFieldLogoPhotoHelp

        // MARK: Gender
        case "onboarding.form.gender.option.female":          return DivoStrings.onboardingGenderFemale
        case "onboarding.form.gender.option.male":            return DivoStrings.onboardingGenderMale
        case "onboarding.form.gender.option.nonbinary":       return DivoStrings.onboardingGenderNonbinary
        case "onboarding.form.gender.option.preferNotToSay":  return DivoStrings.onboardingGenderPreferNotToSay

        // MARK: Form 4.A
        case "onboarding.form.4A.title":                                 return DivoStrings.onboardingForm4ATitle
        case "onboarding.form.4A.step1.title":                           return DivoStrings.onboardingForm4AStep1Title
        case "onboarding.form.4A.companyName.placeholder":               return DivoStrings.onboardingForm4ACompanyNamePlaceholder
        case "onboarding.form.4A.companyType.placeholder":               return DivoStrings.onboardingForm4ACompanyTypePlaceholder
        case "onboarding.form.4A.step2.title":                           return DivoStrings.onboardingForm4AStep2Title
        case "onboarding.form.4A.step3.title":                           return DivoStrings.onboardingForm4AStep3Title
        case "onboarding.form.4A.websiteUrl.placeholder":                return DivoStrings.onboardingForm4AWebsiteUrlPlaceholder
        case "onboarding.form.4A.websiteUrl.help":                       return DivoStrings.onboardingForm4AWebsiteUrlHelp
        case "onboarding.form.4A.contactFirstName.placeholder":          return DivoStrings.onboardingForm4AContactFirstNamePlaceholder
        case "onboarding.form.4A.contactLastName.placeholder":           return DivoStrings.onboardingForm4AContactLastNamePlaceholder
        case "onboarding.form.4A.contactRole.placeholder":               return DivoStrings.onboardingForm4AContactRolePlaceholder
        case "onboarding.form.4A.step4.title":                           return DivoStrings.onboardingForm4AStep4Title
        case "onboarding.form.4A.companyType.option.modelingAgency":     return DivoStrings.onboardingForm4ACompanyTypeOptionModelingAgency
        case "onboarding.form.4A.companyType.option.fashionBrand":       return DivoStrings.onboardingForm4ACompanyTypeOptionFashionBrand
        case "onboarding.form.4A.companyType.option.beautyBrand":        return DivoStrings.onboardingForm4ACompanyTypeOptionBeautyBrand
        case "onboarding.form.4A.companyType.option.brandOrBusiness":    return DivoStrings.onboardingForm4ACompanyTypeOptionBrandOrBusiness
        case "onboarding.form.4A.companyType.option.eventAgency":        return DivoStrings.onboardingForm4ACompanyTypeOptionEventAgency
        case "onboarding.form.4A.companyType.option.magazineOrMedia":    return DivoStrings.onboardingForm4ACompanyTypeOptionMagazineOrMedia

        // MARK: Form 4.B
        case "onboarding.form.4B.title":            return DivoStrings.onboardingForm4BTitle
        case "onboarding.form.4B.step1.title":      return DivoStrings.onboardingForm4BStep1Title
        case "onboarding.form.4B.role.placeholder": return DivoStrings.onboardingForm4BRolePlaceholder
        case "onboarding.form.4B.step3.title":      return DivoStrings.onboardingForm4BStep3Title
        case "onboarding.form.4B.agency.placeholder": return DivoStrings.onboardingForm4BAgencyPlaceholder
        case "onboarding.form.4B.agency.help":      return DivoStrings.onboardingForm4BAgencyHelp

        // MARK: Form 4.C1
        case "onboarding.form.4C1.title":                       return DivoStrings.onboardingForm4C1Title
        case "onboarding.form.4C1.step1.title":                 return DivoStrings.onboardingForm4C1Step1Title
        case "onboarding.form.4C1.specialisation.placeholder":  return DivoStrings.onboardingForm4C1SpecialisationPlaceholder
        case "onboarding.form.4C1.step3.title":                 return DivoStrings.onboardingForm4C1Step3Title
        case "onboarding.form.4C1.step3.subtitle":              return DivoStrings.onboardingForm4C1Step3Subtitle
        case "onboarding.form.4C1.portfolio.help":              return DivoStrings.onboardingForm4C1PortfolioHelp

        // MARK: Form 4.C2
        case "onboarding.form.4C2.title":                           return DivoStrings.onboardingForm4C2Title
        case "onboarding.form.4C2.step1.title":                     return DivoStrings.onboardingForm4C2Step1Title
        case "onboarding.form.4C2.studioName.placeholder":          return DivoStrings.onboardingForm4C2StudioNamePlaceholder
        case "onboarding.form.4C2.step2.title":                     return DivoStrings.onboardingForm4C2Step2Title
        case "onboarding.form.4C2.websiteOrInstagram.placeholder":  return DivoStrings.onboardingForm4C2WebsiteOrInstagramPlaceholder
        case "onboarding.form.4C2.websiteOrInstagram.help":         return DivoStrings.onboardingForm4C2WebsiteOrInstagramHelp
        case "onboarding.form.4C2.contactName.placeholder":         return DivoStrings.onboardingForm4C2ContactNamePlaceholder
        case "onboarding.form.4C2.contactName.help":                return DivoStrings.onboardingForm4C2ContactNameHelp
        case "onboarding.form.4C2.contactPhoneOrEmail.placeholder": return DivoStrings.onboardingForm4C2ContactPhoneOrEmailPlaceholder
        case "onboarding.form.4C2.contactPhoneOrEmail.help":        return DivoStrings.onboardingForm4C2ContactPhoneOrEmailHelp
        case "onboarding.form.4C2.step3.title":                     return DivoStrings.onboardingForm4C2Step3Title
        case "onboarding.form.4C2.step3.subtitle":                  return DivoStrings.onboardingForm4C2Step3Subtitle

        // MARK: Form 4.D1
        case "onboarding.form.4D1.title":                     return DivoStrings.onboardingForm4D1Title
        case "onboarding.form.4D1.step3.title":               return DivoStrings.onboardingForm4D1Step3Title
        case "onboarding.form.4D1.currentAgency.placeholder": return DivoStrings.onboardingForm4D1CurrentAgencyPlaceholder
        case "onboarding.form.4D1.currentAgency.help":        return DivoStrings.onboardingForm4D1CurrentAgencyHelp
        case "onboarding.form.4D1.step4.title":               return DivoStrings.onboardingForm4D1Step4Title
        case "onboarding.form.4D1.step4.subtitle":            return DivoStrings.onboardingForm4D1Step4Subtitle

        // MARK: Form 4.D2
        case "onboarding.form.4D2.title":       return DivoStrings.onboardingForm4D2Title
        case "onboarding.form.4D2.step3.title": return DivoStrings.onboardingForm4D2Step3Title
        case "onboarding.form.4D2.step4.title": return DivoStrings.onboardingForm4D2Step4Title
        case "onboarding.form.4D2.tfp.hint":    return DivoStrings.onboardingForm4D2TfpHint

        // MARK: Form 4.D3
        case "onboarding.form.4D3.title":                          return DivoStrings.onboardingForm4D3Title
        case "onboarding.form.4D3.step3.title":                    return DivoStrings.onboardingForm4D3Step3Title
        case "onboarding.form.4D3.specialisation.placeholder":     return DivoStrings.onboardingForm4D3SpecialisationPlaceholder
        case "onboarding.form.4D3.showreelUrl.placeholder":        return DivoStrings.onboardingForm4D3ShowreelUrlPlaceholder
        case "onboarding.form.4D3.instagramOrCasting.placeholder": return DivoStrings.onboardingForm4D3InstagramOrCastingPlaceholder
        case "onboarding.form.4D3.actor.specialisation.film":       return DivoStrings.onboardingForm4D3ActorSpecFilm
        case "onboarding.form.4D3.actor.specialisation.theatre":    return DivoStrings.onboardingForm4D3ActorSpecTheatre
        case "onboarding.form.4D3.actor.specialisation.commercial": return DivoStrings.onboardingForm4D3ActorSpecCommercial
        case "onboarding.form.4D3.actor.specialisation.dubbing":    return DivoStrings.onboardingForm4D3ActorSpecDubbing
        case "onboarding.form.4D3.actor.specialisation.tv":         return DivoStrings.onboardingForm4D3ActorSpecTV
        case "onboarding.form.4D3.actor.specialisation.other":      return DivoStrings.onboardingForm4D3SpecOther
        case "onboarding.form.4D3.dancer.specialisation.contemporary": return DivoStrings.onboardingForm4D3DancerSpecContemporary
        case "onboarding.form.4D3.dancer.specialisation.ballet":       return DivoStrings.onboardingForm4D3DancerSpecBallet
        case "onboarding.form.4D3.dancer.specialisation.hiphop":       return DivoStrings.onboardingForm4D3DancerSpecHipHop
        case "onboarding.form.4D3.dancer.specialisation.ballroom":     return DivoStrings.onboardingForm4D3DancerSpecBallroom
        case "onboarding.form.4D3.dancer.specialisation.commercial":   return DivoStrings.onboardingForm4D3ActorSpecCommercial
        case "onboarding.form.4D3.dancer.specialisation.latin":        return DivoStrings.onboardingForm4D3DancerSpecLatin
        case "onboarding.form.4D3.dancer.specialisation.jazz":         return DivoStrings.onboardingForm4D3DancerSpecJazz
        case "onboarding.form.4D3.dancer.specialisation.other":        return DivoStrings.onboardingForm4D3SpecOther
        case "onboarding.form.4D3.singer.specialisation.pop":            return DivoStrings.onboardingForm4D3SingerSpecPop
        case "onboarding.form.4D3.singer.specialisation.rnb":            return DivoStrings.onboardingForm4D3SingerSpecRnB
        case "onboarding.form.4D3.singer.specialisation.jazz":           return DivoStrings.onboardingForm4D3SingerSpecJazz
        case "onboarding.form.4D3.singer.specialisation.classical":      return DivoStrings.onboardingForm4D3SingerSpecClassical
        case "onboarding.form.4D3.singer.specialisation.musicalTheatre": return DivoStrings.onboardingForm4D3SingerSpecMusicalTheatre
        case "onboarding.form.4D3.singer.specialisation.opera":          return DivoStrings.onboardingForm4D3SingerSpecOpera
        case "onboarding.form.4D3.singer.specialisation.other":          return DivoStrings.onboardingForm4D3SpecOther

        // MARK: Form 4.E
        case "onboarding.form.4E.title":          return DivoStrings.onboardingForm4ETitle
        case "onboarding.form.4E.step1.title":    return DivoStrings.onboardingForm4EStep1Title
        case "onboarding.form.4E.step2.title":    return DivoStrings.onboardingForm4EStep2Title
        case "onboarding.form.4E.step2.subtitle": return DivoStrings.onboardingForm4EStep2Subtitle

        default:
            return nil
        }
    }

    /// Парсит `onboarding.form.progress.{step}of{total}` → `DivoStrings.onboardingFormProgress`.
    private static func formProgress(forKey key: String) -> String? {
        let prefix = "onboarding.form.progress."
        guard key.hasPrefix(prefix) else { return nil }
        let suffix = String(key.dropFirst(prefix.count))
        let parts = suffix.components(separatedBy: "of")
        guard parts.count == 2, let step = Int(parts[0]), let total = Int(parts[1]) else { return nil }
        return DivoStrings.onboardingFormProgress(step: step, of: total)
    }

    /// Парсит `onboarding.quiz.progress.{question}of{total}` → `DivoStrings.onboardingQuizProgress`.
    private static func quizProgress(forKey key: String) -> String? {
        let prefix = "onboarding.quiz.progress."
        guard key.hasPrefix(prefix) else { return nil }
        let suffix = String(key.dropFirst(prefix.count))
        let parts = suffix.components(separatedBy: "of")
        guard parts.count == 2, let q = Int(parts[0]), let total = Int(parts[1]) else { return nil }
        return DivoStrings.onboardingQuizProgress(question: q, of: total)
    }

    /// 2) Если в DivoStrings ключ ещё не подвезли — берём английский placeholder.
    /// Это даёт нам рабочий онбординг с понятными подписями ещё до полной локализации.
    /// Placeholder'ы — НЕ финальный текст, дизайн/копирайтер ещё ничего не утвердил.
    private static func placeholder(forKey key: String) -> String? {
        return placeholders[key]
    }

    // MARK: - English placeholders

    private static let placeholders: [String: String] = {
        var p: [String: String] = [:]

        // Кнопки
        p["onboarding.button.continue"]     = "Continue"
        p["onboarding.button.done"]         = "Done"
        p["onboarding.button.skip"]         = "Skip for now"
        p["onboarding.button.letsGo"]       = "Let's go"
        p["onboarding.result.button.primary"]   = "Sounds right — let's go"
        p["onboarding.result.button.secondary"] = "Choose a different role"

        // Quiz — top-level
        p["onboarding.quiz.topLevel.title"]    = "We'll set up your profile based on your answer. You can change this later."
        p["onboarding.quiz.topLevel.subtitle"] = ""
        p["onboarding.quiz.topLevel.option.getHired.title"]            = "I WANT TO GET HIRED"
        p["onboarding.quiz.topLevel.option.getHired.subtitle"]         = "Model, performer, creative pro"
        p["onboarding.quiz.topLevel.option.lookingForTalent.title"]    = "I'M LOOKING FOR TALENT"
        p["onboarding.quiz.topLevel.option.lookingForTalent.subtitle"] = "Agency, brand, scout, booker"
        p["onboarding.quiz.topLevel.option.hereToFollow.title"]        = "I'M HERE TO FOLLOW"
        p["onboarding.quiz.topLevel.option.hereToFollow.subtitle"]     = "Fan of fashion and creators"

        // Quiz — industry door
        p["onboarding.quiz.industryDoor.title"]    = "HOW DO YOU WORK?"
        p["onboarding.quiz.industryDoor.subtitle"] = "This helps us tag your right profile"
        p["onboarding.quiz.industryDoor.option.representCompany.title"]         = "I REPRESENT A COMPANY"
        p["onboarding.quiz.industryDoor.option.representCompany.subtitle"]      = "Agency, brand, media or business"
        p["onboarding.quiz.industryDoor.option.industryProfessional.title"]     = "I'M AN INDUSTRY PRO"
        p["onboarding.quiz.industryDoor.option.industryProfessional.subtitle"]  = "Scout, booker, casting director"

        // Quiz — sub-role picker titles
        p["onboarding.quiz.talentPicker.title"]      = "WHAT KIND OF TALENT ARE YOU?"
        p["onboarding.quiz.industryProPicker.title"] = "WHAT'S YOUR ROLE IN THE INDUSTRY?"
        p["onboarding.quiz.companiesPicker.title"]   = "WHAT BEST DESCRIBES YOUR COMPANY?"

        // Quiz — experience (Model)
        p["onboarding.quiz.experience.title"]    = "DO YOU HAVE PROFESSIONAL MODELLING EXPERIENCE AND AN AGENCY?"
        p["onboarding.quiz.experience.subtitle"] = "This helps us match you with the right castings from day one"
        p["onboarding.quiz.experience.option.yes.title"]    = "YES"
        p["onboarding.quiz.experience.option.yes.subtitle"] = "I have a portfolio and I work with or have worked with an agency"
        p["onboarding.quiz.experience.option.no.title"]     = "NO YET"
        p["onboarding.quiz.experience.option.no.subtitle"]  = "I'm building my career and don't have an agency yet"

        // Quiz — progress
        p["onboarding.quiz.progress.1of2"] = "Question 1 of 2"
        p["onboarding.quiz.progress.2of2"] = "Question 2 of 2"

        // Roles — display names
        p["onboarding.role.modelingAgency.name"]      = "Modeling agency"
        p["onboarding.role.fashionBrand.name"]        = "Fashion brand"
        p["onboarding.role.brandOrBusiness.name"]     = "Brand or business"
        p["onboarding.role.beautyBrand.name"]         = "Beauty brand"
        p["onboarding.role.eventAgency.name"]         = "Event agency"
        p["onboarding.role.magazinePublication.name"] = "Magazine or media"
        p["onboarding.role.scout.name"]            = "SCOUT"
        p["onboarding.role.scout.subtitle"]        = "I find new faces, independently or for an agency"
        p["onboarding.role.booker.name"]           = "BOOKER"
        p["onboarding.role.booker.subtitle"]       = "I manage bookings and negotiations for models at an agency"
        p["onboarding.role.castingDirector.name"]  = "CASTING DIRECTOR"
        p["onboarding.role.castingDirector.subtitle"] = "I run castings for specific projects: shows, ads or film"
        p["onboarding.role.talentManager.name"]    = "TALENT MANAGER"
        p["onboarding.role.talentManager.subtitle"] = "I represent and manage individual talent on their career"
        p["onboarding.role.photographer.name"]     = "PHOTOGRAPHER"
        p["onboarding.role.stylist.name"]          = "STYLIST"
        p["onboarding.role.makeupArtist.name"]     = "MAKEUP ARTIST"
        p["onboarding.role.hairStylist.name"]      = "HAIR STYLIST"
        p["onboarding.role.videographer.name"]     = "VIDEOGRAPHER"
        p["onboarding.role.creativeDirector.name"] = "CREATIVE DIRECTOR"
        p["onboarding.role.fashionDesigner.name"]  = "FASHION DESIGNER"
        p["onboarding.role.studioLocation.name"]   = "STUDIO / LOCATION"
        p["onboarding.role.model.name"]            = "MODEL"
        p["onboarding.role.newTalent.name"]        = "NEW TALENT"
        p["onboarding.role.actor.name"]            = "ACTOR OR ACTRESS"
        p["onboarding.role.dancer.name"]           = "DANCER"
        p["onboarding.role.singerPerformer.name"]  = "SINGER OR PERFORMER"
        p["onboarding.role.fan.name"]              = "FAN"

        // Result-экраны (заголовок + описание)
        p["onboarding.result.modelVariant.title"]       = "YOU'RE A PROFESSIONAL MODEL"
        p["onboarding.result.modelVariant.description"] = "Your profile will be built to showcase your portfolio and connect you directly with agencies and brands looking for experienced talent."
        p["onboarding.result.newTalentVariant.title"]   = "YOU'RE A RISING TALENT"
        p["onboarding.result.newTalentVariant.description"] = "Your profile will help you build raw potential, get casting, find TFP shoots with photographers and stylists."
        p["onboarding.result.actor.title"]              = "YOU'RE AN ACTOR"
        p["onboarding.result.actor.description"]        = "Our profile will connect you with brands and agencies looking for acting talent for campaigns, fashion films and live events."
        p["onboarding.result.dancer.title"]             = "YOU'RE A DANCER"
        p["onboarding.result.dancer.description"]       = "Your profile will pair your skills, campaigns and events looking for dance talent across all styles."
        p["onboarding.result.singerPerformer.title"]    = "YOU'RE A PERFORMER"
        p["onboarding.result.singerPerformer.description"] = "Your profile will connect you to fashion events, brand campaigns and creative projects looking for the performance talent."
        p["onboarding.result.creativeProfessional.title"] = "YOU'RE A CREATIVE PROFESSIONAL"
        p["onboarding.result.creativeProfessional.description"] = "Our profile will showcase your portfolio, let you post projects and connect with models, brands and agencies — on both sides of the market."
        p["onboarding.result.companiesBrands.title"]    = "YOU'RE HERE TO FIND TALENT"
        p["onboarding.result.companiesBrands.description"] = "Our profile will be set up to search, post castings and connect directly with models and creatives — whether you're a brand, agency, scout, or anyone else who works with talent."
        p["onboarding.result.industryProfessional.title"] = "YOU'RE A TALENT INDUSTRY PROFESSIONAL"
        p["onboarding.result.industryProfessional.description"] = "Talent database, advanced search tools and casting workflow — for the way professionals actually work."
        p["onboarding.result.fan.title"]                = "YOU'RE A FASHION FAN"
        p["onboarding.result.fan.description"]          = "You'll be able to follow your favourite models and creators, discover new talent and stay connected to the fashion world."

        // Форма 4.A
        p["onboarding.form.4A.title"]                 = "Companies & Brands"
        p["onboarding.form.4A.step1.title"]           = "TELL US ABOUT YOUR COMPANY"
        p["onboarding.form.4A.companyName.placeholder"] = "Company / Organisation name *"
        p["onboarding.form.4A.companyType.placeholder"] = "Choose a type company"
        p["onboarding.form.4A.companyType.option.modelingAgency"]   = "Modeling agency"
        p["onboarding.form.4A.companyType.option.fashionBrand"]     = "Fashion brand"
        p["onboarding.form.4A.companyType.option.beautyBrand"]      = "Beauty brand"
        p["onboarding.form.4A.companyType.option.brandOrBusiness"]  = "Brand or business"
        p["onboarding.form.4A.companyType.option.eventAgency"]      = "Event agency"
        p["onboarding.form.4A.companyType.option.magazineOrMedia"]  = "Magazine or media"
        p["onboarding.form.4A.step2.title"]           = "WHERE ARE YOU BASED?"
        p["onboarding.form.4A.step3.title"]           = "VERIFICATION & CONTACT"
        p["onboarding.form.4A.websiteUrl.placeholder"] = "Website URL"
        p["onboarding.form.4A.websiteUrl.help"]        = "Helps verify your account"
        p["onboarding.form.4A.contactFirstName.placeholder"] = "Contact first name"
        p["onboarding.form.4A.contactLastName.placeholder"]  = "Contact last name"
        p["onboarding.form.4A.contactRole.placeholder"]      = "Contact role / title"
        p["onboarding.form.4A.step4.title"]           = "ADD YOUR LOGO OR PROFILE PHOTO"

        // Форма 4.B
        p["onboarding.form.4B.title"]            = "Industry Professionals"
        p["onboarding.form.4B.step1.title"]      = "YOUR PROFESSIONAL IDENTITY"
        p["onboarding.form.4B.role.placeholder"] = "Role"
        p["onboarding.form.4B.step3.title"]      = "PROFESSIONAL LINKS"
        p["onboarding.form.4B.agency.placeholder"] = "Agency / Organisation"
        p["onboarding.form.4B.agency.help"]        = "Your agency will receive a confirmation request"

        // Форма 4.C1
        p["onboarding.form.4C1.title"]                       = "Creative Professionals — Individual"
        p["onboarding.form.4C1.step1.title"]                 = "YOUR CREATIVE IDENTITY"
        p["onboarding.form.4C1.specialisation.placeholder"]  = "Specialisation"
        p["onboarding.form.4C1.step3.title"]                 = "ADD YOUR PORTFOLIO"
        p["onboarding.form.4C1.step3.subtitle"]              = "Recommended — helps clients find your work faster"
        p["onboarding.form.4C1.portfolio.help"]              = "Share a link to your Instagram, Behance, personal site or any portfolio"

        // Форма 4.C2
        p["onboarding.form.4C2.title"]                          = "Creative Professionals — Studio"
        p["onboarding.form.4C2.step1.title"]                    = "YOUR STUDIO DETAILS"
        p["onboarding.form.4C2.studioName.placeholder"]         = "Studio / space name *"
        p["onboarding.form.4C2.step2.title"]                    = "CONTACT DETAILS"
        p["onboarding.form.4C2.websiteOrInstagram.placeholder"] = "Website or Instagram"
        p["onboarding.form.4C2.websiteOrInstagram.help"]        = "Light verification signal"
        p["onboarding.form.4C2.contactName.placeholder"]        = "Contact name"
        p["onboarding.form.4C2.contactName.help"]               = "Person managing bookings"
        p["onboarding.form.4C2.contactPhoneOrEmail.placeholder"] = "Contact phone or email"
        p["onboarding.form.4C2.contactPhoneOrEmail.help"]       = "For booking enquiries"
        p["onboarding.form.4C2.step3.title"]                    = "SHOW YOUR MAIN SPACE"
        p["onboarding.form.4C2.step3.subtitle"]                 = "Clients want to see what they're booking"

        // Форма 4.D1
        p["onboarding.form.4D1.title"]                     = "Talent — Model"
        p["onboarding.form.4D1.step3.title"]               = "PROFESSIONAL LINKS"
        p["onboarding.form.4D1.currentAgency.placeholder"] = "Current or last agency"
        p["onboarding.form.4D1.currentAgency.help"]        = "Add your agency to get a verified badge"
        p["onboarding.form.4D1.step4.title"]               = "SHOW THE WORLD WHO YOU ARE"
        p["onboarding.form.4D1.step4.subtitle"]            = "Use a clear, front-facing photo. You can update this any time."

        // Форма 4.D2
        p["onboarding.form.4D2.title"]            = "Talent — New Talent"
        p["onboarding.form.4D2.step3.title"]      = "PROFESSIONAL LINKS"
        p["onboarding.form.4D2.step4.title"]      = "ADD YOUR PROFILE PHOTO"
        p["onboarding.form.4D2.tfp.hint"]         = "Your first step: find a TFP shoot.\nTFP (Time For Portfolio) shoots are free collaborations with photographers. They'll build your portfolio fast. We'll show you how when you're in the app."

        // Форма 4.D3 (заголовки шагов общие, специализация — ниже)
        p["onboarding.form.4D3.title"]                       = "Talent — Actor / Dancer / Singer"
        p["onboarding.form.4D3.step3.title"]                 = "PROFESSIONAL LINKS"
        p["onboarding.form.4D3.specialisation.placeholder"]  = "Specialisation"
        p["onboarding.form.4D3.showreelUrl.placeholder"]     = "Showreel / demo reel URL"
        p["onboarding.form.4D3.instagramOrCasting.placeholder"] = "Instagram / casting profile URL"
        // Actor specialisations
        p["onboarding.form.4D3.actor.specialisation.film"]       = "Film"
        p["onboarding.form.4D3.actor.specialisation.theatre"]    = "Theatre"
        p["onboarding.form.4D3.actor.specialisation.commercial"] = "Commercial"
        p["onboarding.form.4D3.actor.specialisation.dubbing"]    = "Dubbing"
        p["onboarding.form.4D3.actor.specialisation.tv"]         = "TV"
        p["onboarding.form.4D3.actor.specialisation.other"]      = "Other"
        // Dancer specialisations
        p["onboarding.form.4D3.dancer.specialisation.contemporary"] = "Contemporary"
        p["onboarding.form.4D3.dancer.specialisation.ballet"]       = "Ballet"
        p["onboarding.form.4D3.dancer.specialisation.hiphop"]       = "Hip-hop"
        p["onboarding.form.4D3.dancer.specialisation.ballroom"]     = "Ballroom"
        p["onboarding.form.4D3.dancer.specialisation.commercial"]   = "Commercial"
        p["onboarding.form.4D3.dancer.specialisation.latin"]        = "Latin"
        p["onboarding.form.4D3.dancer.specialisation.jazz"]         = "Jazz"
        p["onboarding.form.4D3.dancer.specialisation.other"]        = "Other"
        // Singer specialisations
        p["onboarding.form.4D3.singer.specialisation.pop"]            = "Pop"
        p["onboarding.form.4D3.singer.specialisation.rnb"]            = "R&B"
        p["onboarding.form.4D3.singer.specialisation.jazz"]           = "Jazz"
        p["onboarding.form.4D3.singer.specialisation.classical"]      = "Classical"
        p["onboarding.form.4D3.singer.specialisation.musicalTheatre"] = "Musical Theatre"
        p["onboarding.form.4D3.singer.specialisation.opera"]          = "Opera"
        p["onboarding.form.4D3.singer.specialisation.other"]          = "Other"

        // Форма 4.E
        p["onboarding.form.4E.title"]            = "Fan Registration"
        p["onboarding.form.4E.step1.title"]      = "TELL US ABOUT YOURSELF"
        p["onboarding.form.4E.step2.title"]      = "ADD YOUR PROFILE PHOTO"
        p["onboarding.form.4E.step2.subtitle"]   = "Use a clear photo of yourself. You can update this any time."

        // Общие секции / поля
        p["onboarding.form.section.identity.title"]        = "YOUR IDENTITY"
        p["onboarding.form.section.personalDetails.title"] = "PERSONAL DETAILS"
        p["onboarding.form.section.location.title"]        = "LOCATION"
        p["onboarding.form.section.profilePhoto.title"]    = "ADD YOUR PROFILE PHOTO"
        p["onboarding.form.section.profilePhoto.subtitle"] = "Use a clear photo of yourself. You can update this any time."

        p["onboarding.form.field.firstName.placeholder"]            = "First name *"
        p["onboarding.form.field.lastName.placeholder"]             = "Last name *"
        p["onboarding.form.field.dateOfBirth.placeholder"]          = "Date of birth"
        p["onboarding.form.field.gender.placeholder"]               = "Choose a gender"
        p["onboarding.form.field.country.placeholder"]              = "Country"
        p["onboarding.form.field.city.placeholder"]                 = "City"
        p["onboarding.form.field.instagramHandle.placeholder"]      = "Instagram handle"
        p["onboarding.form.field.instagramHandle.help"]             = "Helps you get discovered faster"
        p["onboarding.form.field.instagramOrPortfolio.placeholder"] = "Instagram / Portfolio URL"
        p["onboarding.form.field.profilePhoto.placeholder"]         = "Upload from library or take a photo"
        p["onboarding.form.field.profilePhoto.help"]                = "Any file format supported"
        p["onboarding.form.field.logoPhoto.placeholder"]            = "Upload logo or take a photo"
        p["onboarding.form.field.logoPhoto.help"]                   = "Any file format supported"

        // Gender
        p["onboarding.form.gender.option.female"]        = "Female"
        p["onboarding.form.gender.option.male"]          = "Male"
        p["onboarding.form.gender.option.nonbinary"]     = "Non-binary"
        p["onboarding.form.gender.option.preferNotToSay"] = "Prefer not to say"

        // Form progress
        for total in 2...4 {
            for i in 1...total {
                p["onboarding.form.progress.\(i)of\(total)"] = "Step \(i) of \(total)"
            }
        }

        return p
    }()
}
