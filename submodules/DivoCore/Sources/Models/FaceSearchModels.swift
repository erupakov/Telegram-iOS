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
    public let image: String?
    public let index: Int?
    public let rank: Int?
    public let score: Double
}
