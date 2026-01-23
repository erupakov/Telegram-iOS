import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _getEvent(account: Account, eventId: Int) -> Signal<String?, NoError> {
    print("⛳️", "get one getEvent")
    
    return account.network.request(Api.functions.event.getEvent(eventId: Int64(eventId)))
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.event.Event?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<String?, NoError> in
        if let getEvent = support {
            print("👌 get one getEvent: ", getEvent)
        }
        return .single(nil)
    }
}

func _internal_createEvent(account: Account, event: EventModel) -> Signal<String?, NoError> {
    print("⛳️", "post createEvent")
    
    var flags: Int32 = 0
    let eventType = Api.event.EventType.eventType(typeId: 1, title: "Casting")
//
//    let country = Api.event.Country.country(countryId: 2, country: "Aland Islands")
////    let city = Api.event.City.city(cityId: 1, city: "Odessa")
//
////    var locationFlags: Int32 = 0
////    locationFlags |= 1 << 0
//    let location = Api.event.Location.location(flags: 0, country: country, city: nil)
//
    flags |= 1 << 0
//    flags |= 1 << 1
//    flags |= 1 << 2
//
//
    return account.network.request(
        Api.functions.event.createEvent(
            flags: flags,
            title: event.title,
            description: event.description,
            eventType: eventType,
            eventDate: event.eventDate,
            eventTime: event.eventTime,
            location: nil,
            coverPhotoId: event.coverPhotoId,
            enabledParameterKeys: event.enabledParameterKeys
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.event.Event?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<String?, NoError> in
        if let eventTypes = support {
            print("👌 createEvent: ", eventTypes)
        }
        return .single(nil)
    }
}

func _getCountries(account: Account) -> Signal<String?, NoError> {
    print("⛳️", "get getCountries")
    return account.network.request(Api.functions.event.getCountries(offset: 0, limit: 5))
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<[Api.event.Country]?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<String?, NoError> in
        if let countries = support {
            print("👌 Countries: ", countries)
        }
        return .single(nil)
    }
}

func _internal_getEvents(account: Account) -> Signal<[EventModel]?, NoError> {
//    let accountPeerId = account.peerId
    
//    let country = Api.event.Country.country(countryId: 0, country: "")
//    let city = Api.event.City.city(cityId: 0, city: "")
//    let location = Api.event.Location.location(country: country, city: city)
//    let eventType = Api.event.EventType.eventType(typeId: 0, title: "")
//    let memberType = Api.event.MemberTypeFilter.memberTypeFilter(
//        allMembers: Api.Bool.boolTrue,
//        model: Api.Bool.boolTrue,
//        newTalents: Api.Bool.boolTrue,
//        booker: Api.Bool.boolTrue,
//        scout: Api.Bool.boolTrue)
//
//
//    let filter = Api.event.Filter.filter(
//        searchQuery: "",
//        location: location,
//        eventType: eventType,
//        dateFrom: "",
//        dateTo: "",
//        memberType: memberType)
    
    print("⛳️", "get getEvents")
    let flags: Int32 = 0
//    if filter != nil {
//        flags |= 1 << 0
//    }
    
    return account.network.request(Api.functions.event.getEvents(flags: flags, filter: nil, offset: 0, limit: 30))
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.event.Events?, NoError>.single(nil)
    }
    |> mapToSignal { events -> Signal<[EventModel]?, NoError> in
        if let events = events {
            print("👌 Events:", events)
        }
        switch events {
        case .events(_, let events, _, _):
            let eventModels: [EventModel] = events.compactMap { shortEvent in
                if case let .short(_, _, _, title, _, eventDate, eventTime, _, _, _, _, _) = shortEvent {
                    return EventModel(
                        title: title,
                        description: title,
                        eventDate: eventDate,
                        eventTime: eventTime,
                        coverPhotoId: 0,
                        enabledParameterKeys: nil
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
