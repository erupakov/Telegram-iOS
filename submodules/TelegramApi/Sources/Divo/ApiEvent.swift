public extension Api.event {
    enum AvailableParameter: TypeConstructorDescription {
        case availableParameter(id: Int64, key: String, label: String, displayOrder: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .availableParameter(let id, let key, let label, let displayOrder):
                    if boxed {
                        buffer.appendInt32(-1217837952)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(key, buffer: buffer, boxed: false)
                    serializeString(label, buffer: buffer, boxed: false)
                    serializeInt32(displayOrder, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .availableParameter(let id, let key, let label, let displayOrder):
                return ("availableParameter", [("id", String(describing: id)), ("key", String(describing: key)), ("label", String(describing: label)), ("displayOrder", String(describing: displayOrder))])
            }
        }

        public static func parse_availableParameter(_ reader: BufferReader) -> AvailableParameter? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.event.AvailableParameter.availableParameter(id: _1!, key: _2!, label: _3!, displayOrder: _4!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum City: TypeConstructorDescription {
        case city(cityId: Int32, city: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .city(let cityId, let city):
                    if boxed {
                        buffer.appendInt32(774760486)
                    }
                    serializeInt32(cityId, buffer: buffer, boxed: false)
                    serializeString(city, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .city(let cityId, let city):
                return ("city", [("cityId", String(describing: cityId)), ("city", String(describing: city))])
            }
        }

        public static func parse_city(_ reader: BufferReader) -> City? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.event.City.city(cityId: _1!, city: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Country: TypeConstructorDescription {
        case country(countryId: Int32, country: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .country(let countryId, let country):
                    if boxed {
                        buffer.appendInt32(1618197693)
                    }
                    serializeInt32(countryId, buffer: buffer, boxed: false)
                    serializeString(country, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .country(let countryId, let country):
                return ("country", [("countryId", String(describing: countryId)), ("country", String(describing: country))])
            }
        }

        public static func parse_country(_ reader: BufferReader) -> Country? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.event.Country.country(countryId: _1!, country: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Error: TypeConstructorDescription {
        case error(code: Int32, message: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .error(let code, let message):
                    if boxed {
                        buffer.appendInt32(-2081385980)
                    }
                    serializeInt32(code, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .error(let code, let message):
                return ("error", [("code", String(describing: code)), ("message", String(describing: message))])
            }
        }

        public static func parse_error(_ reader: BufferReader) -> Error? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.event.Error.error(code: _1!, message: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Event: TypeConstructorDescription {
        case event(id: Int64, creator: Api.event.User, title: String, description: String, coverPhoto: Api.event.Photo, eventDate: String, eventTime: String, location: Api.event.Location, eventType: Api.event.EventType, stats: Api.event.Stats, parameters: [Api.event.EventParameter], applyParameters: [Api.event.EventParameter], gallery: [Api.event.Photo], previousEvents: [Api.event.Short], isCreator: Api.Bool, createdAt: Int32, updatedAt: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .event(let id, let creator, let title, let description, let coverPhoto, let eventDate, let eventTime, let location, let eventType, let stats, let parameters, let applyParameters, let gallery, let previousEvents, let isCreator, let createdAt, let updatedAt):
                    if boxed {
                        buffer.appendInt32(765330776)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    creator.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    coverPhoto.serialize(buffer, true)
                    serializeString(eventDate, buffer: buffer, boxed: false)
                    serializeString(eventTime, buffer: buffer, boxed: false)
                    location.serialize(buffer, true)
                    eventType.serialize(buffer, true)
                    stats.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(parameters.count))
                    for item in parameters {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(applyParameters.count))
                    for item in applyParameters {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gallery.count))
                    for item in gallery {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(previousEvents.count))
                    for item in previousEvents {
                        item.serialize(buffer, true)
                    }
                    isCreator.serialize(buffer, true)
                    serializeInt32(createdAt, buffer: buffer, boxed: false)
                    serializeInt32(updatedAt, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .event(let id, let creator, let title, let description, let coverPhoto, let eventDate, let eventTime, let location, let eventType, let stats, let parameters, let applyParameters, let gallery, let previousEvents, let isCreator, let createdAt, let updatedAt):
                return ("event", [("id", String(describing: id)), ("creator", String(describing: creator)), ("title", String(describing: title)), ("description", String(describing: description)), ("coverPhoto", String(describing: coverPhoto)), ("eventDate", String(describing: eventDate)), ("eventTime", String(describing: eventTime)), ("location", String(describing: location)), ("eventType", String(describing: eventType)), ("stats", String(describing: stats)), ("parameters", String(describing: parameters)), ("applyParameters", String(describing: applyParameters)), ("gallery", String(describing: gallery)), ("previousEvents", String(describing: previousEvents)), ("isCreator", String(describing: isCreator)), ("createdAt", String(describing: createdAt)), ("updatedAt", String(describing: updatedAt))])
            }
        }

        public static func parse_event(_ reader: BufferReader) -> Event? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.event.User?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.event.User
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.event.Photo?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.event.Photo
            }
            var _6: String?
            _6 = parseString(reader)
            var _7: String?
            _7 = parseString(reader)
            var _8: Api.event.Location?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.event.Location
            }
            var _9: Api.event.EventType?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.event.EventType
            }
            var _10: Api.event.Stats?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.event.Stats
            }
            var _11: [Api.event.EventParameter]?
            if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.EventParameter.self)
            }
            var _12: [Api.event.EventParameter]?
            if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.EventParameter.self)
            }
            var _13: [Api.event.Photo]?
            if let _ = reader.readInt32() {
                _13 = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.Photo.self)
            }
            var _14: [Api.event.Short]?
            if let _ = reader.readInt32() {
                _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.Short.self)
            }
            var _15: Api.Bool?
            if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _16: Int32?
            _16 = reader.readInt32()
            var _17: Int32?
            _17 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 {
                return Api.event.Event.event(id: _1!, creator: _2!, title: _3!, description: _4!, coverPhoto: _5!, eventDate: _6!, eventTime: _7!, location: _8!, eventType: _9!, stats: _10!, parameters: _11!, applyParameters: _12!, gallery: _13!, previousEvents: _14!, isCreator: _15!, createdAt: _16!, updatedAt: _17!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum EventParameter: TypeConstructorDescription {
        case eventParameter(id: Int64, key: String, label: String, value: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .eventParameter(let id, let key, let label, let value):
                    if boxed {
                        buffer.appendInt32(1872847863)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(key, buffer: buffer, boxed: false)
                    serializeString(label, buffer: buffer, boxed: false)
                    serializeString(value, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .eventParameter(let id, let key, let label, let value):
                return ("eventParameter", [("id", String(describing: id)), ("key", String(describing: key)), ("label", String(describing: label)), ("value", String(describing: value))])
            }
        }

        public static func parse_eventParameter(_ reader: BufferReader) -> EventParameter? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.event.EventParameter.eventParameter(id: _1!, key: _2!, label: _3!, value: _4!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum EventType: TypeConstructorDescription {
        case eventType(typeId: Int32, title: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .eventType(let typeId, let title):
                    if boxed {
                        buffer.appendInt32(405950179)
                    }
                    serializeInt32(typeId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .eventType(let typeId, let title):
                return ("eventType", [("typeId", String(describing: typeId)), ("title", String(describing: title))])
            }
        }

        public static func parse_eventType(_ reader: BufferReader) -> EventType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.event.EventType.eventType(typeId: _1!, title: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Events: TypeConstructorDescription {
        case events(events: [Api.event.Short], totalCount: Int32, hasMore: Api.Bool)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .events(let events, let totalCount, let hasMore):
                    if boxed {
                        buffer.appendInt32(-139189710)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(events.count))
                    for item in events {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(totalCount, buffer: buffer, boxed: false)
                    hasMore.serialize(buffer, true)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .events(let events, let totalCount, let hasMore):
                return ("events", [("events", String(describing: events)), ("totalCount", String(describing: totalCount)), ("hasMore", String(describing: hasMore))])
            }
        }

        public static func parse_events(_ reader: BufferReader) -> Events? {
            var _1: [Api.event.Short]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.Short.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.event.Events.events(events: _1!, totalCount: _2!, hasMore: _3!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Filter: TypeConstructorDescription {
        case filter(searchQuery: String, location: Api.event.Location, eventType: Api.event.EventType, dateFrom: String, dateTo: String, memberType: Api.event.MemberTypeFilter)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .filter(let searchQuery, let location, let eventType, let dateFrom, let dateTo, let memberType):
                    if boxed {
                        buffer.appendInt32(-1526113586)
                    }
                    serializeString(searchQuery, buffer: buffer, boxed: false)
                    location.serialize(buffer, true)
                    eventType.serialize(buffer, true)
                    serializeString(dateFrom, buffer: buffer, boxed: false)
                    serializeString(dateTo, buffer: buffer, boxed: false)
                    memberType.serialize(buffer, true)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .filter(let searchQuery, let location, let eventType, let dateFrom, let dateTo, let memberType):
                return ("filter", [("searchQuery", String(describing: searchQuery)), ("location", String(describing: location)), ("eventType", String(describing: eventType)), ("dateFrom", String(describing: dateFrom)), ("dateTo", String(describing: dateTo)), ("memberType", String(describing: memberType))])
            }
        }

        public static func parse_filter(_ reader: BufferReader) -> Filter? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.event.Location?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.event.Location
            }
            var _3: Api.event.EventType?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.event.EventType
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.event.MemberTypeFilter?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.event.MemberTypeFilter
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.event.Filter.filter(searchQuery: _1!, location: _2!, eventType: _3!, dateFrom: _4!, dateTo: _5!, memberType: _6!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Location: TypeConstructorDescription {
        case location(country: Api.event.Country, city: Api.event.City)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .location(let country, let city):
                    if boxed {
                        buffer.appendInt32(1261068553)
                    }
                    country.serialize(buffer, true)
                    city.serialize(buffer, true)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .location(let country, let city):
                return ("location", [("country", String(describing: country)), ("city", String(describing: city))])
            }
        }

        public static func parse_location(_ reader: BufferReader) -> Location? {
            var _1: Api.event.Country?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.event.Country
            }
            var _2: Api.event.City?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.event.City
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.event.Location.location(country: _1!, city: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum MemberTypeFilter: TypeConstructorDescription {
        case memberTypeFilter(allMembers: Api.Bool, model: Api.Bool, newTalents: Api.Bool, booker: Api.Bool, scout: Api.Bool)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .memberTypeFilter(let allMembers, let model, let newTalents, let booker, let scout):
                    if boxed {
                        buffer.appendInt32(887140881)
                    }
                    allMembers.serialize(buffer, true)
                    model.serialize(buffer, true)
                    newTalents.serialize(buffer, true)
                    booker.serialize(buffer, true)
                    scout.serialize(buffer, true)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .memberTypeFilter(let allMembers, let model, let newTalents, let booker, let scout):
                return ("memberTypeFilter", [("allMembers", String(describing: allMembers)), ("model", String(describing: model)), ("newTalents", String(describing: newTalents)), ("booker", String(describing: booker)), ("scout", String(describing: scout))])
            }
        }

        public static func parse_memberTypeFilter(_ reader: BufferReader) -> MemberTypeFilter? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _2: Api.Bool?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _4: Api.Bool?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _5: Api.Bool?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.event.MemberTypeFilter.memberTypeFilter(allMembers: _1!, model: _2!, newTalents: _3!, booker: _4!, scout: _5!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Members: TypeConstructorDescription {
        case members(members: [Api.event.User], totalCount: Int32, hasMore: Api.Bool)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .members(let members, let totalCount, let hasMore):
                    if boxed {
                        buffer.appendInt32(1028523612)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(members.count))
                    for item in members {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(totalCount, buffer: buffer, boxed: false)
                    hasMore.serialize(buffer, true)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .members(let members, let totalCount, let hasMore):
                return ("members", [("members", String(describing: members)), ("totalCount", String(describing: totalCount)), ("hasMore", String(describing: hasMore))])
            }
        }

        public static func parse_members(_ reader: BufferReader) -> Members? {
            var _1: [Api.event.User]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.event.User.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.event.Members.members(members: _1!, totalCount: _2!, hasMore: _3!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Photo: TypeConstructorDescription {
        case photo(photo: Api.Photo, displayOrder: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .photo(let photo, let displayOrder):
                    if boxed {
                        buffer.appendInt32(-1200681466)
                    }
                    photo.serialize(buffer, true)
                    serializeInt32(displayOrder, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .photo(let photo, let displayOrder):
                return ("photo", [("photo", String(describing: photo)), ("displayOrder", String(describing: displayOrder))])
            }
        }

        public static func parse_photo(_ reader: BufferReader) -> Photo? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.event.Photo.photo(photo: _1!, displayOrder: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Short: TypeConstructorDescription {
        case short(id: Int64, creator: Api.event.User, title: String, coverPhoto: Api.event.Photo, eventDate: String, eventTime: String, location: Api.event.Location, eventType: Api.event.EventType, stats: Api.event.Stats, isCreator: Api.Bool, createdAt: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .short(let id, let creator, let title, let coverPhoto, let eventDate, let eventTime, let location, let eventType, let stats, let isCreator, let createdAt):
                    if boxed {
                        buffer.appendInt32(-1599196108)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    creator.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    coverPhoto.serialize(buffer, true)
                    serializeString(eventDate, buffer: buffer, boxed: false)
                    serializeString(eventTime, buffer: buffer, boxed: false)
                    location.serialize(buffer, true)
                    eventType.serialize(buffer, true)
                    stats.serialize(buffer, true)
                    isCreator.serialize(buffer, true)
                    serializeInt32(createdAt, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .short(let id, let creator, let title, let coverPhoto, let eventDate, let eventTime, let location, let eventType, let stats, let isCreator, let createdAt):
                return ("short", [("id", String(describing: id)), ("creator", String(describing: creator)), ("title", String(describing: title)), ("coverPhoto", String(describing: coverPhoto)), ("eventDate", String(describing: eventDate)), ("eventTime", String(describing: eventTime)), ("location", String(describing: location)), ("eventType", String(describing: eventType)), ("stats", String(describing: stats)), ("isCreator", String(describing: isCreator)), ("createdAt", String(describing: createdAt))])
            }
        }

        public static func parse_short(_ reader: BufferReader) -> Short? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.event.User?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.event.User
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.event.Photo?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.event.Photo
            }
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: Api.event.Location?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.event.Location
            }
            var _8: Api.event.EventType?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.event.EventType
            }
            var _9: Api.event.Stats?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.event.Stats
            }
            var _10: Api.Bool?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _11: Int32?
            _11 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.event.Short.short(id: _1!, creator: _2!, title: _3!, coverPhoto: _4!, eventDate: _5!, eventTime: _6!, location: _7!, eventType: _8!, stats: _9!, isCreator: _10!, createdAt: _11!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Stats: TypeConstructorDescription {
        case stats(participantsCount: Int32, viewsCount: Int32, likesCount: Int32, isLiked: Api.Bool)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .stats(let participantsCount, let viewsCount, let likesCount, let isLiked):
                    if boxed {
                        buffer.appendInt32(1508149430)
                    }
                    serializeInt32(participantsCount, buffer: buffer, boxed: false)
                    serializeInt32(viewsCount, buffer: buffer, boxed: false)
                    serializeInt32(likesCount, buffer: buffer, boxed: false)
                    isLiked.serialize(buffer, true)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .stats(let participantsCount, let viewsCount, let likesCount, let isLiked):
                return ("stats", [("participantsCount", String(describing: participantsCount)), ("viewsCount", String(describing: viewsCount)), ("likesCount", String(describing: likesCount)), ("isLiked", String(describing: isLiked))])
            }
        }

        public static func parse_stats(_ reader: BufferReader) -> Stats? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Bool?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.event.Stats.stats(participantsCount: _1!, viewsCount: _2!, likesCount: _3!, isLiked: _4!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum Success: TypeConstructorDescription {
        case success(success: Api.Bool, message: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .success(let success, let message):
                    if boxed {
                        buffer.appendInt32(-1742876116)
                    }
                    success.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .success(let success, let message):
                return ("success", [("success", String(describing: success)), ("message", String(describing: message))])
            }
        }

        public static func parse_success(_ reader: BufferReader) -> Success? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.event.Success.success(success: _1!, message: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.event {
    enum User: TypeConstructorDescription {
        case user(user: Api.User)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .user(let user):
                    if boxed {
                        buffer.appendInt32(2016712066)
                    }
                    user.serialize(buffer, true)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .user(let user):
                return ("user", [("user", String(describing: user))])
            }
        }

        public static func parse_user(_ reader: BufferReader) -> User? {
            var _1: Api.User?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.User
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.event.User.user(user: _1!)
            }
            else {
                return nil
            }
        }

    }
}
