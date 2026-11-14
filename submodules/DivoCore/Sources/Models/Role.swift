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
/// Опыт работы (история мест работы) ведут только «нанимаемые» участники — модели и таланты.
/// У «нанимающих» (агентства, бренды, компании, индустриальные профи — все с бэк-ролью `agency_employee`)
/// раздела и возможности добавлять опыт нет.
public enum DivoWorkExperience {
    /// - Parameters:
    ///   - profileRole: бэк-роль профиля, который открыт (может быть nil/пустой, пока профиль не загрузился).
    ///   - isMyProfile: свой ли профиль — для него дополнительно смотрим роль текущей сессии.
    public static func isAllowed(profileRole: String?, isMyProfile: Bool) -> Bool {
        if Role(apiRole: profileRole) == .agency {
            return false
        }
        if isMyProfile && DivoConfig.currentUserRole == .agency {
            return false
        }
        return true
    }
}

/// Подпись роли из бэка (`roleLabel`) для показа. Бэк для роли `new_face` без подроли отдаёт «New Face» /
/// «Новое Лицо» — в приложении эта роль называется «Талант» (как вкладка ленты), поэтому такие подписи
/// подменяем локализованным `roleNewFace`. Остальные подписи (подроли: «Photographer», «AI creator»…) — как есть.
public enum DivoRoleLabel {
    private static let legacyNewFaceLabels: Set<String> = [
        "new face", "new faces", "новое лицо", "новые лица", "nueva cara", "cara nueva", "rosto novo", "nouveau visage", "新面孔",
    ]

    public static func display(_ label: String?) -> String? {
        guard let label else { return nil }
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return legacyNewFaceLabels.contains(normalized) ? DivoStrings.roleNewFace : label
    }
}
