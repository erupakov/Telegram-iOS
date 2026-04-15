import Foundation
import TelegramCore

public struct ProfileModel {
    var name: String
    var lastName: String?
    let age: Int
    let location: String
    let isVerified: Bool

    let likesCount: String
    let viewsCount: String
    let savesCount: String

    var biography: String

    let socialMediaHandles: [String]

    let galleryImageURLs: [URL]

    let photos: [TelegramPeerPhoto]
    let isMyProfile: Bool

    let userId: Int?
    let role: String?
    let mainImageURL: URL?
    let avatarImageURL: URL?

    public init(
        name: String,
        lastName: String? = nil,
        age: Int,
        location: String,
        isVerified: Bool,
        likesCount: String,
        viewsCount: String,
        savesCount: String,
        biography: String,
        socialMediaHandles: [String],
        galleryImageURLs: [URL] = [],
        photos: [TelegramPeerPhoto] = [],
        isMyProfile: Bool = false,
        userId: Int? = nil,
        role: String? = nil,
        mainImageURL: URL? = nil,
        avatarImageURL: URL? = nil
    ) {
        self.name = name
        self.lastName = lastName
        self.age = age
        self.location = location
        self.isVerified = isVerified
        self.likesCount = likesCount
        self.viewsCount = viewsCount
        self.savesCount = savesCount
        self.biography = biography
        self.socialMediaHandles = socialMediaHandles
        self.galleryImageURLs = galleryImageURLs
        self.photos = photos
        self.isMyProfile = isMyProfile
        self.userId = userId
        self.role = role
        self.mainImageURL = mainImageURL
        self.avatarImageURL = avatarImageURL
    }
}
