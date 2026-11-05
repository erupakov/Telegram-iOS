import Foundation

public enum Role {
    case model
    case newFace
    case agency
    case fan

    public init(apiRole: String?) {
        switch apiRole {
        case "agency_employee": self = .agency
        case "new_face":        self = .newFace
        case "fan":             self = .fan
        default:                self = .model
        }
    }

    /// Название подроли бэкенда (`subrole`, например `ai_creator`) — там, где бэкенд не отдаёт `roleLabel`
    /// (результаты Face Match). Неизвестная подроль → nil.
    public static func subroleTitle(_ subrole: String?) -> String? {
        switch subrole {
        case "ai_creator": return DivoStrings.onboardingRoleDancer
        case "new_talent": return DivoStrings.onboardingRoleNewTalent
        case "actor": return DivoStrings.onboardingRoleActor
        case "singer": return DivoStrings.onboardingRoleSingerPerformer
        case "photographer": return DivoStrings.onboardingRolePhotographer
        case "stylist": return DivoStrings.onboardingRoleStylist
        case "mua": return DivoStrings.onboardingRoleMakeupArtist
        case "hair_stylist": return DivoStrings.onboardingRoleHairStylist
        case "fashion_designer": return DivoStrings.onboardingRoleFashionDesigner
        case "videographer": return DivoStrings.onboardingRoleVideographer
        case "creative_director": return DivoStrings.onboardingRoleCreativeDirector
        case "studio": return DivoStrings.onboardingRoleStudioLocation
        default: return nil
        }
    }

    public var title: String {
        switch self {
        case .model: DivoStrings.roleModel
        case .newFace: DivoStrings.roleNewFace
        case .agency: DivoStrings.roleAgency
        case .fan: DivoStrings.roleFan
        }
    }
}