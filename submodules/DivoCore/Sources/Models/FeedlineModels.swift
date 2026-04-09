import Foundation

public struct FeedlineListRequest: Encodable {
    public let offset: Int
    public let limit: Int
    public let subscribedOnly: Bool?
    public let modelsOnly: Bool?

    public init(offset: Int, limit: Int, subscribedOnly: Bool? = nil, modelsOnly: Bool? = nil) {
        self.offset = offset
        self.limit = limit
        self.subscribedOnly = subscribedOnly
        self.modelsOnly = modelsOnly
    }
}

public struct FeedlineResponse: Decodable {
    public let message: String?
    public let data: FeedlineData
}

public struct FeedlineData: Decodable {
    public let items: [FeedlineItem]
}

public struct FeedlineItem: Decodable {
    public let id: Int
    public let feedId: Int
    public let title: String
    public let description: String?
    public let entity: String
    public let type: String
    public let likesCount: Int
    public let isLikedByUser: Bool
    public let isFavoriteByUser: Bool
    public let user: FeedlineUser
    public let files: [FeedlineFile]
    public let searchImage: FeedlineFile?

    private enum CodingKeys: String, CodingKey {
        case id, feedId, title, description, entity, type
        case likesCount, isLikedByUser, isFavoriteByUser
        case user, files, searchImage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        feedId = try container.decode(Int.self, forKey: .feedId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        entity = try container.decode(String.self, forKey: .entity)
        type = try container.decode(String.self, forKey: .type)
        likesCount = try container.decode(Int.self, forKey: .likesCount)
        isLikedByUser = try container.decode(Bool.self, forKey: .isLikedByUser)
        isFavoriteByUser = try container.decode(Bool.self, forKey: .isFavoriteByUser)
        user = try container.decode(FeedlineUser.self, forKey: .user)
        searchImage = try container.decodeIfPresent(FeedlineFile.self, forKey: .searchImage)

        let decodedFiles = try container.decodeIfPresent([FeedlineFile].self, forKey: .files) ?? []
        files = Self.normalizedFiles(decodedFiles, fallback: searchImage)
    }

    private static func normalizedFiles(_ files: [FeedlineFile], fallback: FeedlineFile?) -> [FeedlineFile] {
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "heic", "heif", "gif"]
        var sorted = files.sorted {
            let lhsIsImage = imageExtensions.contains($0.fileExtension.lowercased())
            let rhsIsImage = imageExtensions.contains($1.fileExtension.lowercased())
            if lhsIsImage != rhsIsImage {
                return lhsIsImage
            }
            return $0.order < $1.order
        }

        if sorted.isEmpty, let fallback {
            sorted = [fallback]
        }
        return sorted
    }
}

public struct FeedlineUser: Codable {
    public let id: Int
    public let fullName: String
    public let role: String
    public let subrole: String?
    public let roleLabel: String
}

public struct FeedlineFile: Codable {
    public let order: Int
    public let fullName: String
    public let fullUrl: String
    public let fileExtension: String
    public let videoThumbnail: String?
    public let fileUuid: String

    enum CodingKeys: String, CodingKey {
        case order, fullName, fullUrl
        case fileExtension = "extension"
        case videoThumbnail, fileUuid
    }
}

public struct FeedlineSearchEventsRequest: Encodable {
    public let offset: Int
    public let limit: Int
    public let isEvents: Bool

    public init(offset: Int, limit: Int, isEvents: Bool) {
        self.offset = offset
        self.limit = limit
        self.isEvents = isEvents
    }
}

public struct FollowRequest: Encodable {
    public let id: Int
    public init(id: Int) { self.id = id }
}

public struct FollowResponse: Decodable {
    public let message: String?
    public let errors: String?
}
