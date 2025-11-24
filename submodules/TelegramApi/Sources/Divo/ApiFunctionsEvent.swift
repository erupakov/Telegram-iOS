public extension Api.functions.event {
    static func addEventPhoto(eventId: Int64, photoId: Int64, displayOrder: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Photo>) {
        let buffer = Buffer()
        buffer.appendInt32(1743997916)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt64(photoId, buffer: buffer, boxed: false)
        serializeInt32(displayOrder, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.addEventPhoto", parameters: [("eventId", String(describing: eventId)), ("photoId", String(describing: photoId)), ("displayOrder", String(describing: displayOrder))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Photo? in
            let reader = BufferReader(buffer)
            var result: Api.event.Photo?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.event.Photo
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func applyToEvent(eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1963141875)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.applyToEvent", parameters: [("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func approveApplicant(eventId: Int64, userId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(1539802215)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt64(userId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.approveApplicant", parameters: [("eventId", String(describing: eventId)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func createEvent(flags: Int32, title: String, description: String, eventType: Api.event.EventType?, eventDate: String, eventTime: String, location: Api.event.Location?, coverPhotoId: Int64, enabledParameterKeys: [String]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Event>) {
        let buffer = Buffer()
        buffer.appendInt32(-862406103)
        serializeInt32(flags, buffer: buffer, boxed: false)
        serializeString(title, buffer: buffer, boxed: false)
        serializeString(description, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {eventType!.serialize(buffer, true)}
        serializeString(eventDate, buffer: buffer, boxed: false)
        serializeString(eventTime, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 1) != 0 {location!.serialize(buffer, true)}
        serializeInt64(coverPhotoId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(enabledParameterKeys!.count))
        for item in enabledParameterKeys! {
            serializeString(item, buffer: buffer, boxed: false)
        }}
        return (FunctionDescription(name: "event.createEvent", parameters: [("flags", String(describing: flags)), ("title", String(describing: title)), ("description", String(describing: description)), ("eventType", String(describing: eventType)), ("eventDate", String(describing: eventDate)), ("eventTime", String(describing: eventTime)), ("location", String(describing: location)), ("coverPhotoId", String(describing: coverPhotoId)), ("enabledParameterKeys", String(describing: enabledParameterKeys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Event? in
            let reader = BufferReader(buffer)
            var result: Api.event.Event?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.event.Event
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func deleteEvent(eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(1482429790)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.deleteEvent", parameters: [("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func deleteEventPhoto(eventId: Int64, photoId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(231973116)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt64(photoId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.deleteEventPhoto", parameters: [("eventId", String(describing: eventId)), ("photoId", String(describing: photoId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getAvailableParameters() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.event.AvailableParameter]>) {
        let buffer = Buffer()
        buffer.appendInt32(-1467679201)
        return (FunctionDescription(name: "event.getAvailableParameters", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.event.AvailableParameter]? in
            let reader = BufferReader(buffer)
            var result: [Api.event.AvailableParameter]?
            if let _ = reader.readInt32() {
                result = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.AvailableParameter.self)
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getCities(countryId: Int32, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.event.City]>) {
        let buffer = Buffer()
        buffer.appendInt32(1395526862)
        serializeInt32(countryId, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getCities", parameters: [("countryId", String(describing: countryId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.event.City]? in
            let reader = BufferReader(buffer)
            var result: [Api.event.City]?
            if let _ = reader.readInt32() {
                result = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.City.self)
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getCountries(offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.event.Country]>) {
        let buffer = Buffer()
        buffer.appendInt32(-193871156)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getCountries", parameters: [("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.event.Country]? in
            let reader = BufferReader(buffer)
            var result: [Api.event.Country]?
            if let _ = reader.readInt32() {
                result = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.Country.self)
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getEvent(eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Event>) {
        let buffer = Buffer()
        buffer.appendInt32(2128664903)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getEvent", parameters: [("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Event? in
            let reader = BufferReader(buffer)
            var result: Api.event.Event?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.event.Event
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getEventApplicants(eventId: Int64, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Members>) {
        let buffer = Buffer()
        buffer.appendInt32(-1015337045)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getEventApplicants", parameters: [("eventId", String(describing: eventId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Members? in
            let reader = BufferReader(buffer)
            var result: Api.event.Members?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.event.Members
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getEventMembers(flags: Int32, eventId: Int64, filter: Api.event.MemberTypeFilter?, searchQuery: String?, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Members>) {
        let buffer = Buffer()
        buffer.appendInt32(914926579)
        serializeInt32(flags, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {filter!.serialize(buffer, true)}
        if Int(flags) & Int(1 << 1) != 0 {serializeString(searchQuery!, buffer: buffer, boxed: false)}
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getEventMembers", parameters: [("flags", String(describing: flags)), ("eventId", String(describing: eventId)), ("filter", String(describing: filter)), ("searchQuery", String(describing: searchQuery)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Members? in
            let reader = BufferReader(buffer)
            var result: Api.event.Members?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.event.Members
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getEventTypes() -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.event.EventType]>) {
        let buffer = Buffer()
        buffer.appendInt32(-1591563259)
        return (FunctionDescription(name: "event.getEventTypes", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.event.EventType]? in
            let reader = BufferReader(buffer)
            var result: [Api.event.EventType]?
            if let _ = reader.readInt32() {
                result = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.EventType.self)
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getEvents(flags: Int32, filter: Api.event.Filter?, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Events>) {
        let buffer = Buffer()
        buffer.appendInt32(-986904169)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {filter!.serialize(buffer, true)}
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getEvents", parameters: [("flags", String(describing: flags)), ("filter", String(describing: filter)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Events? in
            let reader = BufferReader(buffer)
            var result: Api.event.Events?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.event.Events
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getMyEvents(offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Events>) {
        let buffer = Buffer()
        buffer.appendInt32(61591560)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getMyEvents", parameters: [("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Events? in
            let reader = BufferReader(buffer)
            var result: Api.event.Events?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.event.Events
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func getPreviousEvents(organizerId: Int64, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Events>) {
        let buffer = Buffer()
        buffer.appendInt32(2027489040)
        serializeInt64(organizerId, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getPreviousEvents", parameters: [("organizerId", String(describing: organizerId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Events? in
            let reader = BufferReader(buffer)
            var result: Api.event.Events?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.event.Events
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func likeEvent(eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-29810794)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.likeEvent", parameters: [("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func rejectApplicant(eventId: Int64, userId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(433472223)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt64(userId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.rejectApplicant", parameters: [("eventId", String(describing: eventId)), ("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func shareEvent(eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[String]>) {
        let buffer = Buffer()
        buffer.appendInt32(308239824)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.shareEvent", parameters: [("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [String]? in
            let reader = BufferReader(buffer)
            var result: [String]?
            if let _ = reader.readInt32() {
                result = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func unlikeEvent(eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(998468862)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.unlikeEvent", parameters: [("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func updateApplyParameters(flags: Int32, eventId: Int64, enabledParameterKeys: [Api.event.EventParameter]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(159454846)
        serializeInt32(flags, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(enabledParameterKeys!.count))
        for item in enabledParameterKeys! {
            item.serialize(buffer, true)
        }}
        return (FunctionDescription(name: "event.updateApplyParameters", parameters: [("flags", String(describing: flags)), ("eventId", String(describing: eventId)), ("enabledParameterKeys", String(describing: enabledParameterKeys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func updateEvent(flags: Int32, id: Int64, title: String, description: String, eventType: Api.event.EventType?, eventDate: String, eventTime: String, location: Api.event.Location?, coverPhotoId: Int64, enabledParameterKeys: [String]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Event>) {
        let buffer = Buffer()
        buffer.appendInt32(316214766)
        serializeInt32(flags, buffer: buffer, boxed: false)
        serializeInt64(id, buffer: buffer, boxed: false)
        serializeString(title, buffer: buffer, boxed: false)
        serializeString(description, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {eventType!.serialize(buffer, true)}
        serializeString(eventDate, buffer: buffer, boxed: false)
        serializeString(eventTime, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 1) != 0 {location!.serialize(buffer, true)}
        serializeInt64(coverPhotoId, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(enabledParameterKeys!.count))
        for item in enabledParameterKeys! {
            serializeString(item, buffer: buffer, boxed: false)
        }}
        return (FunctionDescription(name: "event.updateEvent", parameters: [("flags", String(describing: flags)), ("id", String(describing: id)), ("title", String(describing: title)), ("description", String(describing: description)), ("eventType", String(describing: eventType)), ("eventDate", String(describing: eventDate)), ("eventTime", String(describing: eventTime)), ("location", String(describing: location)), ("coverPhotoId", String(describing: coverPhotoId)), ("enabledParameterKeys", String(describing: enabledParameterKeys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Event? in
            let reader = BufferReader(buffer)
            var result: Api.event.Event?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.event.Event
            }
            return result
        })
    }
}
public extension Api.functions.event {
    static func updatePhotoOrder(eventId: Int64, photoId: Int64, displayOrder: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-2020718050)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt64(photoId, buffer: buffer, boxed: false)
        serializeInt32(displayOrder, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.updatePhotoOrder", parameters: [("eventId", String(describing: eventId)), ("photoId", String(describing: photoId)), ("displayOrder", String(describing: displayOrder))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
