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
                    if case let .workExperience(_, id, _, agency, startDate, endDate, photo) = shortEvent {
                        var companyName = "agency"
                        if case let .agency(_, _, agencyName, _, _, _, _) = agency {
                            companyName = agencyName
                        }
                        
                        var period = "—"
                        if startDate > 0 {
                            period = formatExperiencePeriod(startDate: startDate, endDate: endDate)
                        }
                        
                        var photoImage: TelegramMediaImage? = nil
                        if let photo = photo {
                            photoImage = telegramMediaImageFromApiPhoto(photo)
                        }
                        
                        return WorkExperienceModel(
                            id: Int(id),
                            companyName: companyName,
                            period: period,
                            logoName: photoImage
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

func _internal_createWorkExperience(account: Account, agencyName: String, startDate: Int32, endDate: Int32?, photoId: Int64?) -> Signal<String?, NoError> {
    print("⛳️", "post _internal_createWorkExperience")
    
    var flags: Int32 = 0

    flags |= 1 << 0
    if endDate != nil {
        flags |= 1 << 1
    }

    let agency: Api.profile.Agency = .agency(flags: 0, id: 0, name: agencyName, description: nil, website: nil, photo: nil, peer: nil)
    return account.network.request(
        Api.functions.profile.createWorkExperience(
            flags: flags,
            agency: agency,
            startDate: startDate,
            endDate: endDate,
            photoId: photoId
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

func _internal_deleteWorkExperience(account: Account, id: Int64) -> Signal<Bool?, NoError> {
    print("⛳️", "post deleteWorkExperience")

    return account.network.request(
        Api.functions.profile.deleteWorkExperience(
            id: id
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.Bool?, NoError>.single(nil)
    }
    |> mapToSignal { res -> Signal<Bool?, NoError> in
        if let res = res {
            print("👌 deleteWorkExperience: ", res)
        }
        return .single(nil)
    }
}
