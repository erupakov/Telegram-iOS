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
            instagram: "https://www.instagram.com/" + instagram + "/",
            tiktok: "https://tiktok.com/" + tiktok,
            youtube: "https://youtube.com/" + youtube,
            website: website
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
    flags |= 1 << 4 //gender
//    flags |= 1 << 5 //birthDate
    flags |= 1 << 6 //height
    flags |= 1 << 7 //waist
    
    
    flags |= 1 << 8 //hips
//    flags |= 1 << 9 //shoeSize
//    flags |= 1 << 10 //hairLength
//    flags |= 1 << 11 //hairColor
    flags |= 1 << 12 //eyeColor
    
    return account.network.request(
        Api.functions.profile.updateProfile(
            flags: flags,
            firstName: nil,
            lastName: nil,//"lastName",//String?,
            country: nil,//"country",//String?,
            about: nil,//firstName,//String?,
            gender: Api.Gender.genderMale,//Api.Gender?,
            birthDate: nil,//Int32?,
            height: 42,//20,//Int32?,
            waist: 12,//Int32?,
            hips: 0,//Int32?,
            shoeSize: nil,//Int32?,
            hairLength: nil,//Int32?,
            hairColor: nil,//String?,
            eyeColor: "greenNew",//String?,
            skinColor: nil,//String?,
            breastSize: nil,//String?,
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


