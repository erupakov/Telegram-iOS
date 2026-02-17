//public extension Api {
//    enum Update: TypeConstructorDescription {
//        case update(event: Api.event.Short)
//        case updateApplicationApproved(eventId: Int64, eventTitle: String)
//        case updateApplicationRejected(eventId: Int64, eventTitle: String)
//        case updateEventLiked(flags: Int32, eventId: Int64, user: Api.event.User?)
//        case updateNewApplicant(flags: Int32, eventId: Int64, applicant: Api.event.User?)
//
//        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
//            switch self {
//                case .update(let event):
//                    if boxed {
//                        buffer.appendInt32(593489812)
//                    }
//                    event.serialize(buffer, true)
//                    break
//                case .updateApplicationApproved(let eventId, let eventTitle):
//                    if boxed {
//                        buffer.appendInt32(553287311)
//                    }
//                    serializeInt64(eventId, buffer: buffer, boxed: false)
//                    serializeString(eventTitle, buffer: buffer, boxed: false)
//                    break
//                case .updateApplicationRejected(let eventId, let eventTitle):
//                    if boxed {
//                        buffer.appendInt32(706653339)
//                    }
//                    serializeInt64(eventId, buffer: buffer, boxed: false)
//                    serializeString(eventTitle, buffer: buffer, boxed: false)
//                    break
//                case .updateEventLiked(let flags, let eventId, let user):
//                    if boxed {
//                        buffer.appendInt32(88932760)
//                    }
//                    serializeInt32(flags, buffer: buffer, boxed: false)
//                    serializeInt64(eventId, buffer: buffer, boxed: false)
//                    if Int(flags) & Int(1 << 0) != 0 {user!.serialize(buffer, true)}
//                    break
//                case .updateNewApplicant(let flags, let eventId, let applicant):
//                    if boxed {
//                        buffer.appendInt32(925133019)
//                    }
//                    serializeInt32(flags, buffer: buffer, boxed: false)
//                    serializeInt64(eventId, buffer: buffer, boxed: false)
//                    if Int(flags) & Int(1 << 0) != 0 {applicant!.serialize(buffer, true)}
//                    break
//            }
//        }
//        
//        public func descriptionFields() -> (String, [(String, Any)]) {
//            switch self {
//                case .update(let event):
//                return ("update", [("event", String(describing: event))])
//                case .updateApplicationApproved(let eventId, let eventTitle):
//                return ("updateApplicationApproved", [("eventId", String(describing: eventId)), ("eventTitle", String(describing: eventTitle))])
//                case .updateApplicationRejected(let eventId, let eventTitle):
//                return ("updateApplicationRejected", [("eventId", String(describing: eventId)), ("eventTitle", String(describing: eventTitle))])
//                case .updateEventLiked(let flags, let eventId, let user):
//                return ("updateEventLiked", [("flags", String(describing: flags)), ("eventId", String(describing: eventId)), ("user", String(describing: user))])
//                case .updateNewApplicant(let flags, let eventId, let applicant):
//                return ("updateNewApplicant", [("flags", String(describing: flags)), ("eventId", String(describing: eventId)), ("applicant", String(describing: applicant))])
//            }
//        }
//
//        public static func parse_update(_ reader: BufferReader) -> Update? {
//            var _1: Api.event.Short?
//            if let signature = reader.readInt32() {
//                _1 = Api.parse(reader, signature: signature) as? Api.event.Short
//            }
//            let _c1 = _1 != nil
//            if _c1 {
//                return Api.Update.update(event: _1!)
//            }
//            else {
//                return nil
//            }
//        }
//        public static func parse_updateApplicationApproved(_ reader: BufferReader) -> Update? {
//            var _1: Int64?
//            _1 = reader.readInt64()
//            var _2: String?
//            _2 = parseString(reader)
//            let _c1 = _1 != nil
//            let _c2 = _2 != nil
//            if _c1 && _c2 {
//                return Api.Update.updateApplicationApproved(eventId: _1!, eventTitle: _2!)
//            }
//            else {
//                return nil
//            }
//        }
//        public static func parse_updateApplicationRejected(_ reader: BufferReader) -> Update? {
//            var _1: Int64?
//            _1 = reader.readInt64()
//            var _2: String?
//            _2 = parseString(reader)
//            let _c1 = _1 != nil
//            let _c2 = _2 != nil
//            if _c1 && _c2 {
//                return Api.Update.updateApplicationRejected(eventId: _1!, eventTitle: _2!)
//            }
//            else {
//                return nil
//            }
//        }
//        public static func parse_updateEventLiked(_ reader: BufferReader) -> Update? {
//            var _1: Int32?
//            _1 = reader.readInt32()
//            var _2: Int64?
//            _2 = reader.readInt64()
//            var _3: Api.event.User?
//            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
//                _3 = Api.parse(reader, signature: signature) as? Api.event.User
//            } }
//            let _c1 = _1 != nil
//            let _c2 = _2 != nil
//            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
//            if _c1 && _c2 && _c3 {
//                return Api.Update.updateEventLiked(flags: _1!, eventId: _2!, user: _3)
//            }
//            else {
//                return nil
//            }
//        }
//        public static func parse_updateNewApplicant(_ reader: BufferReader) -> Update? {
//            var _1: Int32?
//            _1 = reader.readInt32()
//            var _2: Int64?
//            _2 = reader.readInt64()
//            var _3: Api.event.User?
//            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
//                _3 = Api.parse(reader, signature: signature) as? Api.event.User
//            } }
//            let _c1 = _1 != nil
//            let _c2 = _2 != nil
//            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
//            if _c1 && _c2 && _c3 {
//                return Api.Update.updateNewApplicant(flags: _1!, eventId: _2!, applicant: _3)
//            }
//            else {
//                return nil
//            }
//        }
//
//    }
//}
