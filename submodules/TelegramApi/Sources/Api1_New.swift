//
//  Api1_New.swift
//  Telegram
//
//  Created by Radomyr Sidenko on 08.09.2025.
//

public extension ApiNew {
    enum ModelInfo: TypeConstructorDescription {
        case modelInfo(flags: Int32, typeId: Int32, gender: Int32?, age: Int32?, name: String?, agencyName: String?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .modelInfo(let flags, let typeId, let gender, let age, let name, let agencyName):
//                    if boxed {
                        buffer.appendInt32(1974795807)
//                    }
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
                return ApiNew.ModelInfo.modelInfo(flags: _1!, typeId: _2!, gender: _3, age: _4, name: _5, agencyName: _6)
            }
            else {
                return nil
            }
        }

    }
}
public extension ApiNew.auth {
    enum Authorization: TypeConstructorDescription {
        case signUp(flags: Int32, phoneNumber: String, phoneCodeHash: String, firstName: String, lastName: String, modelInfo: ApiNew.ModelInfo?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
                case .signUp(let flags, let phoneNumber, let phoneCodeHash, let firstName, let lastName, let modelInfo):
                    if boxed {
                        buffer.appendInt32(1187678708)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {modelInfo!.serialize(buffer, true)}
                    break
            }
        }
        
        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
                case .signUp(let flags, let phoneNumber, let phoneCodeHash, let firstName, let lastName, let modelInfo):
                return ("signUp", [("flags", String(describing: flags)), ("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("modelInfo", String(describing: modelInfo))])
            }
        }

        public static func parse_signUp(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: ApiNew.ModelInfo?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = ApiNew.parse(reader, signature: signature) as? ApiNew.ModelInfo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return ApiNew.auth.Authorization.signUp(flags: _1!, phoneNumber: _2!, phoneCodeHash: _3!, firstName: _4!, lastName: _5!, modelInfo: _6)
            }
            else {
                return nil
            }
        }

    }
}

public extension ApiNew.functions.auth {
    static func signUp(flags: Int32, phoneNumber: String, phoneCodeHash: String, firstName: String, lastName: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<ApiNew.auth.Authorization>) {
        let buffer = Buffer()
        buffer.appendInt32(-1429752041)
        serializeInt32(flags, buffer: buffer, boxed: false)
        serializeString(phoneNumber, buffer: buffer, boxed: false)
        serializeString(phoneCodeHash, buffer: buffer, boxed: false)
        serializeString(firstName, buffer: buffer, boxed: false)
        serializeString(lastName, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "auth.signUp", parameters: [("flags", String(describing: flags)), ("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> ApiNew.auth.Authorization? in
            let reader = BufferReader(buffer)
            var result: ApiNew.auth.Authorization?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? ApiNew.auth.Authorization
            }
            return result
        })
    }
}
