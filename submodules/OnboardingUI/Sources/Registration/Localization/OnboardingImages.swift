import UIKit
import DivoCore
import DivoUIKit

public enum OnboardingImages {

    public static func resolve(_ key: String) -> UIImage {
        return mappedFromDivoImage(key)
    }

    private static func mappedFromDivoImage(_ key: String) -> UIImage {
        switch key {
            
        case "onboarding.result.image.model":                        return DivoImage.onboardingResultsModel
        case "onboarding.result.image.talent":                       return DivoImage.onboardingResultsTalent
        case "onboarding.result.image.actor":                        return DivoImage.onboardingResultsActor
        case "onboarding.result.image.dancer":                       return DivoImage.onboardingResultsDancer
        case "onboarding.result.image.performer":                    return DivoImage.onboardingResultsPerformer
        case "onboarding.result.image.creative.professional":        return DivoImage.onboardingResultsCreativeProfessional
        case "onboarding.result.image.find.talent":                  return DivoImage.onboardingResultsFindTalent
        case "onboarding.result.image.talent.industry.professional": return DivoImage.onboardingResultsTalentIndustryProfessional
        case "onboarding.result.image.fashion.fan":                  return DivoImage.onboardingResultsFashionFan
            
        case "onboarding.quiz.topLevel.option.circle":  return DivoImage.largecircleFillCircle
            
        case "onboarding.role.model.name":               return DivoImage.onboardingRoleModel
        case "onboarding.role.actor.name":               return DivoImage.onboardingRoleActorActress
        case "onboarding.role.dancer.name":              return DivoImage.onboardingRoleDancer
        case "onboarding.role.singerPerformer.name":     return DivoImage.onboardingRoleSingerPerformer
        case "onboarding.role.photographer.name":        return DivoImage.onboardingRolePhotographer
        case "onboarding.role.stylist.name":             return DivoImage.onboardingRoleStylist
        case "onboarding.role.makeupArtist.name":        return DivoImage.onboardingRoleMakeupArtist
        case "onboarding.role.hairStylist.name":         return DivoImage.onboardingRoleHairStylist
        case "onboarding.role.videographer.name":        return DivoImage.onboardingRoleVideographer
        case "onboarding.role.creativeDirector.name":    return DivoImage.onboardingRoleCreativeDirector
        case "onboarding.role.fashionDesigner.name":     return DivoImage.onboardingRoleFashionDesigner
        case "onboarding.role.studioLocation.name":      return DivoImage.onboardingRoleStudioLocation
            
        default:
            return UIImage()
        }
    }
}
