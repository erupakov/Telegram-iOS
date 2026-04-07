import Foundation

public struct UserDetailResponse: Decodable {
    public let message: String?
    public let data: UserDetail
    public let errors: [String]?
}

public struct UserDetail: Decodable {
    public let id: Int
    public let fullName: String?
    public let gender: UserGender?
    public let birthday: String?
    public let city: UserCity?
    public let email: String?
    public let phone: String?
    public let photo: UserFile?
    public let avatar: UserFile?
    public let role: String?
    public let subrole: String?
    public let roleLabel: String?
    public let measuringSystem: String?
    public let pushNotifications: Bool?
    public let isRegistrationFinished: Bool?
    public let model: UserModelInfo?
    public let customer: UserCustomerInfo?
    public let agency: UserAgencyInfo?
    public let agencyEmployee: UserAgencyEmployeeInfo?
    public let statistic: UserStatistic?
    public let isFavorite: Bool?
    public let isFollowed: Bool?
    public let userRatingStatus: String?
    public let userSocialNetworks: [UserSocialNetwork]?
}

public struct UserGender: Decodable {
    public let id: String
    public let title: String
}

public struct UserCity: Decodable {
    public let id: Int
    public let countryCode: String?
    public let countryName: String?
    public let areaName: String?
    public let name: String?
}

public struct UserFile: Decodable {
    public let fileName: String?
    public let fullUrl: String?
    public let fileExtension: String?
    public let fileUuid: String?

    enum CodingKeys: String, CodingKey {
        case fileName, fullUrl
        case fileExtension = "extension"
        case fileUuid
    }

    public init(fileName: String?, fullUrl: String?, fileExtension: String?, fileUuid: String?) {
        self.fileName = fileName
        self.fullUrl = fullUrl
        self.fileExtension = fileExtension
        self.fileUuid = fileUuid
    }
}

public struct LinksData {
    public let tiktokUrl: String?
    public let youtubeUrl: String?
    public let telegramUrl: String?
    public let instagramUrl: String?
    public let websiteUrl: String?

    public init(tiktokUrl: String?, youtubeUrl: String?, telegramUrl: String?, instagramUrl: String?, websiteUrl: String?) {
        self.tiktokUrl = tiktokUrl
        self.youtubeUrl = youtubeUrl
        self.telegramUrl = telegramUrl
        self.instagramUrl = instagramUrl
        self.websiteUrl = websiteUrl
    }
}

public struct UpdateSocialLinksRequest: Encodable {
    public let model: ModelData

    public struct ModelData: Encodable {
        public let tiktokUrl: String?
        public let youtubeUrl: String?
        public let telegramUrl: String?
        public let instagramUrl: String?
        public let websiteUrl: String?

        public init(tiktokUrl: String?, youtubeUrl: String?, telegramUrl: String?, instagramUrl: String?, websiteUrl: String?) {
            self.tiktokUrl = tiktokUrl
            self.youtubeUrl = youtubeUrl
            self.telegramUrl = telegramUrl
            self.instagramUrl = instagramUrl
            self.websiteUrl = websiteUrl
        }
    }

    public init(model: ModelData) {
        self.model = model
    }
}

public struct UpdateSocialLinksResponse: Decodable {
    public let message: String?
    public let data: UserDetail?
    public let errors: [String]?

    public init(message: String?, data: UserDetail?, errors: [String]?) {
        self.message = message
        self.data = data
        self.errors = errors
    }
}

public struct UserModelInfo: Decodable {
    public let agency: UserAgencyInfo?
    public let education: String?
    public let workExperience: String?
    public let languages: String?
    public let profileUrl: String?
    public let description: String?
    public let tiktokUrl: String?
    public let youtubeUrl: String?
    public let telegramUrl: String?
    public let instagramUrl: String?
    public let websiteUrl: String?
    public let additionalInformation: String?
    public let hasInternationalPassport: Bool?
    public let hasTattoo: Bool?
    public let hasPiercing: Bool?
    public let hasActingEducation: Bool?
    public let appearance: UserAppearance?
}

public struct UserAgencyRef: Decodable {
    public let id: Int?
    public let name: String?
}

public struct UserAppearance: Decodable {
    public let measuringSystem: String?
    public let height: Double?
    public let weight: Double?
    public let breastSize: String?
    public let waist: Double?
    public let hips: Double?
    public let shoesSize: Double?
    public let hairColor: UserColorOption?
    public let hairLength: UserColorOption?
    public let eyeColor: UserColorOption?
    public let skinColor: UserColorOption?
}

public struct UserColorOption: Decodable {
    public let id: Int?
    public let title: String?
}

public struct UserCustomerInfo: Decodable {
    public let companyName: String?
}

public struct UserAgencyInfo: Decodable {
    public let id: Int?
    public let title: String?
    public let site: String?
    public let email: String?
    public let description: String?
    public let employeeTitle: String?
    public let address: AgencyAddress?
    public let photo: UserFile?
    public let background: UserFile?
}

public struct AgencyAddress: Decodable {
    public let street: String?
    public let house: String?
    public let apartment: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let city: UserCity?
}
public struct UserAgencyEmployeeInfo: Decodable {
    public let agencyId: Int?
    public let position: String?
}

public struct UserStatistic: Decodable {
    public let followersCount: Int?
    public let followingCount: Int?
    public let viewsCount: Int?
    public let sentToAgenciesCount: Int?
    public let modelsCount: Int?
}

public struct UserSocialNetwork: Decodable {
    public let id: Int?
    public let type: String?
    public let url: String?
    public let username: String?
}

public extension Double {
    var clean: String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }
}

public struct UpdateBiographyPageRequest: Encodable {
    public let fullName: String?
    public let gender: String?
    public let model: ModelData?
    public let avatar: AvatarUuid?
    public let photo: AvatarUuid?

    public struct AvatarUuid: Encodable {
        public let uuid: String
        public init(uuid: String) { self.uuid = uuid }
    }

    public struct ModelData: Encodable {
        public let description: String?
        public let appearance: Appearance?
        public init(description: String?, appearance: Appearance?) {
            self.description = description
            self.appearance = appearance
        }
    }

    public init(fullName: String? = nil, gender: String? = nil, model: ModelData? = nil, avatar: AvatarUuid? = nil, photo: AvatarUuid? = nil) {
        self.fullName = fullName
        self.gender = gender
        self.model = model
        self.avatar = avatar
        self.photo = photo
    }
}

public struct UpdateBiographyPageResponse: Decodable {
    public let message: String?
    public let data: UserDetail?
    public let errors: [String]?

    public init(message: String?, data: UserDetail?, errors: [String]?) {
        self.message = message
        self.data = data
        self.errors = errors
    }
}

public struct GenderResponse: Codable {
    public let data: [GenderOption]
}

public struct GenderOption: Codable {
    public let id: String
    public let title: String
}

public struct AgencyListRequest: Encodable {
    public let offset: Int
    public let limit: Int
    public let title: String?

    public init(offset: Int, limit: Int, title: String?) {
        self.offset = offset
        self.limit = limit
        self.title = title
    }
}

public struct AgencyListResponse: Decodable {
    public let message: String?
    public let data: AgencyListData
    public let errors: [String]?
}

public struct AgencyListData: Decodable {
    public let items: [AgencyItem]
    public let pagination: Pagination
}

public struct AgencyItem: Decodable {
    public let id: Int
    public let title: String
}

public struct AppearanceDictionaryResponse: Codable {
    public let data: AppearanceDictionaryData
}

public struct AppearanceDictionaryData: Codable {
    public let hairLength: [AppearanceOption]
    public let hairColor:[AppearanceOption]
    public let eyeColor: [AppearanceOption]
    public let skinColor:[AppearanceOption]
}

public struct AppearanceOption: Codable {
    public let id: Int
    public let title: String
}


// MARK: - API Models for Engagement

public struct UserEngagementResponse: Decodable {
    public let data: UserEngagementData?
}

public struct UserEngagementData: Decodable {
    public let liked: EngagementCategoryData?
    public let viewed: EngagementCategoryData?
    public let followed: EngagementCategoryData?
}

public struct EngagementCategoryData: Decodable {
    public let items: [EngagementItem]?
    public let pagination: EngagementPagination?
}

public struct EngagementPagination: Decodable {
    public let meta: PaginationDetails?
    public let total: Int?
    public let offset: Int?
    public let limit: Int?
}

public struct PaginationDetails: Decodable {
    public let limit: Int?
    public let currentOffset: Int?
    public let totalCount: Int?
}

public struct EngagementItem: Decodable {
    public let id: Int?
    public let fullName: String?
    public let role: String?
    public let roleLabel: String?
    public let avatar: UserFile?
}

public struct FileUploadRequest: Codable {
    public let file: Data
}

public struct FileUploadResponse: Decodable {
    public let message: String?
    public let data: FileUploadData?
    public let errors: String?
}

public struct FileUploadData: Decodable {
    public let uuid: String?
    public let status: String?
    public let fileName: String?
    public let fullUrl: String?
    public let extensionFile: String?
    public let type: String?
    
    private enum CodingKeys: String, CodingKey {
        case uuid, status, fileName, fullUrl, type
        case extensionFile = "extension"
    }
}

public struct AddGalleryRequest: Codable {
    public let uuid: String
    
    public init(uuid: String) {
        self.uuid = uuid
    }
}

public struct AddGalleryResponse: Decodable {
    public let message: String?
    public let data: UserPhoto?
    public let errors: String?
}

// MARK: - Agency Models List

public struct AgencyModelsResponse: Decodable {
    public let message: String?
    public let data: AgencyModelsData?
}

public struct AgencyModelsData: Decodable {
    public let items: [AgencyModelItem]
    public let pagination: AgencyModelsPagination?
}

public struct AgencyModelItem: Decodable {
    public let id: Int
    public let name: String?
    public let birthday: String?
    public let photo: UserFile?
    public let city: UserCity?
    public let userId: Int?
}

public struct AgencyModelsPagination: Decodable {
    public let meta: AgencyModelsPaginationMeta?
}

public struct AgencyModelsPaginationMeta: Decodable {
    public let limit: Int?
    public let currentOffset: Int?
    public let totalCount: Int?
}

public struct AgencyModelsListRequest: Encodable {
    public let offset: Int
    public let limit: Int
    public init(offset: Int, limit: Int) {
        self.offset = offset
        self.limit = limit
    }
}

public struct UpdateDescriptionAgencyRequest: Encodable {
    public let agencyId: Int?
    public let description: String?
    public let background: AvatarUuid?
    public let photo: AvatarUuid?

    public struct AvatarUuid: Encodable {
        public let uuid: String
        public init(uuid: String) { self.uuid = uuid }
    }

    public init(agencyId: Int?, description: String? = nil, background: AvatarUuid? = nil, photo: AvatarUuid? = nil) {
        self.agencyId = agencyId
        self.description = description
        self.background = background
        self.photo = photo
    }
}

public struct UpdateDescriptionAgencyResponse: Decodable {
    public let message: String?
    public let data: String?
    public let errors: [String]?

    public init(message: String?, data: String?, errors: [String]?) {
        self.message = message
        self.data = data
        self.errors = errors
    }
}
