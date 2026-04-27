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

public struct FRBoundingBox: Decodable {
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
    public let image: String?
    public let index: Int?
    public let rank: Int?
    public let score: Double

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
        case birthday
        case cityId = "city_id"
        case image
        case index
        case rank
        case score
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        let rawBirthday = try container.decodeIfPresent(String.self, forKey: .birthday)
        self.birthday = (rawBirthday == "null") ? nil : rawBirthday
        self.cityId = try container.decodeIfPresent(Int.self, forKey: .cityId)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
        self.index = try container.decodeIfPresent(Int.self, forKey: .index)
        self.rank = try container.decodeIfPresent(Int.self, forKey: .rank)
        self.score = try container.decode(Double.self, forKey: .score)
    }
}
