public extension Api {
    enum AgencyRole: TypeConstructorDescription {
        case agencyRoleAgent
        case agencyRoleAll
        case agencyRoleBooker
        case agencyRoleOwner
        case agencyRoleScout

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .agencyRoleAgent:
                    if boxed {
                        buffer.appendInt32(179446145)
                    }
                    break
                case .agencyRoleAll:
                    if boxed {
                        buffer.appendInt32(-2032480205)
                    }
                    break
                case .agencyRoleBooker:
                    if boxed {
                        buffer.appendInt32(-675920387)
                    }
                    break
                case .agencyRoleOwner:
                    if boxed {
                        buffer.appendInt32(2015587456)
                    }
                    break
                case .agencyRoleScout:
                    if boxed {
                        buffer.appendInt32(1021882952)
                    }
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .agencyRoleAgent:
                return ("agencyRoleAgent", [])
                case .agencyRoleAll:
                return ("agencyRoleAll", [])
                case .agencyRoleBooker:
                return ("agencyRoleBooker", [])
                case .agencyRoleOwner:
                return ("agencyRoleOwner", [])
                case .agencyRoleScout:
                return ("agencyRoleScout", [])
            }
        }

        public static func parse_agencyRoleAgent(_ reader: BufferReader) -> AgencyRole? {
            return Api.AgencyRole.agencyRoleAgent
        }
        public static func parse_agencyRoleAll(_ reader: BufferReader) -> AgencyRole? {
            return Api.AgencyRole.agencyRoleAll
        }
        public static func parse_agencyRoleBooker(_ reader: BufferReader) -> AgencyRole? {
            return Api.AgencyRole.agencyRoleBooker
        }
        public static func parse_agencyRoleOwner(_ reader: BufferReader) -> AgencyRole? {
            return Api.AgencyRole.agencyRoleOwner
        }
        public static func parse_agencyRoleScout(_ reader: BufferReader) -> AgencyRole? {
            return Api.AgencyRole.agencyRoleScout
        }

    }
}
public extension Api {
    enum Gender: TypeConstructorDescription {
        case genderFemale
        case genderMale

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .genderFemale:
                    if boxed {
                        buffer.appendInt32(-694027777)
                    }
                    break
                case .genderMale:
                    if boxed {
                        buffer.appendInt32(1534712458)
                    }
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .genderFemale:
                return ("genderFemale", [])
                case .genderMale:
                return ("genderMale", [])
            }
        }

        public static func parse_genderFemale(_ reader: BufferReader) -> Gender? {
            return Api.Gender.genderFemale
        }
        public static func parse_genderMale(_ reader: BufferReader) -> Gender? {
            return Api.Gender.genderMale
        }

    }
}
public extension Api {
    enum Range: TypeConstructorDescription {
        case range(flags: Int32, value: Int64?, minValue: Int64?, maxValue: Int64?, avgValue: Int64?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .range(let flags, let value, let minValue, let maxValue, let avgValue):
                    if boxed {
                        buffer.appendInt32(-1325288322)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(value!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(minValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(maxValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(avgValue!, buffer: buffer, boxed: false)}
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .range(let flags, let value, let minValue, let maxValue, let avgValue):
                return ("range", [("flags", String(describing: flags)), ("value", String(describing: value)), ("minValue", String(describing: minValue)), ("maxValue", String(describing: maxValue)), ("avgValue", String(describing: avgValue))])
            }
        }

        public static func parse_range(_ reader: BufferReader) -> Range? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt64() }
            var _3: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = reader.readInt64() }
            var _4: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt64() }
            var _5: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt64() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Range.range(flags: _1!, value: _2, minValue: _3, maxValue: _4, avgValue: _5)
            }
            else {
                return nil
            }
        }

    }
}
