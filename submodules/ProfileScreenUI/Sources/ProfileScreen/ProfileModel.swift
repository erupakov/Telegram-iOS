import Foundation

public struct ProfileModel {
    let name: String
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
    
    public init(
        name: String,
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
        galleryImageNames: [String]
    ) {
        self.name = name
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
    }
}
