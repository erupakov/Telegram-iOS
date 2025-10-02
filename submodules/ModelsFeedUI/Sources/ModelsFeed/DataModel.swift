import Foundation
import UIKit

struct StoryModel {
    let name: String
    let avatarName: String
    let isLive: Bool
    let isAdd: Bool?
}

struct CardModel {
    let name: String
    let mainImageName: String
    let avatarImageName: String
    let previewImagesName: [String]
    var userReaction: ReactionType?
    //    let reactionCounts: [ReactionType: Int]
    //    let status: String
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
