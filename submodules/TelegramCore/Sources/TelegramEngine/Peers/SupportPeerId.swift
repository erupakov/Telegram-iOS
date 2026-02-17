import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_supportPeerId(account: Account) -> Signal<PeerId?, NoError> {
    print("⛳️", "post createEvent")
    
    var flags: Int32 = 0
//
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
            title: "Test ios 12:29",
            description: "Test ios description2 12:29",
            eventType: eventType,
            eventDate: "2026-07-15",
            eventTime: "00:00",
            location: nil,
            coverPhotoId: 0,
            enabledParameterKeys: []
        )
    )
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.event.Event?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<PeerId?, NoError> in
        if let eventTypes = support {
            print("👌 createEvent: ", eventTypes)
        }
        return .single(nil)
    }
}

func _internal_getCountries(account: Account) -> Signal<String?, NoError> {
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

func _internal_getEventTypes(account: Account) -> Signal<PeerId?, NoError> {
    print("⛳️", "get getEventTypes")
    return account.network.request(Api.functions.event.getEventTypes())
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<[Api.event.EventType]?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<PeerId?, NoError> in
        if let eventTypes = support {
            print("👌eventTypes: ", eventTypes)
        }
        return .single(nil)
    }
}

func _internal_getEvent(account: Account) -> Signal<PeerId?, NoError> {
    print("⛳️", "get one getEvent")
    
    return account.network.request(Api.functions.event.getEvent(eventId: 1))
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.event.Event?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<PeerId?, NoError> in
        if let getEvent = support {
            print("👌 get one getEvent: ", getEvent)
        }
        return .single(nil)
    }
}
