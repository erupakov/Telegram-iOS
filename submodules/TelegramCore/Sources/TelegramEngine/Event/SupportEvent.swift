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

func _internal_createEvent(account: Account, event: EventModel, id: Int64) -> Signal<String?, NoError> {
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
    flags |= 1 << 0 //eventType
//    flags |= 1 << 1 //location
//    flags |= 1 << 2 // enabledParameterKeys ?????????
//
//
    return account.network.request(
        Api.functions.event.createEvent(
            flags: flags,
            title: event.title,
            description: event.description,
            eventType: eventType,
            eventDate: event.eventDate,
            eventTime: event.eventTime + ":00+03:00[Europe/Kyiv]",
            location: nil,
            coverPhotoId: id,
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
                if case let .short(_, _, _, title, coverPhoto, eventDate, eventTime, _, _, _, _, _) = shortEvent {
                    
                    var coverPhotoId: TelegramMediaImage? = nil
                    if case let .photo(photo, _) = coverPhoto {
                        coverPhotoId = telegramMediaImageFromApiPhoto(photo)
                    }
                    
                    return EventModel(
                        title: title,
                        description: title,
                        eventDate: eventDate,
                        eventTime: eventTime,
                        coverPhotoId: coverPhotoId,
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
