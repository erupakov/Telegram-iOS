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
/// При добавлении нового ключа: дописываем property в `DivoStrings.swift` под MARK-секцией
/// `// MARK: - Onboarding — …` (с 5 языками через `L(en:ru:es:pt:zh:)`) и case в `mappedFromDivoStrings(_:)`.
/// Если case забыт — `resolve` вернёт сам key (например, `"onboarding.role.foo.name"`), что сразу
/// видно в UI как сигнал «забыли смапить».
public enum OnboardingStrings {

    public static func resolve(_ key: String) -> String {
        return mappedFromDivoStrings(key) ?? key
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
        case "onboarding.quiz.topLevel.subtitle":                                return DivoStrings.onboardingQuizTopLevelSubtitle
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
        case "onboarding.quiz.talentPicker.title":              return DivoStrings.onboardingQuizTalentPickerTitle
        case "onboarding.quiz.talentPicker.subtitle":           return DivoStrings.onboardingQuizTalentPickerSubtitle
        case "onboarding.quiz.talentPicker.section.talents":    return DivoStrings.onboardingQuizTalentPickerSectionTalents
        case "onboarding.quiz.talentPicker.section.creative":   return DivoStrings.onboardingQuizTalentPickerSectionCreative
        case "onboarding.quiz.industryProPicker.title":         return DivoStrings.onboardingQuizIndustryProPickerTitle
        case "onboarding.quiz.industryProPicker.subtitle":      return DivoStrings.onboardingQuizIndustryProPickerSubtitle
        case "onboarding.quiz.companiesPicker.title":           return DivoStrings.onboardingQuizCompaniesPickerTitle
        case "onboarding.quiz.companiesPicker.subtitle":        return DivoStrings.onboardingQuizCompaniesPickerSubtitle
        case "onboarding.quiz.experience.title":             return DivoStrings.onboardingQuizExperienceTitle
        case "onboarding.quiz.experience.subtitle":          return DivoStrings.onboardingQuizExperienceSubtitle
        case "onboarding.quiz.experience.option.yes.title":      return DivoStrings.onboardingQuizExperienceOptionYesTitle
        case "onboarding.quiz.experience.option.yes.subtitle":   return DivoStrings.onboardingQuizExperienceOptionYesSubtitle
        case "onboarding.quiz.experience.option.no.title":       return DivoStrings.onboardingQuizExperienceOptionNoTitle
        case "onboarding.quiz.experience.option.no.subtitle":    return DivoStrings.onboardingQuizExperienceOptionNoSubtitle

        // MARK: Role names
        case "onboarding.role.modelingAgency.name":               return DivoStrings.onboardingRoleModelingAgency
        case "onboarding.role.modelingAgency.name.subtitle":      return DivoStrings.onboardingRoleModelingAgencySubtitle
        case "onboarding.role.fashionBrand.name":                 return DivoStrings.onboardingRoleFashionBrand
        case "onboarding.role.fashionBrand.name.subtitle":        return DivoStrings.onboardingRoleFashionBrandSubtitle
        case "onboarding.role.brandOrBusiness.name":              return DivoStrings.onboardingRoleBrandOrBusiness
        case "onboarding.role.brandOrBusiness.name.subtitle":     return DivoStrings.onboardingRoleBrandOrBusinessSubtitle
        case "onboarding.role.beautyBrand.name":                  return DivoStrings.onboardingRoleBeautyBrand
        case "onboarding.role.beautyBrand.name.subtitle":         return DivoStrings.onboardingRoleBeautyBrandSubtitle
        case "onboarding.role.eventAgency.name":                  return DivoStrings.onboardingRoleEventAgency
        case "onboarding.role.eventAgency.name.subtitle":         return DivoStrings.onboardingRoleEventAgencySubtitle
        case "onboarding.role.magazinePublication.name":          return DivoStrings.onboardingRoleMagazineMedia
        case "onboarding.role.magazinePublication.name.subtitle": return DivoStrings.onboardingRoleMagazineMediaSubtitle
        case "onboarding.role.scout.name":                        return DivoStrings.onboardingRoleScout
        case "onboarding.role.scout.subtitle":                    return DivoStrings.onboardingRoleScoutSubtitle
        case "onboarding.role.booker.name":                       return DivoStrings.onboardingRoleBooker
        case "onboarding.role.booker.subtitle":                   return DivoStrings.onboardingRoleBookerSubtitle
        case "onboarding.role.castingDirector.name":              return DivoStrings.onboardingRoleCastingDirector
        case "onboarding.role.castingDirector.subtitle":          return DivoStrings.onboardingRoleCastingDirectorSubtitle
        case "onboarding.role.talentManager.name":                return DivoStrings.onboardingRoleTalentManager
        case "onboarding.role.talentManager.subtitle":            return DivoStrings.onboardingRoleTalentManagerSubtitle
        case "onboarding.role.photographer.name":                 return DivoStrings.onboardingRolePhotographer
        case "onboarding.role.stylist.name":                      return DivoStrings.onboardingRoleStylist
        case "onboarding.role.makeupArtist.name":                 return DivoStrings.onboardingRoleMakeupArtist
        case "onboarding.role.hairStylist.name":                  return DivoStrings.onboardingRoleHairStylist
        case "onboarding.role.videographer.name":                 return DivoStrings.onboardingRoleVideographer
        case "onboarding.role.creativeDirector.name":             return DivoStrings.onboardingRoleCreativeDirector
        case "onboarding.role.fashionDesigner.name":              return DivoStrings.onboardingRoleFashionDesigner
        case "onboarding.role.studioLocation.name":               return DivoStrings.onboardingRoleStudioLocation
        case "onboarding.role.model.name":                        return DivoStrings.onboardingRoleModel
        case "onboarding.role.newTalent.name":                    return DivoStrings.onboardingRoleNewTalent
        case "onboarding.role.actor.name":                        return DivoStrings.onboardingRoleActor
        case "onboarding.role.dancer.name":                       return DivoStrings.onboardingRoleDancer
        case "onboarding.role.singerPerformer.name":              return DivoStrings.onboardingRoleSingerPerformer
        case "onboarding.role.fan.name":                          return DivoStrings.onboardingRoleFan

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
        case "onboarding.form.field.dateOfBirth.title":                return DivoStrings.onboardingFieldDateOfBirthTitle
        case "onboarding.form.field.dateOfBirth.placeholder":          return DivoStrings.onboardingFieldDateOfBirthPlaceholder
        case "onboarding.form.field.gender.title":                     return DivoStrings.paramGender
        case "onboarding.form.field.gender.placeholder":               return DivoStrings.onboardingFieldGenderPlaceholder
        case "onboarding.form.field.country.title":                    return DivoStrings.onboardingFieldCountryTitle
        case "onboarding.form.field.city.title":                       return DivoStrings.onboardingFieldCityPlaceholder
        case "onboarding.form.field.country.placeholder":              return DivoStrings.chooseCountry
        case "onboarding.form.field.city.placeholder":                 return DivoStrings.chooseCity
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
        case "onboarding.form.4A.companyType.title":                     return DivoStrings.onboardingForm4ACompanyTypeTitle
        case "onboarding.form.4A.companyType.placeholder":               return DivoStrings.onboardingForm4ACompanyTypePlaceholder
        case "onboarding.form.4A.step2.title":                           return DivoStrings.onboardingForm4AStep2Title
        case "onboarding.form.4A.step3.title":                           return DivoStrings.onboardingForm4AStep3Title
        case "onboarding.form.4A.websiteUrl.placeholder":                return DivoStrings.onboardingForm4AWebsiteUrlPlaceholder
        case "onboarding.form.4A.websiteUrl.help":                       return DivoStrings.onboardingForm4AWebsiteUrlHelp
        case "onboarding.form.4A.contactFirstName.placeholder":          return DivoStrings.onboardingForm4AContactFirstNamePlaceholder
        case "onboarding.form.4A.contactLastName.placeholder":           return DivoStrings.onboardingForm4AContactLastNamePlaceholder
        case "onboarding.form.4A.contactRole.placeholder":               return DivoStrings.onboardingForm4AContactRolePlaceholder
        case "onboarding.form.4A.step4.title":                           return DivoStrings.onboardingForm4AStep4Title

        // MARK: Form 4.B
        case "onboarding.form.4B.title":            return DivoStrings.onboardingForm4BTitle
        case "onboarding.form.4B.step1.title":      return DivoStrings.onboardingForm4BStep1Title
        case "onboarding.form.4B.role.title":       return DivoStrings.onboardingForm4BRoleTitle
        case "onboarding.form.4B.role.placeholder": return DivoStrings.onboardingForm4BRolePlaceholder
        case "onboarding.form.4B.step3.title":      return DivoStrings.onboardingForm4BStep3Title
        case "onboarding.form.4B.agency.placeholder": return DivoStrings.onboardingForm4BAgencyPlaceholder
        case "onboarding.form.4B.agency.help":      return DivoStrings.onboardingForm4BAgencyHelp

        // MARK: Form 4.C1
        case "onboarding.form.4C1.title":                       return DivoStrings.onboardingForm4C1Title
        case "onboarding.form.4C1.step1.title":                 return DivoStrings.onboardingForm4C1Step1Title
        case "onboarding.form.4C1.specialisation.title":        return DivoStrings.onboardingForm4C1SpecialisationTitle
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
        case "onboarding.form.4D2.title":             return DivoStrings.onboardingForm4D2Title
        case "onboarding.form.4D2.step3.title":       return DivoStrings.onboardingForm4D2Step3Title
        case "onboarding.form.4D2.step4.title":       return DivoStrings.onboardingForm4D2Step4Title
        case "onboarding.form.4D2.tfp.hint.title":    return DivoStrings.onboardingForm4D2TfpHintTitle
        case "onboarding.form.4D2.tfp.hint.subtitle": return DivoStrings.onboardingForm4D2TfpHintSubtitle

        // MARK: Form 4.D3
        case "onboarding.form.4D3.title":                          return DivoStrings.onboardingForm4D3Title
        case "onboarding.form.4D3.step3.title":                    return DivoStrings.onboardingForm4D3Step3Title
        case "onboarding.form.4D3.specialisation.title":     return DivoStrings.onboardingForm4D3SpecialisationTitle
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

}
