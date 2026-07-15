import Foundation

// MARK: - Detect

public struct FRDetectResponse: Decodable {
    public let faces: [FRFace]
}

public struct FRFace: Decodable {
    public let area: Double
    public let bbox: FRBoundingBox
    public let index: Int
}

public struct FRBoundingBox: Codable, Equatable {
    public let x1: Double
    public let x2: Double
    public let y1: Double
    public let y2: Double
}

// MARK: - Search

public struct FRSearchResponse: Decodable {
    public let bbox: FRBoundingBox
    public let faceInfo: FRFaceInfo
    public let results: [FRSearchResult]

    private enum CodingKeys: String, CodingKey {
        case bbox
        case faceInfo = "face_info"
        case results
    }
}

public struct FRFaceInfo: Decodable {
    public let age: String?
    public let emotion: String?
    public let gender: String?
    public let race: String?
}

public struct FRSearchResult: Decodable {
    public let userId: Int?
    public let fullName: String?
    public let birthday: String?
    public let cityId: Int?
    public let countryCode: String?
    public let countryName: String?
    public let gender: String?
    public let image: String?
    public let index: Int?
    public let photoId: Int?
    public let rating: String?
    public let role: String?
    public let subrole: String?
    public let rank: Int?
    public let score: Double
    public let isFollowedByUser: Bool?

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
        case birthday
        case cityId = "city_id"
        case countryCode = "country_code"
        case countryName = "country_name"
        case gender
        case image
        case index
        case photoId = "photo_id"
        case rating
        case role
        case subrole
        case rank
        case score
        case isFollowedByUser
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        let rawBirthday = try container.decodeIfPresent(String.self, forKey: .birthday)
        self.birthday = (rawBirthday == "null") ? nil : rawBirthday
        self.cityId = try container.decodeIfPresent(Int.self, forKey: .cityId)
        self.countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        self.countryName = try container.decodeIfPresent(String.self, forKey: .countryName)
        self.gender = try container.decodeIfPresent(String.self, forKey: .gender)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
        self.index = try container.decodeIfPresent(Int.self, forKey: .index)
        self.photoId = try container.decodeIfPresent(Int.self, forKey: .photoId)
        self.rating = try container.decodeIfPresent(String.self, forKey: .rating)
        self.role = try container.decodeIfPresent(String.self, forKey: .role)
        self.subrole = try container.decodeIfPresent(String.self, forKey: .subrole)
        self.rank = try container.decodeIfPresent(Int.self, forKey: .rank)
        self.score = try container.decode(Double.self, forKey: .score)
        self.isFollowedByUser = try container.decodeIfPresent(Bool.self, forKey: .isFollowedByUser)
    }
}
