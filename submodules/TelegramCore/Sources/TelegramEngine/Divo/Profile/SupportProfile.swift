import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_getWorkHistory(account: Account, peer: Peer?) -> Signal<[WorkExperienceModel]?, NoError> {
    print("⛳️", "_internal_getWorkHistory")

    if let peer = peer, let inputUser = apiInputUser(peer) {
        return account.network.request(Api.functions.profile.getWorkHistory(userId: inputUser, offset: 0, limit: 30))
        |> map(Optional.init)
        |> `catch` { _ in
            return Signal<Api.profile.WorkHistory?, NoError>.single(nil)
        }
        |> mapToSignal { workHistory -> Signal<[WorkExperienceModel]?, NoError> in
            if let workHistory = workHistory {
                print("👌 Events:", workHistory)
            }
            switch workHistory {
            case .workHistory(_, let experiences):
                
                let eventModels: [WorkExperienceModel] = experiences.compactMap { shortEvent in
                    if case let .workExperience(_, _, _, agency, startDate, endDate) = shortEvent {
                        var companyName = "agency"
                        if case let .agency(_, _, agencyName, _, _, _/*photo*/, _) = agency {
                            companyName = agencyName
                        }
                        
                        var period = "—"
                        if startDate < 0 {
                            period = formatExperiencePeriod(startDate: startDate, endDate: endDate)
                        }
                        return WorkExperienceModel(
                            companyName: companyName,
                            period: period,
                            logoName: nil
                        )
                    }
                    return nil
                }
                
                return .single(eventModels)
            default:
                return .single(nil)
            }
        }
    }
    return .single(nil)
}

private func formatExperiencePeriod(startDate: Int32, endDate: Int32?) -> String {
    let calendar = Calendar.current
    let start = Date(timeIntervalSince1970: TimeInterval(startDate))
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMMM yyyy"
    dateFormatter.locale = Locale(identifier: "en_US")
    
    let startString = dateFormatter.string(from: start)
    let endString: String
    let end: Date
    
    if let endDate = endDate, endDate > 0 {
        end = Date(timeIntervalSince1970: TimeInterval(endDate))
        endString = dateFormatter.string(from: end)
    } else {
        end = Date()
        endString = "Present"
    }
    
    let components = calendar.dateComponents([.year, .month], from: start, to: end)
    let years = components.year ?? 0
    let months = components.month ?? 0
    
    var durationString = ""
    if years > 0 {
        durationString += "\(years) year\(years > 1 ? "s" : "")"
    }
    
    if months > 0 {
        if !durationString.isEmpty {
            durationString += " "
        }
        durationString += "\(months) month\(months > 1 ? "s" : "")"
    }
    
    if durationString.isEmpty {
        durationString = "1 month"
    }
    
    return "\(startString) - \(endString) · \(durationString)"
}

func _internal_createWorkExperience(account: Account, agencyName: String, startDate: Int32) -> Signal<String?, NoError> {
    print("⛳️", "post createEvent")
    
    var flags: Int32 = 0

    flags |= 1 << 0
//    flags |= 1 << 1
//    flags |= 1 << 2
//

    let agency: Api.profile.Agency = .agency(flags: 0, id: 0, name: agencyName, description: nil, website: nil, photo: nil, peer: nil)
    return account.network.request(
        Api.functions.profile.createWorkExperience(
            flags: flags,
            agency: agency,
            startDate: startDate,
            endDate: nil,
            photo: nil
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.profile.WorkExperience?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<String?, NoError> in
        if let eventTypes = support {
            print("👌 createWorkExperience: ", eventTypes)
        }
        return .single(nil)
    }
}

func _internal_updateSocialLinks(
    account: Account,
    instagram: String,
    tiktok: String,
    youtube: String,
    website: String
) -> Signal<String?, NoError> {
    print("⛳️", "post createEvent")
    
    var flags: Int32 = 0

    flags |= 1 << 0 //instagram
    flags |= 1 << 1 //tiktok
    flags |= 1 << 2 //youtube
    flags |= 1 << 3 //website
    
    return account.network.request(
        Api.functions.profile.updateSocialLinks(
            flags: flags,
            instagram: "https://" + instagram + "/",
            tiktok: "https://" + tiktok,
            youtube: "https://" + youtube,
            website: website.isEmpty ? "" : website.contains("https://") ? website : "https://" + website
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.User?, NoError>.single(nil)
    }
    |> mapToSignal { user -> Signal<String?, NoError> in
        if let user = user {
            print("👌 _internal_updateSocialLinks: ", user)
        }
        return .single(nil)
    }
}

func _internal_updateProfile(account: Account, data: ProfileParametersData) -> Signal<String?, NoError> {
    print("⛳️", "post createEvent")
    
    var flags: Int32 = 0
    
//    flags |= 1 << 0 //firstName
//    flags |= 1 << 1 //lastName
//    flags |= 1 << 2 //country
//    flags |= 1 << 3 //about
//    flags |= 1 << 4 //gender
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
    
    return account.network.request(
        Api.functions.profile.updateProfile(
            flags: flags,
            firstName: nil,
            lastName: nil,//"lastName",//String?,
            country: nil,//"country",//String?,
            about: nil,//firstName,//String?,
            gender: nil,//Api.Gender.genderMale,//Api.Gender?,
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
            photoId: nil//Int64?
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.User?, NoError>.single(nil)
    }
    |> mapToSignal { user -> Signal<String?, NoError> in
        if let user = user {
            print("👌 _internal_updateSocialLinks: ", user)
        }
        return .single(nil)
    }
}

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
            photoId: nil//Int64?
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.User?, NoError>.single(nil)
    }
    |> mapToSignal { user -> Signal<String?, NoError> in
        if let user = user {
            print("👌 _internal_updateProfileNameAndBio: ", user)
        }
        return .single(nil)
    }
//    
//    var flags: Int32 = 0
//    
//    flags |= 1 << 0 //firstName
//    flags |= 1 << 1 //lastName
//    flags |= 1 << 3 //about
//    
//    let firstName = data.firstName
//    let lastName = data.lastName
//    let about = data.about
//    
//    return account.network.request(Api.functions.account.updateProfile(flags: flags, firstName: firstName, lastName: lastName, about: about))
//    |> map { result -> Api.User? in
//        return result
//    }
//    |> `catch` { _ in
//        return .single(nil)
//    }
//    |> mapToSignal { user -> Signal<String?, NoError> in
//        if let user = user {
//            print("👌 _internal_updateProfileNameAndBio: ", user)
//        }
//        return .single(nil)
//    }
}

func _internal_getUserProfile(account: Account, peer: Peer?) -> Signal<UserProfileData?, NoError> {
    print("⛳️", "_internal_getWorkHistory")

    if let peer = peer, let inputUser = apiInputUser(peer) {
        return account.network.request(Api.functions.profile.getUserProfile(userId: inputUser))
        |> map(Optional.init)
        |> `catch` { _ in
            return Signal<Api.UserProfile?, NoError>.single(nil)
        }
        |> mapToSignal { userProfile -> Signal<UserProfileData?, NoError> in
            if let userProfile = userProfile {
                print("👌 UserProfile:", userProfile)
            }
            switch userProfile {
            case .userProfile(_, _, let country, let city, let gender, let birthDate, _, let about, let physicalParams, _, _, let socialLinks, _):
                
                var finalGender: UserProfileData.Gender? = nil
                if let gender = gender {
                    switch gender {
                    case .genderFemale: finalGender = .genderFemale
                    case .genderMale: finalGender = .genderMale
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
                var finalPhysical: PhysicalParams? = nil
                if let p = physicalParams, case let .physicalParams(flags, age, height, waist, hips, shoeSize, hairLength, hairColor, eyeColor, skinColor, breastSize) = p {
                    
                    let unwrapRange: (Api.Range?) -> Int? = { range in
                        guard let range = range, case let .range(_, _, val) = range else { return nil }
                        return val.map(Int.init)
                    }
                    
                    finalPhysical = PhysicalParams(
                        flags: Int(flags),
                        age: age.flatMap { if case let .range(_, _, v) = $0 { return v.map(Int.init) }; return nil },
                        height: unwrapRange(height),
                        waist: unwrapRange(waist),
                        hips: unwrapRange(hips),
                        shoeSize: unwrapRange(shoeSize),
                        hairLength: unwrapRange(hairLength),
                        hairColor: hairColor,
                        eyeColor: eyeColor,
                        skinColor: skinColor,
                        breastSize: breastSize
                    )
                }
                
                let data = UserProfileData(
                    country: country,
                    city: city,
                    gender: finalGender,
                    birthDate: Int(birthDate ?? 0),
                    about: about,
                    physicalParams: finalPhysical,
                    socialLinks: finalSocialLinks,
                    agency: nil
                )
                return .single(data)
            default:
                return .single(nil)
            }
        }
    }
    return .single(nil)
}
