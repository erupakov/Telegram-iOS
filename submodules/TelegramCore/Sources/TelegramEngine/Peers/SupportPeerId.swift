import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_supportPeerId(account: Account) -> Signal<PeerId?, NoError> {
    print("⛳️", "get getCountries")
    return account.network.request(Api.functions.event.getCountries(offset: 0, limit: 1000))
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<[Api.event.Country]?, NoError>.single(nil)
    }
    |> mapToSignal { support -> Signal<PeerId?, NoError> in
        if let eventTypes = support {
            print("👌 Country: ", eventTypes)
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
    
    return account.network.request(Api.functions.event.getEvent(userId: 0, eventId: 3))
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


func _internal_getEvents(account: Account) -> Signal<PeerId?, NoError> {
//    let accountPeerId = account.peerId
    
    let country = Api.event.Country.country(countryId: 0, country: "")
    let city = Api.event.City.city(cityId: 0, city: "")
    let location = Api.event.Location.location(country: country, city: city)
    let eventType = Api.event.EventType.eventType(typeId: 0, title: "")
    let memberType = Api.event.MemberTypeFilter.memberTypeFilter(
        allMembers: Api.Bool.boolTrue,
        model: Api.Bool.boolTrue,
        newTalents: Api.Bool.boolTrue,
        booker: Api.Bool.boolTrue,
        scout: Api.Bool.boolTrue)
    
    
    let filter = Api.event.Filter.filter(
        searchQuery: "",
        location: location,
        eventType: eventType,
        dateFrom: "",
        dateTo: "",
        memberType: memberType)
    
    print("⛳️", "get getEvents")
    return account.network.request(Api.functions.event.getEvents(userId: 0, filter: filter, offset: 0, limit: 30))
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.event.Events?, NoError>.single(nil)
    }
    |> mapToSignal { events -> Signal<PeerId?, NoError> in
        if let events = events {
            print("👌 Events:", events)
        }
        return .single(nil)
    }
}
