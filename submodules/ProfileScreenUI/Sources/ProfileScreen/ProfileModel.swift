import Foundation
import TelegramCore

public struct ProfileModel {
    let name: String
    let lastName: String?
    let age: Int
    let location: String
    let mainImageName: String
    let avatarImageName: String
    let isVerified: Bool
    
    let likesCount: String
    let viewsCount: String
    let savesCount: String
    
    let biography: String
    
    let socialMediaIcons: [String] = ["Models/instaIcon", "Models/TikTokIcon", "Models/youtubeIcon", "Models/webIcon"]
    let socialMediaHandles: [String]
    
    let galleryImageNames: [String]
    
    let photos: [TelegramPeerPhoto]
    let isMyProfile: Bool
    
    public init(
        name: String,
        lastName: String? = nil,
        age: Int,
        location: String,
        mainImageName: String,
        avatarImageName: String,
        isVerified: Bool,
        likesCount: String,
        viewsCount: String,
        savesCount: String,
        biography: String,
        socialMediaHandles: [String],
        galleryImageNames: [String],
        photos: [TelegramPeerPhoto] = [],
        isMyProfile: Bool = false
    ) {
        self.name = name
        self.lastName = lastName
        self.age = age
        self.location = location
        self.mainImageName = mainImageName
        self.avatarImageName = avatarImageName
        self.isVerified = isVerified
        self.likesCount = likesCount
        self.viewsCount = viewsCount
        self.savesCount = savesCount
        self.biography = biography
        self.socialMediaHandles = socialMediaHandles
        self.galleryImageNames = galleryImageNames
        self.photos = photos
        self.isMyProfile = isMyProfile
    }
}
