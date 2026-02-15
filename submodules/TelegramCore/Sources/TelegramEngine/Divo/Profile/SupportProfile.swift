import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_updateSocialLinks(
    account: Account,
    instagram: String,
    tiktok: String,
    youtube: String,
    website: String
) -> Signal<String?, NoError> {
    print("⛳️", "post _internal_updateSocialLinks")
    
    var flags: Int32 = 0

    flags |= 1 << 0 //instagram
    flags |= 1 << 1 //tiktok
    flags |= 1 << 2 //youtube
    flags |= 1 << 3 //website
    
    return account.network.request(
        Api.functions.profile.updateSocialLinks(
            flags: flags,
            instagram: "https://" + instagram,
            tiktok: "https://" + tiktok,
            youtube: "https://" + youtube,
            website: website.isEmpty ? "" : website.contains("https://") ? website : "https://" + website
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.UserProfile?, NoError>.single(nil)
    }
    |> mapToSignal { user -> Signal<String?, NoError> in
        if let user = user {
            print("👌 _internal_updateSocialLinks: ", user)
        }
        return .single(nil)
    }
}

func _internal_updateProfile(account: Account, data: ProfileParametersData) -> Signal<String?, NoError> {
    print("⛳️", "post _internal_updateProfile")
    
    var flags: Int32 = 0
    
//    flags |= 1 << 0 //firstName
//    flags |= 1 << 1 //lastName
//    flags |= 1 << 2 //country
//    flags |= 1 << 3 //about
    if data.gender != nil {
        flags |= 1 << 4 //gender
    }
//    flags |= 1 << 5 //birthDate
    flags |= 1 << 6 //height
    flags |= 1 << 7 //waist
    flags |= 1 << 8 //hips
    flags |= 1 << 9 //shoeSize
    flags |= 1 << 10 //hairLength
    flags |= 1 << 11 //hairColor
    flags |= 1 << 12 //eyeColor
    flags |= 1 << 13 //skinColor
    flags |= 1 << 14 //breastSize

    //    flags |= 1 << 15 //photoId
    
    flags |= 1 << 16 //backgroundId
    
    return account.network.request(
        Api.functions.profile.updateProfile(
            flags: flags,
            firstName: nil,
            lastName: nil,//"lastName",//String?,
            country: nil,//"country",//String?,
            about: nil,//firstName,//String?,
            gender: data.gender,//Api.Gender.genderMale,//Api.Gender?,
            birthDate: nil,//Int32?,
            height: data.height,
            waist: data.waist,
            hips: data.hips,
            shoeSize: data.shoeSize,
            hairLength: data.hairLength,
            hairColor: data.hairColor,
            eyeColor: data.eyeColor,
            skinColor: data.skinColor,
            breastSize: data.breastSize,
            photoId: nil,//Int64?
            backgroundId: data.backgroundId
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.UserProfile?, NoError>.single(nil)
    }
    |> mapToSignal { user -> Signal<String?, NoError> in
        if let user = user {
            print("👌 _internal_updateProfile: ", user)
        }
        return .single(nil)
    }
}

func _internal_updateProfileBackground(account: Account, backgroundId: Int64) -> Signal<String?, NoError> {
    print("⛳️", "post _internal_updateProfile")
    
    var flags: Int32 = 0

    flags |= 1 << 16 //backgroundId
    
    return account.network.request(
        Api.functions.profile.updateProfile(
            flags: flags,
            firstName: nil,
            lastName: nil,
            country: nil,
            about: nil,
            gender: nil,
            birthDate: nil,
            height: nil,
            waist: nil,
            hips: nil,
            shoeSize: nil,
            hairLength: nil,
            hairColor: nil,
            eyeColor: nil,
            skinColor: nil,
            breastSize: nil,
            photoId: nil,//Int64?
            backgroundId: backgroundId
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.UserProfile?, NoError>.single(nil)
    }
    |> mapToSignal { user -> Signal<String?, NoError> in
        if let user = user {
            print("👌 _internal_updateProfile: ", user)
        }
        return .single(nil)
    }
}

// MARK: - OLD
func _internal_updateProfileNameAndBio(account: Account, data: ProfileParametersData) -> Signal<String?, NoError> {
    print("⛳️", "post _internal_updateProfileNameAndBio")
    
    var flags: Int32 = 0
    
    flags |= 1 << 0 //firstName
    flags |= 1 << 1 //lastName
    flags |= 1 << 3 //about
    
    return account.network.request(
        Api.functions.profile.updateProfile(
            flags: flags,
            firstName: data.firstName,
            lastName: data.lastName,
            country: nil,
            about: data.about,
            gender: nil,
            birthDate: nil,
            height: nil,
            waist: nil,
            hips: nil,
            shoeSize: nil,
            hairLength: nil,
            hairColor: nil,
            eyeColor: nil,
            skinColor: nil,
            breastSize: nil,
            photoId: nil,//Int64?
            backgroundId: nil//Int64?
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.UserProfile?, NoError>.single(nil)
    }
    |> mapToSignal { user -> Signal<String?, NoError> in
        if let user = user {
            print("👌 _internal_updateProfileNameAndBio: ", user)
        }
        return .single(nil)
    }
}

func _internal_getUserProfile(account: Account, peer: Peer?) -> Signal<UserProfileData?, NoError> {
    print("⛳️", "_internal_getUserProfile")

    if let peer = peer, let inputUser = apiInputUser(peer) {
        return account.network.request(Api.functions.profile.getUserProfile(userId: inputUser))
        |> map(Optional.init)
        |> `catch` { _ in
            return Signal<Api.UserProfile?, NoError>.single(nil)
        }
        |> mapToSignal { userProfile -> Signal<UserProfileData?, NoError> in
            switch userProfile {
            case .userProfile(_, _, let country, let city, let gender, let birthDate, _, let about, let physicalParams, _, _, let socialLinks, _, let user, let background):
                
                var finalGender: SecureIdGender? = nil
                if let gender = gender {
                    switch gender {
                    case .genderFemale: finalGender = .female
                    case .genderMale: finalGender = .male
                    }
                }
                
                var finalSocialLinks: SocialLinks? = nil
                if let socialLinks = socialLinks, case let .socialLinks(apiLinks) = socialLinks {
                    var instagram: String?
                    var tiktok: String?
                    var youtube: String?
                    var website: String?
                    
                    for item in apiLinks {
                        if case let .keyVal(key, val) = item {
                            switch key.lowercased() {
                            case "instagram": instagram = val
                            case "tiktok":    tiktok = val
                            case "youtube":   youtube = val
                            case "website":   website = val
                            default: break
                            }
                        }
                    }
                    
                    finalSocialLinks = SocialLinks(
                        instagram: instagram,
                        tiktok: tiktok,
                        youtube: youtube,
                        website: website
                    )
                }
                let finalPhysical: PhysicalParams? = getPhysicalParams(physicalParams)
                
                var backgroundImage: TelegramMediaImage? = nil
                if let background = background {
                    backgroundImage = telegramMediaImageFromApiPhoto(background)
                }
                
                if let user = user,
                   case let .user(_, _, _, _, _, _, photo, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = user,
                   case let .userProfilePhoto(_, photoId, _, _) = photo
                {
                    print("⚠️", photoId)
                }
                let data = UserProfileData(
                    country: country,
                    city: city,
                    gender: finalGender,
                    birthDate: Int(birthDate ?? 0),
                    about: about,
                    physicalParams: finalPhysical,
                    socialLinks: finalSocialLinks,
                    agency: nil,
                    backgroundImage: backgroundImage
                )
                return .single(data)
            default:
                return .single(nil)
            }
        }
    }
    return .single(nil)
}

private func getPhysicalParams(_ physicalParams: Api.profile.PhysicalParams?) -> PhysicalParams? {
    if let p = physicalParams, case let .physicalParams(flags, age, height, waist, hips, shoeSize, hairLength, hairColor, eyeColor, skinColor, breastSize) = p {
        
        return PhysicalParams(
            flags: Int(flags),
            age: Int(age ?? 0),
            height: Int(height ?? 0),
            waist: Int(waist ?? 0),
            hips: Int(hips ?? 0),
            shoeSize: Int(shoeSize ?? 0),
            hairLength: Int(hairLength ?? 0),
            hairColor: hairColor,
            eyeColor: eyeColor,
            skinColor: skinColor,
            breastSize: breastSize
        )
    } else {
        return nil
    }
}

func _internal_getFullUser(account: Account, peer: Peer?) -> Signal<String?, NoError> {
    print("⛳️ _internal_getFullUser")

    if let peer = peer, let inputUser = apiInputUser(peer) {
//        let (description, buffer, deserializer) = Api.functions.users.getFullUser(id: inputUser)
        
        return account.network.request(Api.functions.users.getFullUser(id: inputUser))
            |> map(Optional.init)
            |> `catch` { _ in
                return .single(nil)
            }
            |> mapToSignal { fullUser -> Signal<String?, NoError> in
                if let fullUser = fullUser {
                    if case let .userFull(userFull, _, _) = fullUser {
                        if case let .userFull(_, _, _, about, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = userFull {
                            return .single(about)
                        }
                    }
                }
                return .single("about")
            }
    }
    return .single(nil)
}

func _internal_uploadPortfolioItem(account: Account, fileId: Int64, type: String) -> Signal<String?, NoError> {
    print("⛳️", "post _internal_uploadPortfolioItem")
    
    return account.network.request(
        Api.functions.profile.uploadPortfolioItem(fileId: fileId, type: type)
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.profile.PortfolioItem?, NoError>.single(nil)
    }
    |> mapToSignal { user -> Signal<String?, NoError> in
        if let user = user {
            print("👌 uploadPortfolioItem: ", user)
        }
        return .single(nil)
    }
}

func _internal_getPortfolio(account: Account, peer: Peer?, tab: String, offset: Int32, limit: Int32) -> Signal<[TelegramMediaImage]?, NoError> {
    print("⛳️", "_internal_getPortfolio")
    
    if let peer = peer, let inputUser = apiInputUser(peer) {
        return account.network.request(Api.functions.profile.getPortfolio(userId: inputUser, tab: tab, offset: offset, limit: limit))
        |> map(Optional.init)
        |> `catch` { _ in
            return Signal<Api.profile.Portfolio?, NoError>.single(nil)
        }
        |> mapToSignal { userProfile -> Signal<[TelegramMediaImage]?, NoError> in
            
            var images: [TelegramMediaImage]? = []
            if let user = userProfile {
                if case let .portfolio(_, items) = user {
                    for i in items {
                        if case let .portfolioItem(_, _, file) = i {
                            if let image = telegramMediaImageFromApiPhoto(file) {
                                images?.append(image)
                            }
                        }
                    }
                }
            }
            return .single(images)
        }
    }
    return .single(nil)
}
