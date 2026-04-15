import Foundation
import UIKit

struct StoryModel {
    let name: String
    let avatar: UIImage?
    let isLive: Bool
    let isAdd: Bool?
}

struct CardModel {
    let name: String
    var userReaction: ReactionType?

    let userId: Int?
    let role: String?
    let roleLabel: String?
    let mainImageURL: URL?
    let avatarImageURL: URL?
    let previewImageURLs: [URL]
    var likesCount: Int
    let viewsCount: Int
    var savesCount: Int
    let isFavorite: Bool
    var isFollowed: Bool
    let feedId: Int?
    var isLiked: Bool
    let age: Int?
    let country: String?
    let countryFlag: String?

    init(
        name: String,
        userReaction: ReactionType? = nil,
        userId: Int? = nil,
        role: String? = nil,
        roleLabel: String? = nil,
        mainImageURL: URL? = nil,
        avatarImageURL: URL? = nil,
        previewImageURLs: [URL] = [],
        likesCount: Int = 0,
        viewsCount: Int = 0,
        savesCount: Int = 0,
        isFavorite: Bool = false,
        isFollowed: Bool = false,
        feedId: Int? = nil,
        isLiked: Bool = false,
        age: Int? = nil,
        country: String? = nil,
        countryFlag: String? = nil
    ) {
        self.name = name
        self.userReaction = userReaction
        self.userId = userId
        self.role = role
        self.roleLabel = roleLabel
        self.mainImageURL = mainImageURL
        self.avatarImageURL = avatarImageURL
        self.previewImageURLs = previewImageURLs
        self.likesCount = likesCount
        self.viewsCount = viewsCount
        self.savesCount = savesCount
        self.isFavorite = isFavorite
        self.isFollowed = isFollowed
        self.feedId = feedId
        self.isLiked = isLiked
        self.age = age
        self.country = country
        self.countryFlag = countryFlag
    }
}

enum ReactionType {
    case like
    case heart
    case dislike
    case fire
}

extension ReactionType: RawRepresentable {
    typealias RawValue = Int

    var rawValue: Int {
        switch self {
        case .like: return 1
        case .heart: return 2
        case .dislike: return 3
        case .fire: return 4
        }
    }

    init?(rawValue: Int) {
        switch rawValue {
        case 1: self = .like
        case 2: self = .heart
        case 3: self = .dislike
        case 4: self = .fire
        default: return nil
        }
    }
}
