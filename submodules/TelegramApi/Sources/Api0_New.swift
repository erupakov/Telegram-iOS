//
//  Api0_New.swift
//  Telegram
//
//  Created by Radomyr Sidenko on 08.09.2025.
//

public enum ApiNew {
    public enum auth {}
    public enum functions {
        public enum auth {}
    }
}

fileprivate let parsers: [Int32 : (BufferReader) -> Any?] = {
    var dict: [Int32 : (BufferReader) -> Any?] = [:]
    dict[-1471112230] = { return $0.readInt32() }
    dict[570911930] = { return $0.readInt64() }
    dict[571523412] = { return $0.readDouble() }
    dict[-1255641564] = { return parseString($0) }
    dict[1974795807] = { return ApiNew.ModelInfo.parse_modelInfo($0) }
    dict[1187678708] = { return ApiNew.auth.Authorization.parse_signUp($0) }
    return dict
}()

public extension ApiNew {
    static func parse(_ buffer: Buffer) -> Any? {
        let reader = BufferReader(buffer)
        if let signature = reader.readInt32() {
            return parse(reader, signature: signature)
        }
        return nil
    }
    
    static func parse(_ reader: BufferReader, signature: Int32) -> Any? {
        if let parser = parsers[signature] {
            return parser(reader)
        }
        else {
            telegramApiLog("Type constructor \(String(signature, radix: 16, uppercase: false)) not found")
            return nil
        }
    }
        
    static func parseVector<T>(_ reader: BufferReader, elementSignature: Int32, elementType: T.Type) -> [T]? {
        if let count = reader.readInt32() {
            var array = [T]()
            var i: Int32 = 0
            while i < count {
                var signature = elementSignature
                if elementSignature == 0 {
                    if let unboxedSignature = reader.readInt32() {
                        signature = unboxedSignature
                    }
                    else {
                        return nil
                    }
                }
                if elementType == Buffer.self {
                    if let item = parseBytes(reader) as? T {
                        array.append(item)
                    } else {
                        return nil
                    }
                } else {
                if let item = ApiNew.parse(reader, signature: signature) as? T {
                    array.append(item)
                }
                else {
                    return nil
                }
                }
                i += 1
            }
            return array
        }
        return nil
    }
    
    static func serializeObject(_ object: Any, buffer: Buffer, boxed: Swift.Bool) {
        switch object {
            case let _1 as ApiNew.ModelInfo:
                _1.serialize(buffer, boxed)
            case let _1 as ApiNew.auth.Authorization:
                _1.serialize(buffer, boxed)
            default:
                break
        }
    }

}
