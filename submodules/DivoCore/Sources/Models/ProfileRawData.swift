import Foundation

// Здесь остались только живые типы профиля. `Appearance` использует `UserDetail` (UserDetailModels);
// `File`/`Model` оставлены консервативно. Мёртвые ProfileRawData/UpdateProfileRequest(+хелперы) удалены.

public struct File: Codable {
    public let uuid: String

    public init(uuid: String) {
        self.uuid = uuid
    }
}

public struct Model: Codable {
    public let agencyId: Int?
    public let profileUrl: String?
    public let education: String?
    public let workExperience: String?
    public let languages: String?
    public let hasInternationalPassport: Bool
    public let hasTattoo: Bool
    public let hasPiercing: Bool
    public let hasActingEducation: Bool
    public let appearance: Appearance

    public init(
        agencyId: Int?,
        profileUrl: String?,
        education: String?,
        workExperience: String?,
        languages: String?,
        hasInternationalPassport: Bool,
        hasTattoo: Bool,
        hasPiercing: Bool,
        hasActingEducation: Bool,
        appearance: Appearance
    ) {
        self.agencyId = agencyId
        self.profileUrl = profileUrl
        self.education = education
        self.workExperience = workExperience
        self.languages = languages
        self.hasInternationalPassport = hasInternationalPassport
        self.hasTattoo = hasTattoo
        self.hasPiercing = hasPiercing
        self.hasActingEducation = hasActingEducation
        self.appearance = appearance
    }
}

public struct Appearance: Codable {
    public let measuringSystem: String?
    public let height: Double?
    public let weight: Double?
    public let breastSize: String?
    public let waist: Double?
    public let hips: Double?
    public let shoesSize: Double?
    public let hairColor: Int?
    public let hairLength: Int?
    public let eyeColor: Int?
    public let skinColor: Int?

    public init(
        measuringSystem: String?,
        height: Double?,
        weight: Double?,
        breastSize: String?,
        waist: Double?,
        hips: Double?,
        shoesSize: Double?,
        hairColor: Int?,
        hairLength: Int?,
        eyeColor: Int?,
        skinColor: Int?
    ) {
        self.measuringSystem = measuringSystem
        self.height = height
        self.weight = weight
        self.breastSize = breastSize
        self.waist = waist
        self.hips = hips
        self.shoesSize = shoesSize
        self.hairColor = hairColor
        self.hairLength = hairLength
        self.eyeColor = eyeColor
        self.skinColor = skinColor
    }
}
