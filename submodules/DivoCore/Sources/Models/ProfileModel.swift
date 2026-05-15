import Foundation

public struct ProfileModel {
    public var name: String
    public var lastName: String?
    public let age: Int?
    public let location: String
    public let isVerified: Bool

    public let likesCount: String
    public let viewsCount: String
    public let savesCount: String

    public var biography: String

    public let socialMediaHandles: [String]

    public let galleryImageURLs: [URL]

    public let isMyProfile: Bool

    public let userId: Int?
    public let role: String?
    public let mainImageURL: URL?
    public let avatarImageURL: URL?

    public init(
        name: String,
        lastName: String? = nil,
        age: Int?,
        location: String,
        isVerified: Bool,
        likesCount: String,
        viewsCount: String,
        savesCount: String,
        biography: String,
        socialMediaHandles: [String],
        galleryImageURLs: [URL] = [],
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
        self.isMyProfile = isMyProfile
        self.userId = userId
        self.role = role
        self.mainImageURL = mainImageURL
        self.avatarImageURL = avatarImageURL
    }
}
