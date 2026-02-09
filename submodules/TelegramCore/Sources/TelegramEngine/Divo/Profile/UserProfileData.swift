public class UserProfileData {
    //    let userId: Int64
    //    let role: String?
    //    let stats: Api.profile.Stats?
    //    let portfolio: Api.profile.Portfolio?
    
    public let country: String?
    public let city: String?
    public let gender: SecureIdGender?
    public let birthDate: Int?
    public let about: String?
    public let physicalParams: PhysicalParams?
    public let socialLinks: SocialLinks?
    public let agency: String?
    public let backgroundImage: TelegramMediaImage?

    init(country: String?, city: String?, gender: SecureIdGender?, birthDate: Int?, about: String?, physicalParams: PhysicalParams?, socialLinks: SocialLinks?, agency: String?, backgroundImage: TelegramMediaImage? = nil) {
        self.country = country
        self.city = city
        self.gender = gender
        self.birthDate = birthDate
        self.about = about
        self.physicalParams = physicalParams
        self.socialLinks = socialLinks
        self.agency = agency
        self.backgroundImage = backgroundImage
    }
}

public struct PhysicalParams: Codable {
    public let flags: Int
    public let age: Int?
    public let height: Int?
    public let waist: Int?
    public let hips: Int?
    public let shoeSize: Int?
    public let hairLength: Int?
    public let hairColor: String?
    public let eyeColor: String?
    public let skinColor: String?
    public let breastSize: String?
}

//struct RangeValue: Codable {
//    public let flags: Int
//    public let max: Int?
//    public let value: Int?
//}

public struct SocialLinks: Codable {
    public let instagram: String?
    public let tiktok: String?
    public let youtube: String?
    public let website: String?
}
