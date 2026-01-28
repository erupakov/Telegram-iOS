public extension Api {
    enum UserProfile: TypeConstructorDescription {
        case userProfile(flags: Int32, userId: Int64, country: String?, city: String?, gender: Api.Gender?, birthDate: Int64?, role: Api.AgencyRole?, about: String?, physicalParams: Api.profile.PhysicalParams?, stats: Api.profile.Stats?, portfolio: Api.profile.Portfolio?, socialLinks: Api.profile.SocialLinks?, agency: Api.profile.Agency?)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .userProfile(let flags, let userId, let country, let city, let gender, let birthDate, let role, let about, let physicalParams, let stats, let portfolio, let socialLinks, let agency):
                if boxed {
                    buffer.appendInt32(-1676832783)
                }
                serializeInt32(flags, buffer: buffer, boxed: false)
                serializeInt64(userId, buffer: buffer, boxed: false)
                if Int(flags) & Int(1 << 0) != 0 {serializeString(country!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 1) != 0 {serializeString(city!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 2) != 0 {gender!.serialize(buffer, true)}
                if Int(flags) & Int(1 << 3) != 0 {serializeInt64(birthDate!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 4) != 0 {role!.serialize(buffer, true)}
                if Int(flags) & Int(1 << 5) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 6) != 0 {physicalParams!.serialize(buffer, true)}
                if Int(flags) & Int(1 << 7) != 0 {stats!.serialize(buffer, true)}
                if Int(flags) & Int(1 << 8) != 0 {portfolio!.serialize(buffer, true)}
                if Int(flags) & Int(1 << 9) != 0 {socialLinks!.serialize(buffer, true)}
                if Int(flags) & Int(1 << 10) != 0 {agency!.serialize(buffer, true)}
                break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .userProfile(let flags, let userId, let country, let city, let gender, let birthDate, let role, let about, let physicalParams, let stats, let portfolio, let socialLinks, let agency):
                return ("userProfile", [("flags", String(describing: flags)), ("userId", String(describing: userId)), ("country", String(describing: country)), ("city", String(describing: city)), ("gender", String(describing: gender)), ("birthDate", String(describing: birthDate)), ("role", String(describing: role)), ("about", String(describing: about)), ("physicalParams", String(describing: physicalParams)), ("stats", String(describing: stats)), ("portfolio", String(describing: portfolio)), ("socialLinks", String(describing: socialLinks)), ("agency", String(describing: agency))])
            }
        }
        
        public static func parse_userProfile(_ reader: BufferReader) -> UserProfile? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: Api.Gender?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Gender
            } }
            var _6: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = reader.readInt64() }
            var _7: Api.AgencyRole?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.AgencyRole
            } }
            var _8: String?
            if Int(_1!) & Int(1 << 5) != 0 {_8 = parseString(reader) }
            var _9: Api.profile.PhysicalParams?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.profile.PhysicalParams
            } }
            var _10: Api.profile.Stats?
            if Int(_1!) & Int(1 << 7) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.profile.Stats
            } }
            var _11: Api.profile.Portfolio?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.profile.Portfolio
            } }
            var _12: Api.profile.SocialLinks?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.profile.SocialLinks
            } }
            var _13: Api.profile.Agency?
            if Int(_1!) & Int(1 << 10) != 0 {if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.profile.Agency
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 7) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 8) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 9) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 10) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.UserProfile.userProfile(flags: _1!, userId: _2!, country: _3, city: _4, gender: _5, birthDate: _6, role: _7, about: _8, physicalParams: _9, stats: _10, portfolio: _11, socialLinks: _12, agency: _13)
            }
            else {
                return nil
            }
        }
        
    }
}
