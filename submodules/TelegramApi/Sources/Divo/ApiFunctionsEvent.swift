public extension Api.functions.event {
    static func addEventPhoto(userId: Int64, eventId: Int64, photoId: Int64, displayOrder: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Photo>) {
        let buffer = Buffer()
        buffer.appendInt32(-440153535)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt64(photoId, buffer: buffer, boxed: false)
        serializeInt32(displayOrder, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.addEventPhoto", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId)), ("photoId", String(describing: photoId)), ("displayOrder", String(describing: displayOrder))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Photo? in
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
    static func applyToEvent(userId: Int64, eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-726855573)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.applyToEvent", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func createEvent(userId: Int64, title: String, description: String, eventType: Api.event.EventType, eventDate: String, eventTime: String, location: Api.event.Location, coverPhotoId: Int64, enabledParameterKeys: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Event>) {
        let buffer = Buffer()
        buffer.appendInt32(-232478147)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeString(title, buffer: buffer, boxed: false)
        serializeString(description, buffer: buffer, boxed: false)
        eventType.serialize(buffer, true)
        serializeString(eventDate, buffer: buffer, boxed: false)
        serializeString(eventTime, buffer: buffer, boxed: false)
        location.serialize(buffer, true)
        serializeInt64(coverPhotoId, buffer: buffer, boxed: false)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(enabledParameterKeys.count))
        for item in enabledParameterKeys {
            serializeString(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "event.createEvent", parameters: [("userId", String(describing: userId)), ("title", String(describing: title)), ("description", String(describing: description)), ("eventType", String(describing: eventType)), ("eventDate", String(describing: eventDate)), ("eventTime", String(describing: eventTime)), ("location", String(describing: location)), ("coverPhotoId", String(describing: coverPhotoId)), ("enabledParameterKeys", String(describing: enabledParameterKeys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Event? in
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
    static func deleteEvent(userId: Int64, eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1697614088)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.deleteEvent", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func deleteEventPhoto(userId: Int64, eventId: Int64, photoId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(232260027)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt64(photoId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.deleteEventPhoto", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId)), ("photoId", String(describing: photoId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func getAvailableParameters(userId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.event.AvailableParameter]>) {
        let buffer = Buffer()
        buffer.appendInt32(2041235951)
        serializeInt64(userId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getAvailableParameters", parameters: [("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.event.AvailableParameter]? in
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
    static func getEvent(userId: Int64, eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Event>) {
        let buffer = Buffer()
        buffer.appendInt32(1784809044)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getEvent", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Event? in
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
    static func getEventApplicants(userId: Int64, eventId: Int64, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Members>) {
        let buffer = Buffer()
        buffer.appendInt32(-981517988)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getEventApplicants", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Members? in
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
    static func getEventMembers(userId: Int64, eventId: Int64, filter: Api.event.MemberTypeFilter, searchQuery: String, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Members>) {
        let buffer = Buffer()
        buffer.appendInt32(2028592163)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        filter.serialize(buffer, true)
        serializeString(searchQuery, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getEventMembers", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId)), ("filter", String(describing: filter)), ("searchQuery", String(describing: searchQuery)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Members? in
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
    static func getEvents(userId: Int64, filter: Api.event.Filter, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Events>) {
        let buffer = Buffer()
        buffer.appendInt32(200595927)
        serializeInt64(userId, buffer: buffer, boxed: false)
        filter.serialize(buffer, true)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getEvents", parameters: [("userId", String(describing: userId)), ("filter", String(describing: filter)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Events? in
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
    static func getMyEvents(userId: Int64, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Events>) {
        let buffer = Buffer()
        buffer.appendInt32(-1782880116)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getMyEvents", parameters: [("userId", String(describing: userId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Events? in
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
    static func getPreviousEvents(userId: Int64, organizerId: Int64, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Events>) {
        let buffer = Buffer()
        buffer.appendInt32(-1793048227)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(organizerId, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.getPreviousEvents", parameters: [("userId", String(describing: userId)), ("organizerId", String(describing: organizerId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Events? in
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
    static func likeEvent(userId: Int64, eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1295599196)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.likeEvent", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func shareEvent(userId: Int64, eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[String]>) {
        let buffer = Buffer()
        buffer.appendInt32(94091441)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.shareEvent", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [String]? in
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
    static func unlikeEvent(userId: Int64, eventId: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1773141903)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.unlikeEvent", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func updateApplyParameters(userId: Int64, eventId: Int64, enabledParameterKeys: [Api.event.EventParameter]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-1018577779)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(enabledParameterKeys.count))
        for item in enabledParameterKeys {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "event.updateApplyParameters", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId)), ("enabledParameterKeys", String(describing: enabledParameterKeys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
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
    static func updateEvent(id: Int64, userId: Int64, title: String, description: String, eventType: Api.event.EventType, eventDate: String, eventTime: String, location: Api.event.Location, coverPhotoId: Int64, enabledParameterKeys: [String]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.event.Event>) {
        let buffer = Buffer()
        buffer.appendInt32(690381817)
        serializeInt64(id, buffer: buffer, boxed: false)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeString(title, buffer: buffer, boxed: false)
        serializeString(description, buffer: buffer, boxed: false)
        eventType.serialize(buffer, true)
        serializeString(eventDate, buffer: buffer, boxed: false)
        serializeString(eventTime, buffer: buffer, boxed: false)
        location.serialize(buffer, true)
        serializeInt64(coverPhotoId, buffer: buffer, boxed: false)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(enabledParameterKeys.count))
        for item in enabledParameterKeys {
            serializeString(item, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "event.updateEvent", parameters: [("id", String(describing: id)), ("userId", String(describing: userId)), ("title", String(describing: title)), ("description", String(describing: description)), ("eventType", String(describing: eventType)), ("eventDate", String(describing: eventDate)), ("eventTime", String(describing: eventTime)), ("location", String(describing: location)), ("coverPhotoId", String(describing: coverPhotoId)), ("enabledParameterKeys", String(describing: enabledParameterKeys))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.event.Event? in
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
    static func updatePhotoOrder(userId: Int64, eventId: Int64, photoId: Int64, displayOrder: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(418839194)
        serializeInt64(userId, buffer: buffer, boxed: false)
        serializeInt64(eventId, buffer: buffer, boxed: false)
        serializeInt64(photoId, buffer: buffer, boxed: false)
        serializeInt32(displayOrder, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "event.updatePhotoOrder", parameters: [("userId", String(describing: userId)), ("eventId", String(describing: eventId)), ("photoId", String(describing: photoId)), ("displayOrder", String(describing: displayOrder))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}

