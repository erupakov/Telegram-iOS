public class UserProfileData {
    //    let userId: Int64
    //    let role: String?
    //    let stats: Api.profile.Stats?
    //    let portfolio: Api.profile.Portfolio?
    
    let country: String?
    let city: String?
    let gender: Gender?
    let birthDate: Int?
    let about: String?
    let physicalParams: PhysicalParams?
    let socialLinks: SocialLinks?
    let agency: String?

    enum Gender: String, Codable {
        case genderFemale
        case genderMale
    }
    
    init(country: String?, city: String?, gender: Gender?, birthDate: Int?, about: String?, physicalParams: PhysicalParams?, socialLinks: SocialLinks?, agency: String?) {
        self.country = country
        self.city = city
        self.gender = gender
        self.birthDate = birthDate
        self.about = about
        self.physicalParams = physicalParams
        self.socialLinks = socialLinks
        self.agency = agency
    }
}

struct PhysicalParams: Codable {
    let flags: Int
    let age: Int?
    let height: RangeValue?
    let waist: RangeValue?
    let hips: RangeValue?
    let shoeSize: RangeValue?
    let hairLength: String?
    let hairColor: String?
    let eyeColor: String?
    let skinColor: String?
    let breastSize: String?
}

struct RangeValue: Codable {
    let flags: Int
    let max: Int?
    let value: Int?
}

struct SocialLinks: Codable {
    let links: [SocialKeyVal]
}

struct SocialKeyVal: Codable {
    let key: String
    let val: String
}
