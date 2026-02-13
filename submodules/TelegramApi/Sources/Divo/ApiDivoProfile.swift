public extension Api.profile {
    enum Agency: TypeConstructorDescription {
        case agency(flags: Int32, id: Int64, name: String, description: String?, website: String?, photo: Api.Photo?, peer: Api.Peer?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .agency(let flags, let id, let name, let description, let website, let photo, let peer):
                    if boxed {
                        buffer.appendInt32(892775356)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(website!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {peer!.serialize(buffer, true)}
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .agency(let flags, let id, let name, let description, let website, let photo, let peer):
                return ("agency", [("flags", String(describing: flags)), ("id", String(describing: id)), ("name", String(describing: name)), ("description", String(describing: description)), ("website", String(describing: website)), ("photo", String(describing: photo)), ("peer", String(describing: peer))])
            }
        }

        public static func parse_agency(_ reader: BufferReader) -> Agency? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _7: Api.Peer?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.profile.Agency.agency(flags: _1!, id: _2!, name: _3!, description: _4, website: _5, photo: _6, peer: _7)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum FoundAgencies: TypeConstructorDescription {
        case foundAgencies(count: Int32, agencies: [Api.profile.Agency])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .foundAgencies(let count, let agencies):
                    if boxed {
                        buffer.appendInt32(-1238686816)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(agencies.count))
                    for item in agencies {
                        item.serialize(buffer, true)
                    }
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .foundAgencies(let count, let agencies):
                return ("foundAgencies", [("count", String(describing: count)), ("agencies", String(describing: agencies))])
            }
        }

        public static func parse_foundAgencies(_ reader: BufferReader) -> FoundAgencies? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.profile.Agency]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.profile.Agency.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.profile.FoundAgencies.foundAgencies(count: _1!, agencies: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum FoundUsers: TypeConstructorDescription {
        case foundUsers(count: Int32, users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .foundUsers(let count, let users):
                    if boxed {
                        buffer.appendInt32(-1159652644)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .foundUsers(let count, let users):
                return ("foundUsers", [("count", String(describing: count)), ("users", String(describing: users))])
            }
        }

        public static func parse_foundUsers(_ reader: BufferReader) -> FoundUsers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.profile.FoundUsers.foundUsers(count: _1!, users: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum KeyVal: TypeConstructorDescription {
        case keyVal(key: String, val: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .keyVal(let key, let val):
                    if boxed {
                        buffer.appendInt32(460711454)
                    }
                    serializeString(key, buffer: buffer, boxed: false)
                    serializeString(val, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .keyVal(let key, let val):
                return ("keyVal", [("key", String(describing: key)), ("val", String(describing: val))])
            }
        }

        public static func parse_keyVal(_ reader: BufferReader) -> KeyVal? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.profile.KeyVal.keyVal(key: _1!, val: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum ModelInfo: TypeConstructorDescription {
        case modelInfo(flags: Int32, typeId: Int32, gender: Int32?, age: Int32?, name: String?, agencyName: String?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .modelInfo(let flags, let typeId, let gender, let age, let name, let agencyName):
                    if boxed {
                        buffer.appendInt32(1107222402)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(typeId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(gender!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(age!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(name!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(agencyName!, buffer: buffer, boxed: false)}
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .modelInfo(let flags, let typeId, let gender, let age, let name, let agencyName):
                return ("modelInfo", [("flags", String(describing: flags)), ("typeId", String(describing: typeId)), ("gender", String(describing: gender)), ("age", String(describing: age)), ("name", String(describing: name)), ("agencyName", String(describing: agencyName))])
            }
        }

        public static func parse_modelInfo(_ reader: BufferReader) -> ModelInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.profile.ModelInfo.modelInfo(flags: _1!, typeId: _2!, gender: _3, age: _4, name: _5, agencyName: _6)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum Option: TypeConstructorDescription {
        case option(id: String, value: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .option(let id, let value):
                    if boxed {
                        buffer.appendInt32(-2391709)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(value, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .option(let id, let value):
                return ("option", [("id", String(describing: id)), ("value", String(describing: value))])
            }
        }

        public static func parse_option(_ reader: BufferReader) -> Option? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.profile.Option.option(id: _1!, value: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum PhysicalParams: TypeConstructorDescription {
        case physicalParams(flags: Int32, age: Int64?, height: Int64?, waist: Int64?, hips: Int64?, shoeSize: Int64?, hairLength: Int64?, hairColor: String?, eyeColor: String?, skinColor: String?, breastSize: String?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .physicalParams(let flags, let age, let height, let waist, let hips, let shoeSize, let hairLength, let hairColor, let eyeColor, let skinColor, let breastSize):
                    if boxed {
                        buffer.appendInt32(1215939547)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(age!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(height!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(waist!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(hips!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(shoeSize!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt64(hairLength!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(hairColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeString(eyeColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeString(skinColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeString(breastSize!, buffer: buffer, boxed: false)}
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .physicalParams(let flags, let age, let height, let waist, let hips, let shoeSize, let hairLength, let hairColor, let eyeColor, let skinColor, let breastSize):
                return ("physicalParams", [("flags", String(describing: flags)), ("age", String(describing: age)), ("height", String(describing: height)), ("waist", String(describing: waist)), ("hips", String(describing: hips)), ("shoeSize", String(describing: shoeSize)), ("hairLength", String(describing: hairLength)), ("hairColor", String(describing: hairColor)), ("eyeColor", String(describing: eyeColor)), ("skinColor", String(describing: skinColor)), ("breastSize", String(describing: breastSize))])
            }
        }

        public static func parse_physicalParams(_ reader: BufferReader) -> PhysicalParams? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt64() }
            var _3: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt64() }
            var _4: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt64() }
            var _5: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = reader.readInt64() }
            var _6: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = reader.readInt64() }
            var _7: Int64?
            if Int(_1!) & Int(1 << 5) != 0 {_7 = reader.readInt64() }
            var _8: String?
            if Int(_1!) & Int(1 << 6) != 0 {_8 = parseString(reader) }
            var _9: String?
            if Int(_1!) & Int(1 << 7) != 0 {_9 = parseString(reader) }
            var _10: String?
            if Int(_1!) & Int(1 << 8) != 0 {_10 = parseString(reader) }
            var _11: String?
            if Int(_1!) & Int(1 << 9) != 0 {_11 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 5) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 6) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 7) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 8) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 9) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.profile.PhysicalParams.physicalParams(flags: _1!, age: _2, height: _3, waist: _4, hips: _5, shoeSize: _6, hairLength: _7, hairColor: _8, eyeColor: _9, skinColor: _10, breastSize: _11)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum Portfolio: TypeConstructorDescription {
        case portfolio(count: Int32, items: [Api.profile.PortfolioItem])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .portfolio(let count, let items):
                    if boxed {
                        buffer.appendInt32(657486946)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(items.count))
                    for item in items {
                        item.serialize(buffer, true)
                    }
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .portfolio(let count, let items):
                return ("portfolio", [("count", String(describing: count)), ("items", String(describing: items))])
            }
        }

        public static func parse_portfolio(_ reader: BufferReader) -> Portfolio? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.profile.PortfolioItem]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.profile.PortfolioItem.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.profile.Portfolio.portfolio(count: _1!, items: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum PortfolioItem: TypeConstructorDescription {
        case portfolioItem(id: Int64, type: String, file: Api.Photo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .portfolioItem(let id, let type, let file):
                    if boxed {
                        buffer.appendInt32(77281858)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .portfolioItem(let id, let type, let file):
                return ("portfolioItem", [("id", String(describing: id)), ("type", String(describing: type)), ("file", String(describing: file))])
            }
        }

        public static func parse_portfolioItem(_ reader: BufferReader) -> PortfolioItem? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Photo?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.profile.PortfolioItem.portfolioItem(id: _1!, type: _2!, file: _3!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum RangeLimits: TypeConstructorDescription {
        case rangeLimits(min: Int32, max: Int32, step: Int32, unit: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .rangeLimits(let min, let max, let step, let unit):
                    if boxed {
                        buffer.appendInt32(-817810613)
                    }
                    serializeInt32(min, buffer: buffer, boxed: false)
                    serializeInt32(max, buffer: buffer, boxed: false)
                    serializeInt32(step, buffer: buffer, boxed: false)
                    serializeString(unit, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .rangeLimits(let min, let max, let step, let unit):
                return ("rangeLimits", [("min", String(describing: min)), ("max", String(describing: max)), ("step", String(describing: step)), ("unit", String(describing: unit))])
            }
        }

        public static func parse_rangeLimits(_ reader: BufferReader) -> RangeLimits? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.profile.RangeLimits.rangeLimits(min: _1!, max: _2!, step: _3!, unit: _4!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum SearchConfig: TypeConstructorDescription {
        case searchConfig(flags: Int32, genders: [Api.profile.Option], hairColors: [Api.profile.Option], eyeColors: [Api.profile.Option], skinColors: [Api.profile.Option], breastSizes: [Api.profile.Option], ageLimits: Api.profile.RangeLimits, heightLimits: Api.profile.RangeLimits, waistLimits: Api.profile.RangeLimits, hipsLimits: Api.profile.RangeLimits, shoeSizeLimits: Api.profile.RangeLimits, hairLengthLimits: Api.profile.RangeLimits)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .searchConfig(let flags, let genders, let hairColors, let eyeColors, let skinColors, let breastSizes, let ageLimits, let heightLimits, let waistLimits, let hipsLimits, let shoeSizeLimits, let hairLengthLimits):
                    if boxed {
                        buffer.appendInt32(-1956061324)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(genders.count))
                    for item in genders {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(hairColors.count))
                    for item in hairColors {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(eyeColors.count))
                    for item in eyeColors {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(skinColors.count))
                    for item in skinColors {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(breastSizes.count))
                    for item in breastSizes {
                        item.serialize(buffer, true)
                    }
                    ageLimits.serialize(buffer, true)
                    heightLimits.serialize(buffer, true)
                    waistLimits.serialize(buffer, true)
                    hipsLimits.serialize(buffer, true)
                    shoeSizeLimits.serialize(buffer, true)
                    hairLengthLimits.serialize(buffer, true)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .searchConfig(let flags, let genders, let hairColors, let eyeColors, let skinColors, let breastSizes, let ageLimits, let heightLimits, let waistLimits, let hipsLimits, let shoeSizeLimits, let hairLengthLimits):
                return ("searchConfig", [("flags", String(describing: flags)), ("genders", String(describing: genders)), ("hairColors", String(describing: hairColors)), ("eyeColors", String(describing: eyeColors)), ("skinColors", String(describing: skinColors)), ("breastSizes", String(describing: breastSizes)), ("ageLimits", String(describing: ageLimits)), ("heightLimits", String(describing: heightLimits)), ("waistLimits", String(describing: waistLimits)), ("hipsLimits", String(describing: hipsLimits)), ("shoeSizeLimits", String(describing: shoeSizeLimits)), ("hairLengthLimits", String(describing: hairLengthLimits))])
            }
        }

        public static func parse_searchConfig(_ reader: BufferReader) -> SearchConfig? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.profile.Option]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.profile.Option.self)
            }
            var _3: [Api.profile.Option]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.profile.Option.self)
            }
            var _4: [Api.profile.Option]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.profile.Option.self)
            }
            var _5: [Api.profile.Option]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.profile.Option.self)
            }
            var _6: [Api.profile.Option]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.profile.Option.self)
            }
            var _7: Api.profile.RangeLimits?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.profile.RangeLimits
            }
            var _8: Api.profile.RangeLimits?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.profile.RangeLimits
            }
            var _9: Api.profile.RangeLimits?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.profile.RangeLimits
            }
            var _10: Api.profile.RangeLimits?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.profile.RangeLimits
            }
            var _11: Api.profile.RangeLimits?
            if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.profile.RangeLimits
            }
            var _12: Api.profile.RangeLimits?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.profile.RangeLimits
            }
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.profile.SearchConfig.searchConfig(flags: _1!, genders: _2!, hairColors: _3!, eyeColors: _4!, skinColors: _5!, breastSizes: _6!, ageLimits: _7!, heightLimits: _8!, waistLimits: _9!, hipsLimits: _10!, shoeSizeLimits: _11!, hairLengthLimits: _12!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum SocialLinks: TypeConstructorDescription {
        case socialLinks(links: [Api.profile.KeyVal])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .socialLinks(let links):
                    if boxed {
                        buffer.appendInt32(1499661675)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(links.count))
                    for item in links {
                        item.serialize(buffer, true)
                    }
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .socialLinks(let links):
                return ("socialLinks", [("links", String(describing: links))])
            }
        }

        public static func parse_socialLinks(_ reader: BufferReader) -> SocialLinks? {
            var _1: [Api.profile.KeyVal]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.profile.KeyVal.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.profile.SocialLinks.socialLinks(links: _1!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum Stats: TypeConstructorDescription {
        case stats(likes: Int32, views: Int32, saved: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .stats(let likes, let views, let saved):
                    if boxed {
                        buffer.appendInt32(-1946315564)
                    }
                    serializeInt32(likes, buffer: buffer, boxed: false)
                    serializeInt32(views, buffer: buffer, boxed: false)
                    serializeInt32(saved, buffer: buffer, boxed: false)
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .stats(let likes, let views, let saved):
                return ("stats", [("likes", String(describing: likes)), ("views", String(describing: views)), ("saved", String(describing: saved))])
            }
        }

        public static func parse_stats(_ reader: BufferReader) -> Stats? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.profile.Stats.stats(likes: _1!, views: _2!, saved: _3!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum UsersList: TypeConstructorDescription {
        case usersList(count: Int32, users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .usersList(let count, let users):
                    if boxed {
                        buffer.appendInt32(2104542426)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .usersList(let count, let users):
                return ("usersList", [("count", String(describing: count)), ("users", String(describing: users))])
            }
        }

        public static func parse_usersList(_ reader: BufferReader) -> UsersList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.profile.UsersList.usersList(count: _1!, users: _2!)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum WorkExperience: TypeConstructorDescription {
        case workExperience(flags: Int32, id: Int64, userId: Int64, agency: Api.profile.Agency, startDate: Int32, endDate: Int32?, photo: Api.Photo?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .workExperience(let flags, let id, let userId, let agency, let startDate, let endDate, let photo):
                    if boxed {
                        buffer.appendInt32(2016442193)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    agency.serialize(buffer, true)
                    serializeInt32(startDate, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(endDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .workExperience(let flags, let id, let userId, let agency, let startDate, let endDate, let photo):
                return ("workExperience", [("flags", String(describing: flags)), ("id", String(describing: id)), ("userId", String(describing: userId)), ("agency", String(describing: agency)), ("startDate", String(describing: startDate)), ("endDate", String(describing: endDate)), ("photo", String(describing: photo))])
            }
        }

        public static func parse_workExperience(_ reader: BufferReader) -> WorkExperience? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.profile.Agency?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.profile.Agency
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt32() }
            var _7: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.profile.WorkExperience.workExperience(flags: _1!, id: _2!, userId: _3!, agency: _4!, startDate: _5!, endDate: _6, photo: _7)
            }
            else {
                return nil
            }
        }

    }
}
public extension Api.profile {
    enum WorkHistory: TypeConstructorDescription {
        case workHistory(count: Int32, experiences: [Api.profile.WorkExperience])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .workHistory(let count, let experiences):
                    if boxed {
                        buffer.appendInt32(-1178167755)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(experiences.count))
                    for item in experiences {
                        item.serialize(buffer, true)
                    }
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .workHistory(let count, let experiences):
                return ("workHistory", [("count", String(describing: count)), ("experiences", String(describing: experiences))])
            }
        }

        public static func parse_workHistory(_ reader: BufferReader) -> WorkHistory? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.profile.WorkExperience]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.profile.WorkExperience.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.profile.WorkHistory.workHistory(count: _1!, experiences: _2!)
            }
            else {
                return nil
            }
        }

    }
}
