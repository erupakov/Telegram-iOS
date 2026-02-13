public extension Api.functions.profile {
    static func createWorkExperience(flags: Int32, agency: Api.profile.Agency, startDate: Int32, endDate: Int32?, photoId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.WorkExperience>) {
        let buffer = Buffer()
        buffer.appendInt32(2045881312)
        serializeInt32(flags, buffer: buffer, boxed: false)
        agency.serialize(buffer, true)
        serializeInt32(startDate, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 1) != 0 {serializeInt32(endDate!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 2) != 0 {serializeInt64(photoId!, buffer: buffer, boxed: false)}
        return (FunctionDescription(name: "profile.createWorkExperience", parameters: [("flags", String(describing: flags)), ("agency", String(describing: agency)), ("startDate", String(describing: startDate)), ("endDate", String(describing: endDate)), ("photoId", String(describing: photoId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.WorkExperience? in
            let reader = BufferReader(buffer)
            var result: Api.profile.WorkExperience?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.WorkExperience
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func deletePortfolioItem(id: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-319345294)
        serializeInt64(id, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.deletePortfolioItem", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func deleteWorkExperience(id: Int64) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-167521312)
        serializeInt64(id, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.deleteWorkExperience", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func getAgencyModels(agencyId: Int64, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.FoundUsers>) {
        let buffer = Buffer()
        buffer.appendInt32(-267612773)
        serializeInt64(agencyId, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.getAgencyModels", parameters: [("agencyId", String(describing: agencyId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.FoundUsers? in
            let reader = BufferReader(buffer)
            var result: Api.profile.FoundUsers?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.FoundUsers
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func getLikedUsers(offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.UsersList>) {
        let buffer = Buffer()
        buffer.appendInt32(-800221945)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.getLikedUsers", parameters: [("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.UsersList? in
            let reader = BufferReader(buffer)
            var result: Api.profile.UsersList?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.UsersList
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func getPortfolio(userId: Api.InputUser, tab: String, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.Portfolio>) {
        let buffer = Buffer()
        buffer.appendInt32(185951911)
        userId.serialize(buffer, true)
        serializeString(tab, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.getPortfolio", parameters: [("userId", String(describing: userId)), ("tab", String(describing: tab)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.Portfolio? in
            let reader = BufferReader(buffer)
            var result: Api.profile.Portfolio?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.Portfolio
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func getSavedUsers(offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.UsersList>) {
        let buffer = Buffer()
        buffer.appendInt32(630011370)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.getSavedUsers", parameters: [("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.UsersList? in
            let reader = BufferReader(buffer)
            var result: Api.profile.UsersList?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.UsersList
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func getSearchConfig(hash: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.SearchConfig>) {
        let buffer = Buffer()
        buffer.appendInt32(-906125800)
        serializeInt32(hash, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.getSearchConfig", parameters: [("hash", String(describing: hash))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.SearchConfig? in
            let reader = BufferReader(buffer)
            var result: Api.profile.SearchConfig?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.SearchConfig
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func getViewedUsers(offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.UsersList>) {
        let buffer = Buffer()
        buffer.appendInt32(1129304592)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.getViewedUsers", parameters: [("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.UsersList? in
            let reader = BufferReader(buffer)
            var result: Api.profile.UsersList?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.UsersList
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func getWorkHistory(userId: Api.InputUser, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.WorkHistory>) {
        let buffer = Buffer()
        buffer.appendInt32(-1772685853)
        userId.serialize(buffer, true)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.getWorkHistory", parameters: [("userId", String(describing: userId)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.WorkHistory? in
            let reader = BufferReader(buffer)
            var result: Api.profile.WorkHistory?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.WorkHistory
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func registerView(userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(1512812189)
        userId.serialize(buffer, true)
        return (FunctionDescription(name: "profile.registerView", parameters: [("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func searchAgencies(query: String, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.FoundAgencies>) {
        let buffer = Buffer()
        buffer.appendInt32(1227505917)
        serializeString(query, buffer: buffer, boxed: false)
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.searchAgencies", parameters: [("query", String(describing: query)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.FoundAgencies? in
            let reader = BufferReader(buffer)
            var result: Api.profile.FoundAgencies?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.FoundAgencies
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func searchUsers(flags: Int32, genders: [String]?, age: Api.Range?, height: Api.Range?, waist: Api.Range?, hips: Api.Range?, shoeSize: Api.Range?, hairColors: [String]?, hairLength: Api.Range?, eyeColors: [String]?, skinColors: [String]?, breastSizes: [String]?, offset: Int32, limit: Int32) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.FoundUsers>) {
        let buffer = Buffer()
        buffer.appendInt32(-1465029891)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(genders!.count))
        for item in genders! {
            serializeString(item, buffer: buffer, boxed: false)
        }}
        if Int(flags) & Int(1 << 1) != 0 {age!.serialize(buffer, true)}
        if Int(flags) & Int(1 << 2) != 0 {height!.serialize(buffer, true)}
        if Int(flags) & Int(1 << 3) != 0 {waist!.serialize(buffer, true)}
        if Int(flags) & Int(1 << 4) != 0 {hips!.serialize(buffer, true)}
        if Int(flags) & Int(1 << 5) != 0 {shoeSize!.serialize(buffer, true)}
        if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(hairColors!.count))
        for item in hairColors! {
            serializeString(item, buffer: buffer, boxed: false)
        }}
        if Int(flags) & Int(1 << 7) != 0 {hairLength!.serialize(buffer, true)}
        if Int(flags) & Int(1 << 8) != 0 {buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(eyeColors!.count))
        for item in eyeColors! {
            serializeString(item, buffer: buffer, boxed: false)
        }}
        if Int(flags) & Int(1 << 9) != 0 {buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(skinColors!.count))
        for item in skinColors! {
            serializeString(item, buffer: buffer, boxed: false)
        }}
        if Int(flags) & Int(1 << 10) != 0 {buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(breastSizes!.count))
        for item in breastSizes! {
            serializeString(item, buffer: buffer, boxed: false)
        }}
        serializeInt32(offset, buffer: buffer, boxed: false)
        serializeInt32(limit, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.searchUsers", parameters: [("flags", String(describing: flags)), ("genders", String(describing: genders)), ("age", String(describing: age)), ("height", String(describing: height)), ("waist", String(describing: waist)), ("hips", String(describing: hips)), ("shoeSize", String(describing: shoeSize)), ("hairColors", String(describing: hairColors)), ("hairLength", String(describing: hairLength)), ("eyeColors", String(describing: eyeColors)), ("skinColors", String(describing: skinColors)), ("breastSizes", String(describing: breastSizes)), ("offset", String(describing: offset)), ("limit", String(describing: limit))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.FoundUsers? in
            let reader = BufferReader(buffer)
            var result: Api.profile.FoundUsers?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.FoundUsers
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func toggleLike(userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(13003584)
        userId.serialize(buffer, true)
        return (FunctionDescription(name: "profile.toggleLike", parameters: [("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func toggleSave(userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(1143000937)
        userId.serialize(buffer, true)
        return (FunctionDescription(name: "profile.toggleSave", parameters: [("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func updateProfile(flags: Int32, firstName: String?, lastName: String?, country: String?, about: String?, gender: Api.Gender?, birthDate: Int32?, height: Int32?, waist: Int32?, hips: Int32?, shoeSize: Int32?, hairLength: Int32?, hairColor: String?, eyeColor: String?, skinColor: String?, breastSize: String?, photoId: Int64?, backgroundId: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UserProfile>) {
        let buffer = Buffer()
        buffer.appendInt32(-2079856034)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {serializeString(firstName!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 1) != 0 {serializeString(lastName!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 2) != 0 {serializeString(country!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 3) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 4) != 0 {gender!.serialize(buffer, true)}
        if Int(flags) & Int(1 << 5) != 0 {serializeInt32(birthDate!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 6) != 0 {serializeInt32(height!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 7) != 0 {serializeInt32(waist!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 8) != 0 {serializeInt32(hips!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 9) != 0 {serializeInt32(shoeSize!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 10) != 0 {serializeInt32(hairLength!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 11) != 0 {serializeString(hairColor!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 12) != 0 {serializeString(eyeColor!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 13) != 0 {serializeString(skinColor!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 14) != 0 {serializeString(breastSize!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 15) != 0 {serializeInt64(photoId!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 16) != 0 {serializeInt64(backgroundId!, buffer: buffer, boxed: false)}
        return (FunctionDescription(name: "profile.updateProfile", parameters: [("flags", String(describing: flags)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("country", String(describing: country)), ("about", String(describing: about)), ("gender", String(describing: gender)), ("birthDate", String(describing: birthDate)), ("height", String(describing: height)), ("waist", String(describing: waist)), ("hips", String(describing: hips)), ("shoeSize", String(describing: shoeSize)), ("hairLength", String(describing: hairLength)), ("hairColor", String(describing: hairColor)), ("eyeColor", String(describing: eyeColor)), ("skinColor", String(describing: skinColor)), ("breastSize", String(describing: breastSize)), ("photoId", String(describing: photoId)), ("backgroundId", String(describing: backgroundId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UserProfile? in
            let reader = BufferReader(buffer)
            var result: Api.UserProfile?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.UserProfile
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func updateSocialLinks(flags: Int32, instagram: String?, tiktok: String?, youtube: String?, website: String?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UserProfile>) {
        let buffer = Buffer()
        buffer.appendInt32(-329193826)
        serializeInt32(flags, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 0) != 0 {serializeString(instagram!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 1) != 0 {serializeString(tiktok!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 2) != 0 {serializeString(youtube!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 3) != 0 {serializeString(website!, buffer: buffer, boxed: false)}
        return (FunctionDescription(name: "profile.updateSocialLinks", parameters: [("flags", String(describing: flags)), ("instagram", String(describing: instagram)), ("tiktok", String(describing: tiktok)), ("youtube", String(describing: youtube)), ("website", String(describing: website))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UserProfile? in
            let reader = BufferReader(buffer)
            var result: Api.UserProfile?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.UserProfile
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func updateWorkExperience(flags: Int32, id: Int64, agency: Api.profile.Agency?, startDate: Int32?, endDate: Int32?, photo: Api.Photo?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.WorkExperience>) {
        let buffer = Buffer()
        buffer.appendInt32(-1496808634)
        serializeInt32(flags, buffer: buffer, boxed: false)
        serializeInt64(id, buffer: buffer, boxed: false)
        if Int(flags) & Int(1 << 1) != 0 {agency!.serialize(buffer, true)}
        if Int(flags) & Int(1 << 2) != 0 {serializeInt32(startDate!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 3) != 0 {serializeInt32(endDate!, buffer: buffer, boxed: false)}
        if Int(flags) & Int(1 << 4) != 0 {photo!.serialize(buffer, true)}
        return (FunctionDescription(name: "profile.updateWorkExperience", parameters: [("flags", String(describing: flags)), ("id", String(describing: id)), ("agency", String(describing: agency)), ("startDate", String(describing: startDate)), ("endDate", String(describing: endDate)), ("photo", String(describing: photo))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.WorkExperience? in
            let reader = BufferReader(buffer)
            var result: Api.profile.WorkExperience?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.WorkExperience
            }
            return result
        })
    }
}
public extension Api.functions.profile {
    static func uploadPortfolioItem(file: Api.InputFile, type: String) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.profile.PortfolioItem>) {
        let buffer = Buffer()
        buffer.appendInt32(-1558106417)
        file.serialize(buffer, true)
        serializeString(type, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "profile.uploadPortfolioItem", parameters: [("file", String(describing: file)), ("type", String(describing: type))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.profile.PortfolioItem? in
            let reader = BufferReader(buffer)
            var result: Api.profile.PortfolioItem?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.profile.PortfolioItem
            }
            return result
        })
    }
}

public extension Api.functions.profile {
    static func getUserProfile(userId: Api.InputUser) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.UserProfile>) {
        let buffer = Buffer()
        buffer.appendInt32(504379527)
        userId.serialize(buffer, true)
        return (FunctionDescription(name: "profile.getUserProfile", parameters: [("userId", String(describing: userId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.UserProfile? in
            let reader = BufferReader(buffer)
            var result: Api.UserProfile?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.UserProfile
            }
            return result
        })
    }
}
