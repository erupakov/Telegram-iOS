import Foundation

public struct ProfileRawData: Codable {
    public let fullName: String?
    public let phone: String?
    public let timezone: String
    public let gender: String
    public let birthday: String
    public let geoCityId: Int
    public let measuringSystem: String
    public let subrole: String?
    public let pushNotifications: Bool
    public let isRegistrationFinished: Bool
    public let photo: File?
    public let avatar: File?
    public let model: Model?
    public let customer: Customer?

    public init(
        fullName: String?,
        phone: String?,
        timezone: String,
        gender: String,
        birthday: String,
        geoCityId: Int,
        measuringSystem: String,
        subrole: String?,
        pushNotifications: Bool,
        isRegistrationFinished: Bool,
        photo: File?,
        avatar: File?,
        model: Model?,
        customer: Customer?
    ) {
        self.fullName = fullName
        self.phone = phone
        self.timezone = timezone
        self.gender = gender
        self.birthday = birthday
        self.geoCityId = geoCityId
        self.measuringSystem = measuringSystem
        self.subrole = subrole
        self.pushNotifications = pushNotifications
        self.isRegistrationFinished = isRegistrationFinished
        self.photo = photo
        self.avatar = avatar
        self.model = model
        self.customer = customer
    }
}

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
    public let measuringSystem: String
    public let height: Double
    public let weight: Double?
    public let breastSize: String?
    public let waist: Double
    public let hips: Double
    public let shoesSize: Double
    public let hairColor: Int
    public let hairLength: Int
    public let eyeColor: Int
    public let skinColor: Int

    public init(
        measuringSystem: String,
        height: Double,
        weight: Double?,
        breastSize: String?,
        waist: Double,
        hips: Double,
        shoesSize: Double,
        hairColor: Int,
        hairLength: Int,
        eyeColor: Int,
        skinColor: Int
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

public struct Customer: Codable {
    public init() {}
}

public struct UpdateProfileRequest: Encodable {
    public let fullName: String?
    public let phone: String?
    public let timezone: String
    public let gender: String
    public let birthday: String
    public let geoCityId: Int
    public let measuringSystem: String
    public let subrole: String?
    public let pushNotifications: Bool
    public let isRegistrationFinished: Bool
    public let photo: FileRequest?
    public let avatar: FileRequest?
    public let model: ModelRequest?
    public let customer: CustomerRequest?

    public init(
        fullName: String?,
        phone: String?,
        timezone: String,
        gender: String,
        birthday: String,
        geoCityId: Int,
        measuringSystem: String,
        subrole: String?,
        pushNotifications: Bool,
        isRegistrationFinished: Bool,
        photo: FileRequest?,
        avatar: FileRequest?,
        model: ModelRequest?,
        customer: CustomerRequest?
    ) {
        self.fullName = fullName
        self.phone = phone
        self.timezone = timezone
        self.gender = gender
        self.birthday = birthday
        self.geoCityId = geoCityId
        self.measuringSystem = measuringSystem
        self.subrole = subrole
        self.pushNotifications = pushNotifications
        self.isRegistrationFinished = isRegistrationFinished
        self.photo = photo
        self.avatar = avatar
        self.model = model
        self.customer = customer
    }
}

public struct FileRequest: Encodable {
    public let uuid: String

    public init(uuid: String) {
        self.uuid = uuid
    }

    public init?(_ file: File?) {
        guard let uuid = file?.uuid else { return nil }
        self.uuid = uuid
    }
}

public struct ModelRequest: Encodable {
    public let agencyId: Int?
    public let profileUrl: String?
    public let education: String?
    public let workExperience: String?
    public let languages: String?
    public let hasInternationalPassport: Bool
    public let hasTattoo: Bool
    public let hasPiercing: Bool
    public let hasActingEducation: Bool
    public let appearance: AppearanceRequest

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
        appearance: AppearanceRequest
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

public struct AppearanceRequest: Encodable {
    public let measuringSystem: String
    public let height: Double
    public let weight: Double?
    public let breastSize: String?
    public let waist: Double
    public let hips: Double
    public let shoesSize: Double
    public let hairColor: Int
    public let hairLength: Double
    public let eyeColor: Int
    public let skinColor: Int

    public init(
        measuringSystem: String,
        height: Double,
        weight: Double?,
        breastSize: String?,
        waist: Double,
        hips: Double,
        shoesSize: Double,
        hairColor: Int,
        hairLength: Double,
        eyeColor: Int,
        skinColor: Int
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

public struct CustomerRequest: Encodable {
    public let site: String?
    public let description: String?
    public let background: FileRequest?

    public init(
        site: String?,
        description: String?,
        background: FileRequest?
    ) {
        self.site = site
        self.description = description
        self.background = background
    }
}

public struct UpdateProfileResponse: Decodable {
    public let message: String?
    public let data: UserDetail?
    public let errors: [String]?

    public init(
        message: String?,
        data: UserDetail?,
        errors: [String]?
    ) {
        self.message = message
        self.data = data
        self.errors = errors
    }
}

