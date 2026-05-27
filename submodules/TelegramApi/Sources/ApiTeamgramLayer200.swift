import Foundation

// DIVO: парсеры для constructor'ов teamgram-сервера layer 200/201.
//
// Eugene держит стэйдж teamgram-сервера на layer 200, а наш TL-словарь — от свежего
// апстрима Telegram-iOS (layer 222+). Большинство типов изменились между версиями;
// здесь — алиас-парсеры, которые знают как раскодировать старые байт-форматы и
// возвращают тот же тип Api.Message что и наш текущий parse_message, заполняя
// поля которых не было в старой схеме как nil.
//
// Извлечено из апстрим-коммита 1dd07df394^ (период когда апстрим работал на той же
// схеме что и teamgram). Дополнительные поля нашей текущей Cons-структуры
// (suggestedPost, scheduleRepeatPeriod, summaryFromLanguage, savedPeerId для
// messageService) заполняются nil — они в layer 200 ещё не существовали.
//
// Регистрация constructor → parser сделана в Api0.swift рядом со стандартными
// dict[]-записями (см. DIVO-комментарий).
public extension Api.Message {
    // message#eabcdd4d (layer 200-205)
    static func parse_message_teamgram_layer200(_ reader: BufferReader) -> Api.Message? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Int32?
        _2 = reader.readInt32()
        var _3: Int32?
        _3 = reader.readInt32()
        var _4: Api.Peer?
        if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
            _4 = Api.parse(reader, signature: signature) as? Api.Peer
        } }
        var _5: Int32?
        if Int(_1!) & Int(1 << 29) != 0 {_5 = reader.readInt32() }
        var _6: Api.Peer?
        if let signature = reader.readInt32() {
            _6 = Api.parse(reader, signature: signature) as? Api.Peer
        }
        var _7: Api.Peer?
        if Int(_1!) & Int(1 << 28) != 0 {if let signature = reader.readInt32() {
            _7 = Api.parse(reader, signature: signature) as? Api.Peer
        } }
        var _8: Api.MessageFwdHeader?
        if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
            _8 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
        } }
        var _9: Int64?
        if Int(_1!) & Int(1 << 11) != 0 {_9 = reader.readInt64() }
        var _10: Int64?
        if Int(_2!) & Int(1 << 0) != 0 {_10 = reader.readInt64() }
        var _11: Api.MessageReplyHeader?
        if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
            _11 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
        } }
        var _12: Int32?
        _12 = reader.readInt32()
        var _13: String?
        _13 = parseString(reader)
        var _14: Api.MessageMedia?
        if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
            _14 = Api.parse(reader, signature: signature) as? Api.MessageMedia
        } }
        var _15: Api.ReplyMarkup?
        if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
            _15 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
        } }
        var _16: [Api.MessageEntity]?
        if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
            _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
        } }
        var _17: Int32?
        if Int(_1!) & Int(1 << 10) != 0 {_17 = reader.readInt32() }
        var _18: Int32?
        if Int(_1!) & Int(1 << 10) != 0 {_18 = reader.readInt32() }
        var _19: Api.MessageReplies?
        if Int(_1!) & Int(1 << 23) != 0 {if let signature = reader.readInt32() {
            _19 = Api.parse(reader, signature: signature) as? Api.MessageReplies
        } }
        var _20: Int32?
        if Int(_1!) & Int(1 << 15) != 0 {_20 = reader.readInt32() }
        var _21: String?
        if Int(_1!) & Int(1 << 16) != 0 {_21 = parseString(reader) }
        var _22: Int64?
        if Int(_1!) & Int(1 << 17) != 0 {_22 = reader.readInt64() }
        var _23: Api.MessageReactions?
        if Int(_1!) & Int(1 << 20) != 0 {if let signature = reader.readInt32() {
            _23 = Api.parse(reader, signature: signature) as? Api.MessageReactions
        } }
        var _24: [Api.RestrictionReason]?
        if Int(_1!) & Int(1 << 22) != 0 {if let _ = reader.readInt32() {
            _24 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
        } }
        var _25: Int32?
        if Int(_1!) & Int(1 << 25) != 0 {_25 = reader.readInt32() }
        var _26: Int32?
        if Int(_1!) & Int(1 << 30) != 0 {_26 = reader.readInt32() }
        var _27: Int64?
        if Int(_2!) & Int(1 << 2) != 0 {_27 = reader.readInt64() }
        var _28: Api.FactCheck?
        if Int(_2!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
            _28 = Api.parse(reader, signature: signature) as? Api.FactCheck
        } }
        var _29: Int32?
        if Int(_2!) & Int(1 << 5) != 0 {_29 = reader.readInt32() }
        var _30: Int64?
        if Int(_2!) & Int(1 << 6) != 0 {_30 = reader.readInt64() }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = _3 != nil
        let _c4 = (Int(_1!) & Int(1 << 8) == 0) || _4 != nil
        let _c5 = (Int(_1!) & Int(1 << 29) == 0) || _5 != nil
        let _c6 = _6 != nil
        let _c7 = (Int(_1!) & Int(1 << 28) == 0) || _7 != nil
        let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
        let _c9 = (Int(_1!) & Int(1 << 11) == 0) || _9 != nil
        let _c10 = (Int(_2!) & Int(1 << 0) == 0) || _10 != nil
        let _c11 = (Int(_1!) & Int(1 << 3) == 0) || _11 != nil
        let _c12 = _12 != nil
        let _c13 = _13 != nil
        let _c14 = (Int(_1!) & Int(1 << 9) == 0) || _14 != nil
        let _c15 = (Int(_1!) & Int(1 << 6) == 0) || _15 != nil
        let _c16 = (Int(_1!) & Int(1 << 7) == 0) || _16 != nil
        let _c17 = (Int(_1!) & Int(1 << 10) == 0) || _17 != nil
        let _c18 = (Int(_1!) & Int(1 << 10) == 0) || _18 != nil
        let _c19 = (Int(_1!) & Int(1 << 23) == 0) || _19 != nil
        let _c20 = (Int(_1!) & Int(1 << 15) == 0) || _20 != nil
        let _c21 = (Int(_1!) & Int(1 << 16) == 0) || _21 != nil
        let _c22 = (Int(_1!) & Int(1 << 17) == 0) || _22 != nil
        let _c23 = (Int(_1!) & Int(1 << 20) == 0) || _23 != nil
        let _c24 = (Int(_1!) & Int(1 << 22) == 0) || _24 != nil
        let _c25 = (Int(_1!) & Int(1 << 25) == 0) || _25 != nil
        let _c26 = (Int(_1!) & Int(1 << 30) == 0) || _26 != nil
        let _c27 = (Int(_2!) & Int(1 << 2) == 0) || _27 != nil
        let _c28 = (Int(_2!) & Int(1 << 3) == 0) || _28 != nil
        let _c29 = (Int(_2!) & Int(1 << 5) == 0) || _29 != nil
        let _c30 = (Int(_2!) & Int(1 << 6) == 0) || _30 != nil
        if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 && _c27 && _c28 && _c29 && _c30 {
            // suggestedPost / scheduleRepeatPeriod / summaryFromLanguage не существовали в layer 200 → nil
            return Api.Message.message(Api.Message.Cons_message(flags: _1!, flags2: _2!, id: _3!, fromId: _4, fromBoostsApplied: _5, peerId: _6!, savedPeerId: _7, fwdFrom: _8, viaBotId: _9, viaBusinessBotId: _10, replyTo: _11, date: _12!, message: _13!, media: _14, replyMarkup: _15, entities: _16, views: _17, forwards: _18, replies: _19, editDate: _20, postAuthor: _21, groupedId: _22, reactions: _23, restrictionReason: _24, ttlPeriod: _25, quickReplyShortcutId: _26, effect: _27, factcheck: _28, reportDeliveryUntilDate: _29, paidMessageStars: _30, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil))
        } else {
            return nil
        }
    }

}

public extension Api.Chat {
    // channel#7482147e (layer 200-203) — структура полей та же что и в нашем layer 222 Cons_channel,
    // КРОМЕ: stories_max_id в layer 200/201 это Int32, в нашей схеме это boxed Api.RecentStory? →
    // читаем Int32 чтобы не сломать byte-stream, передаём storiesMaxId: nil.
    // linkedMonoforumId не существовало в layer 200 → nil.
    static func parse_channel_teamgram_layer200(_ reader: BufferReader) -> Api.Chat? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Int32?
        _2 = reader.readInt32()
        var _3: Int64?
        _3 = reader.readInt64()
        var _4: Int64?
        if Int(_1!) & Int(1 << 13) != 0 {_4 = reader.readInt64() }
        var _5: String?
        _5 = parseString(reader)
        var _6: String?
        if Int(_1!) & Int(1 << 6) != 0 {_6 = parseString(reader) }
        var _7: Api.ChatPhoto?
        if let signature = reader.readInt32() {
            _7 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
        }
        var _8: Int32?
        _8 = reader.readInt32()
        var _9: [Api.RestrictionReason]?
        if Int(_1!) & Int(1 << 9) != 0 {if let _ = reader.readInt32() {
            _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
        } }
        var _10: Api.ChatAdminRights?
        if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
            _10 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
        } }
        var _11: Api.ChatBannedRights?
        if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
            _11 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
        } }
        var _12: Api.ChatBannedRights?
        if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
            _12 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
        } }
        var _13: Int32?
        if Int(_1!) & Int(1 << 17) != 0 {_13 = reader.readInt32() }
        var _14: [Api.Username]?
        if Int(_2!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
            _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Username.self)
        } }
        // stories_max_id Int32 в layer 200; в текущей схеме это boxed RecentStory.
        // Читаем Int32 чтобы не сломать поток, далее в Cons_channel передаём nil.
        var _15: Int32?
        if Int(_2!) & Int(1 << 4) != 0 {_15 = reader.readInt32() }
        _ = _15
        var _16: Api.PeerColor?
        if Int(_2!) & Int(1 << 7) != 0 {if let signature = reader.readInt32() {
            _16 = Api.parse(reader, signature: signature) as? Api.PeerColor
        } }
        var _17: Api.PeerColor?
        if Int(_2!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
            _17 = Api.parse(reader, signature: signature) as? Api.PeerColor
        } }
        var _18: Api.EmojiStatus?
        if Int(_2!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
            _18 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
        } }
        var _19: Int32?
        if Int(_2!) & Int(1 << 10) != 0 {_19 = reader.readInt32() }
        var _20: Int32?
        if Int(_2!) & Int(1 << 11) != 0 {_20 = reader.readInt32() }
        var _21: Int64?
        if Int(_2!) & Int(1 << 13) != 0 {_21 = reader.readInt64() }
        var _22: Int64?
        if Int(_2!) & Int(1 << 14) != 0 {_22 = reader.readInt64() }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = _3 != nil
        let _c4 = (Int(_1!) & Int(1 << 13) == 0) || _4 != nil
        let _c5 = _5 != nil
        let _c6 = (Int(_1!) & Int(1 << 6) == 0) || _6 != nil
        let _c7 = _7 != nil
        let _c8 = _8 != nil
        let _c9 = (Int(_1!) & Int(1 << 9) == 0) || _9 != nil
        let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
        let _c11 = (Int(_1!) & Int(1 << 15) == 0) || _11 != nil
        let _c12 = (Int(_1!) & Int(1 << 18) == 0) || _12 != nil
        let _c13 = (Int(_1!) & Int(1 << 17) == 0) || _13 != nil
        let _c14 = (Int(_2!) & Int(1 << 0) == 0) || _14 != nil
        let _c15 = (Int(_2!) & Int(1 << 4) == 0) || _15 != nil
        let _c16 = (Int(_2!) & Int(1 << 7) == 0) || _16 != nil
        let _c17 = (Int(_2!) & Int(1 << 8) == 0) || _17 != nil
        let _c18 = (Int(_2!) & Int(1 << 9) == 0) || _18 != nil
        let _c19 = (Int(_2!) & Int(1 << 10) == 0) || _19 != nil
        let _c20 = (Int(_2!) & Int(1 << 11) == 0) || _20 != nil
        let _c21 = (Int(_2!) & Int(1 << 13) == 0) || _21 != nil
        let _c22 = (Int(_2!) & Int(1 << 14) == 0) || _22 != nil
        if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 {
            return Api.Chat.channel(Api.Chat.Cons_channel(flags: _1!, flags2: _2!, id: _3!, accessHash: _4, title: _5!, username: _6, photo: _7!, date: _8!, restrictionReason: _9, adminRights: _10, bannedRights: _11, defaultBannedRights: _12, participantsCount: _13, usernames: _14, storiesMaxId: nil, color: _16, profileColor: _17, emojiStatus: _18, level: _19, subscriptionUntilDate: _20, botVerificationIcon: _21, sendPaidMessagesStars: _22, linkedMonoforumId: nil))
        } else {
            return nil
        }
    }

}

public extension Api.ChatFull {
    // channelFull#52d6806b (layer 200-201) — 45 полей. В нашем текущем Cons_channelFull
    // (47 полей) дополнительно sendPaidMessagesStars и mainTab → nil.
    // Извлечено из апстрим-коммита 06eaf81fa9^.
    static func parse_channelFull_teamgram_layer201(_ reader: BufferReader) -> Api.ChatFull? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Int32?
        _2 = reader.readInt32()
        var _3: Int64?
        _3 = reader.readInt64()
        var _4: String?
        _4 = parseString(reader)
        var _5: Int32?
        if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
        var _6: Int32?
        if Int(_1!) & Int(1 << 1) != 0 {_6 = reader.readInt32() }
        var _7: Int32?
        if Int(_1!) & Int(1 << 2) != 0 {_7 = reader.readInt32() }
        var _8: Int32?
        if Int(_1!) & Int(1 << 2) != 0 {_8 = reader.readInt32() }
        var _9: Int32?
        if Int(_1!) & Int(1 << 13) != 0 {_9 = reader.readInt32() }
        var _10: Int32?
        _10 = reader.readInt32()
        var _11: Int32?
        _11 = reader.readInt32()
        var _12: Int32?
        _12 = reader.readInt32()
        var _13: Api.Photo?
        if let signature = reader.readInt32() {
            _13 = Api.parse(reader, signature: signature) as? Api.Photo
        }
        var _14: Api.PeerNotifySettings?
        if let signature = reader.readInt32() {
            _14 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
        }
        var _15: Api.ExportedChatInvite?
        if Int(_1!) & Int(1 << 23) != 0 {if let signature = reader.readInt32() {
            _15 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
        } }
        var _16: [Api.BotInfo]?
        if let _ = reader.readInt32() {
            _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInfo.self)
        }
        var _17: Int64?
        if Int(_1!) & Int(1 << 4) != 0 {_17 = reader.readInt64() }
        var _18: Int32?
        if Int(_1!) & Int(1 << 4) != 0 {_18 = reader.readInt32() }
        var _19: Int32?
        if Int(_1!) & Int(1 << 5) != 0 {_19 = reader.readInt32() }
        var _20: Api.StickerSet?
        if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
            _20 = Api.parse(reader, signature: signature) as? Api.StickerSet
        } }
        var _21: Int32?
        if Int(_1!) & Int(1 << 9) != 0 {_21 = reader.readInt32() }
        var _22: Int32?
        if Int(_1!) & Int(1 << 11) != 0 {_22 = reader.readInt32() }
        var _23: Int64?
        if Int(_1!) & Int(1 << 14) != 0 {_23 = reader.readInt64() }
        var _24: Api.ChannelLocation?
        if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
            _24 = Api.parse(reader, signature: signature) as? Api.ChannelLocation
        } }
        var _25: Int32?
        if Int(_1!) & Int(1 << 17) != 0 {_25 = reader.readInt32() }
        var _26: Int32?
        if Int(_1!) & Int(1 << 18) != 0 {_26 = reader.readInt32() }
        var _27: Int32?
        if Int(_1!) & Int(1 << 12) != 0 {_27 = reader.readInt32() }
        var _28: Int32?
        _28 = reader.readInt32()
        var _29: Api.InputGroupCall?
        if Int(_1!) & Int(1 << 21) != 0 {if let signature = reader.readInt32() {
            _29 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
        } }
        var _30: Int32?
        if Int(_1!) & Int(1 << 24) != 0 {_30 = reader.readInt32() }
        var _31: [String]?
        if Int(_1!) & Int(1 << 25) != 0 {if let _ = reader.readInt32() {
            _31 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
        } }
        var _32: Api.Peer?
        if Int(_1!) & Int(1 << 26) != 0 {if let signature = reader.readInt32() {
            _32 = Api.parse(reader, signature: signature) as? Api.Peer
        } }
        var _33: String?
        if Int(_1!) & Int(1 << 27) != 0 {_33 = parseString(reader) }
        var _34: Int32?
        if Int(_1!) & Int(1 << 28) != 0 {_34 = reader.readInt32() }
        var _35: [Int64]?
        if Int(_1!) & Int(1 << 28) != 0 {if let _ = reader.readInt32() {
            _35 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
        } }
        var _36: Api.Peer?
        if Int(_1!) & Int(1 << 29) != 0 {if let signature = reader.readInt32() {
            _36 = Api.parse(reader, signature: signature) as? Api.Peer
        } }
        var _37: Api.ChatReactions?
        if Int(_1!) & Int(1 << 30) != 0 {if let signature = reader.readInt32() {
            _37 = Api.parse(reader, signature: signature) as? Api.ChatReactions
        } }
        var _38: Int32?
        if Int(_2!) & Int(1 << 13) != 0 {_38 = reader.readInt32() }
        var _39: Api.PeerStories?
        if Int(_2!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
            _39 = Api.parse(reader, signature: signature) as? Api.PeerStories
        } }
        var _40: Api.WallPaper?
        if Int(_2!) & Int(1 << 7) != 0 {if let signature = reader.readInt32() {
            _40 = Api.parse(reader, signature: signature) as? Api.WallPaper
        } }
        var _41: Int32?
        if Int(_2!) & Int(1 << 8) != 0 {_41 = reader.readInt32() }
        var _42: Int32?
        if Int(_2!) & Int(1 << 9) != 0 {_42 = reader.readInt32() }
        var _43: Api.StickerSet?
        if Int(_2!) & Int(1 << 10) != 0 {if let signature = reader.readInt32() {
            _43 = Api.parse(reader, signature: signature) as? Api.StickerSet
        } }
        var _44: Api.BotVerification?
        if Int(_2!) & Int(1 << 17) != 0 {if let signature = reader.readInt32() {
            _44 = Api.parse(reader, signature: signature) as? Api.BotVerification
        } }
        var _45: Int32?
        if Int(_2!) & Int(1 << 18) != 0 {_45 = reader.readInt32() }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = _3 != nil
        let _c4 = _4 != nil
        let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
        let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
        let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
        let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
        let _c9 = (Int(_1!) & Int(1 << 13) == 0) || _9 != nil
        let _c10 = _10 != nil
        let _c11 = _11 != nil
        let _c12 = _12 != nil
        let _c13 = _13 != nil
        let _c14 = _14 != nil
        let _c15 = (Int(_1!) & Int(1 << 23) == 0) || _15 != nil
        let _c16 = _16 != nil
        let _c17 = (Int(_1!) & Int(1 << 4) == 0) || _17 != nil
        let _c18 = (Int(_1!) & Int(1 << 4) == 0) || _18 != nil
        let _c19 = (Int(_1!) & Int(1 << 5) == 0) || _19 != nil
        let _c20 = (Int(_1!) & Int(1 << 8) == 0) || _20 != nil
        let _c21 = (Int(_1!) & Int(1 << 9) == 0) || _21 != nil
        let _c22 = (Int(_1!) & Int(1 << 11) == 0) || _22 != nil
        let _c23 = (Int(_1!) & Int(1 << 14) == 0) || _23 != nil
        let _c24 = (Int(_1!) & Int(1 << 15) == 0) || _24 != nil
        let _c25 = (Int(_1!) & Int(1 << 17) == 0) || _25 != nil
        let _c26 = (Int(_1!) & Int(1 << 18) == 0) || _26 != nil
        let _c27 = (Int(_1!) & Int(1 << 12) == 0) || _27 != nil
        let _c28 = _28 != nil
        let _c29 = (Int(_1!) & Int(1 << 21) == 0) || _29 != nil
        let _c30 = (Int(_1!) & Int(1 << 24) == 0) || _30 != nil
        let _c31 = (Int(_1!) & Int(1 << 25) == 0) || _31 != nil
        let _c32 = (Int(_1!) & Int(1 << 26) == 0) || _32 != nil
        let _c33 = (Int(_1!) & Int(1 << 27) == 0) || _33 != nil
        let _c34 = (Int(_1!) & Int(1 << 28) == 0) || _34 != nil
        let _c35 = (Int(_1!) & Int(1 << 28) == 0) || _35 != nil
        let _c36 = (Int(_1!) & Int(1 << 29) == 0) || _36 != nil
        let _c37 = (Int(_1!) & Int(1 << 30) == 0) || _37 != nil
        let _c38 = (Int(_2!) & Int(1 << 13) == 0) || _38 != nil
        let _c39 = (Int(_2!) & Int(1 << 4) == 0) || _39 != nil
        let _c40 = (Int(_2!) & Int(1 << 7) == 0) || _40 != nil
        let _c41 = (Int(_2!) & Int(1 << 8) == 0) || _41 != nil
        let _c42 = (Int(_2!) & Int(1 << 9) == 0) || _42 != nil
        let _c43 = (Int(_2!) & Int(1 << 10) == 0) || _43 != nil
        let _c44 = (Int(_2!) & Int(1 << 17) == 0) || _44 != nil
        let _c45 = (Int(_2!) & Int(1 << 18) == 0) || _45 != nil
        if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 && _c27 && _c28 && _c29 && _c30 && _c31 && _c32 && _c33 && _c34 && _c35 && _c36 && _c37 && _c38 && _c39 && _c40 && _c41 && _c42 && _c43 && _c44 && _c45 {
            return Api.ChatFull.channelFull(Api.ChatFull.Cons_channelFull(flags: _1!, flags2: _2!, id: _3!, about: _4!, participantsCount: _5, adminsCount: _6, kickedCount: _7, bannedCount: _8, onlineCount: _9, readInboxMaxId: _10!, readOutboxMaxId: _11!, unreadCount: _12!, chatPhoto: _13!, notifySettings: _14!, exportedInvite: _15, botInfo: _16!, migratedFromChatId: _17, migratedFromMaxId: _18, pinnedMsgId: _19, stickerset: _20, availableMinId: _21, folderId: _22, linkedChatId: _23, location: _24, slowmodeSeconds: _25, slowmodeNextSendDate: _26, statsDc: _27, pts: _28!, call: _29, ttlPeriod: _30, pendingSuggestions: _31, groupcallDefaultJoinAs: _32, themeEmoticon: _33, requestsPending: _34, recentRequesters: _35, defaultSendAs: _36, availableReactions: _37, reactionsLimit: _38, stories: _39, wallpaper: _40, boostsApplied: _41, boostsUnrestrict: _42, emojiset: _43, botVerification: _44, stargiftsCount: _45, sendPaidMessagesStars: nil, mainTab: nil))
        } else {
            return nil
        }
    }
}

public extension Api.Message {
    // messageService#d3d28540 (layer 200-204)
    static func parse_messageService_teamgram_layer200(_ reader: BufferReader) -> Api.Message? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Int32?
        _2 = reader.readInt32()
        var _3: Api.Peer?
        if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
            _3 = Api.parse(reader, signature: signature) as? Api.Peer
        } }
        var _4: Api.Peer?
        if let signature = reader.readInt32() {
            _4 = Api.parse(reader, signature: signature) as? Api.Peer
        }
        var _5: Api.MessageReplyHeader?
        if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
            _5 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
        } }
        var _6: Int32?
        _6 = reader.readInt32()
        var _7: Api.MessageAction?
        if let signature = reader.readInt32() {
            _7 = Api.parse(reader, signature: signature) as? Api.MessageAction
        }
        var _8: Api.MessageReactions?
        if Int(_1!) & Int(1 << 20) != 0 {if let signature = reader.readInt32() {
            _8 = Api.parse(reader, signature: signature) as? Api.MessageReactions
        } }
        var _9: Int32?
        if Int(_1!) & Int(1 << 25) != 0 {_9 = reader.readInt32() }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = (Int(_1!) & Int(1 << 8) == 0) || _3 != nil
        let _c4 = _4 != nil
        let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
        let _c6 = _6 != nil
        let _c7 = _7 != nil
        let _c8 = (Int(_1!) & Int(1 << 20) == 0) || _8 != nil
        let _c9 = (Int(_1!) & Int(1 << 25) == 0) || _9 != nil
        if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
            // savedPeerId не существовал в messageService layer 200 → nil
            return Api.Message.messageService(Api.Message.Cons_messageService(flags: _1!, id: _2!, fromId: _3, peerId: _4!, savedPeerId: nil, replyTo: _5, date: _6!, action: _7!, reactions: _8, ttlPeriod: _9))
        } else {
            return nil
        }
    }
}

public extension Api.Update {
    // updateUserTyping#c01e857f (layer 200/201) — без flags и topMsgId (добавлены позже).
    // Структура: user_id:long action:SendMessageAction.
    static func parse_updateUserTyping_teamgram_layer201(_ reader: BufferReader) -> Api.Update? {
        var _1: Int64?
        _1 = reader.readInt64()
        var _2: Api.SendMessageAction?
        if let signature = reader.readInt32() {
            _2 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
        }
        if let _1 = _1, let _2 = _2 {
            return Api.Update.updateUserTyping(Api.Update.Cons_updateUserTyping(flags: 0, userId: _1, topMsgId: nil, action: _2))
        } else {
            return nil
        }
    }

    // updateReadHistoryInbox#9c974fdf (layer 201) — без topMsgId (добавлен позже).
    static func parse_updateReadHistoryInbox_teamgram_layer201(_ reader: BufferReader) -> Api.Update? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Int32?
        if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
        var _3: Api.Peer?
        if let signature = reader.readInt32() {
            _3 = Api.parse(reader, signature: signature) as? Api.Peer
        }
        var _4: Int32?
        _4 = reader.readInt32()
        var _5: Int32?
        _5 = reader.readInt32()
        var _6: Int32?
        _6 = reader.readInt32()
        var _7: Int32?
        _7 = reader.readInt32()
        let _c1 = _1 != nil
        let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
        let _c3 = _3 != nil
        let _c4 = _4 != nil
        let _c5 = _5 != nil
        let _c6 = _6 != nil
        let _c7 = _7 != nil
        if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
            return Api.Update.updateReadHistoryInbox(Api.Update.Cons_updateReadHistoryInbox(flags: _1!, folderId: _2, peer: _3!, topMsgId: nil, maxId: _4!, stillUnreadCount: _5!, pts: _6!, ptsCount: _7!))
        } else {
            return nil
        }
    }

    // updateDraftMessage#1b49ec6d (layer 201) — без savedPeerId (flags.1, добавлен позже).
    // Структура: flags:# peer:Peer top_msg_id:flags.0?int draft:DraftMessage.
    static func parse_updateDraftMessage_teamgram_layer201(_ reader: BufferReader) -> Api.Update? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Api.Peer?
        if let signature = reader.readInt32() {
            _2 = Api.parse(reader, signature: signature) as? Api.Peer
        }
        var _3: Int32?
        if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
        var _4: Api.DraftMessage?
        if let signature = reader.readInt32() {
            _4 = Api.parse(reader, signature: signature) as? Api.DraftMessage
        }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
        let _c4 = _4 != nil
        if _c1 && _c2 && _c3 && _c4 {
            return Api.Update.updateDraftMessage(Api.Update.Cons_updateDraftMessage(flags: _1!, peer: _2!, topMsgId: _3, savedPeerId: nil, draft: _4!))
        } else {
            return nil
        }
    }

    // updateDialogUnreadMark#e16459c3 (layer 201) — без savedPeerId (flags.1, добавлен позже).
    // Структура: flags:# unread:flags.0?true peer:DialogPeer.
    static func parse_updateDialogUnreadMark_teamgram_layer201(_ reader: BufferReader) -> Api.Update? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Api.DialogPeer?
        if let signature = reader.readInt32() {
            _2 = Api.parse(reader, signature: signature) as? Api.DialogPeer
        }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        if _c1 && _c2 {
            return Api.Update.updateDialogUnreadMark(Api.Update.Cons_updateDialogUnreadMark(flags: _1!, peer: _2!, savedPeerId: nil))
        } else {
            return nil
        }
    }

    // updateChannelReadMessagesContents#ea29055d (layer 201) — без savedPeerId (flags.1, добавлен позже).
    // Структура: flags:# channel_id:long top_msg_id:flags.0?int messages:Vector<int>.
    static func parse_updateChannelReadMessagesContents_teamgram_layer201(_ reader: BufferReader) -> Api.Update? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Int64?
        _2 = reader.readInt64()
        var _3: Int32?
        if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
        var _4: [Int32]?
        if let _ = reader.readInt32() {
            _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
        }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
        let _c4 = _4 != nil
        if _c1 && _c2 && _c3 && _c4 {
            return Api.Update.updateChannelReadMessagesContents(Api.Update.Cons_updateChannelReadMessagesContents(flags: _1!, channelId: _2!, topMsgId: _3, savedPeerId: nil, messages: _4!))
        } else {
            return nil
        }
    }

    // updateMessageReactions#5e1b3cb8 (layer 201) — без savedPeerId (flags.1, добавлен позже).
    // Структура: flags:# peer:Peer msg_id:int top_msg_id:flags.0?int reactions:MessageReactions.
    static func parse_updateMessageReactions_teamgram_layer201(_ reader: BufferReader) -> Api.Update? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Api.Peer?
        if let signature = reader.readInt32() {
            _2 = Api.parse(reader, signature: signature) as? Api.Peer
        }
        var _3: Int32?
        _3 = reader.readInt32()
        var _4: Int32?
        if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
        var _5: Api.MessageReactions?
        if let signature = reader.readInt32() {
            _5 = Api.parse(reader, signature: signature) as? Api.MessageReactions
        }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = _3 != nil
        let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
        let _c5 = _5 != nil
        if _c1 && _c2 && _c3 && _c4 && _c5 {
            return Api.Update.updateMessageReactions(Api.Update.Cons_updateMessageReactions(flags: _1!, peer: _2!, msgId: _3!, topMsgId: _4, savedPeerId: nil, reactions: _5!))
        } else {
            return nil
        }
    }

    // updateGroupCall#97d64341 (layer 201) — chat_id:flags.0?long вместо peer:flags.1?Peer.
    // chat_id маппим в Api.Peer.peerChat; flags пересобираем под современную семантику (peer в flags.1).
    static func parse_updateGroupCall_teamgram_layer201(_ reader: BufferReader) -> Api.Update? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Api.Peer?
        if Int(_1!) & Int(1 << 0) != 0 {
            if let chatId = reader.readInt64() {
                _2 = Api.Peer.peerChat(Api.Peer.Cons_peerChat(chatId: chatId))
            }
        }
        var _3: Api.GroupCall?
        if let signature = reader.readInt32() {
            _3 = Api.parse(reader, signature: signature) as? Api.GroupCall
        }
        let _c1 = _1 != nil
        let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
        let _c3 = _3 != nil
        if _c1 && _c2 && _c3 {
            let flags: Int32 = (_2 != nil) ? (1 << 1) : 0
            return Api.Update.updateGroupCall(Api.Update.Cons_updateGroupCall(flags: flags, peer: _2, call: _3!))
        } else {
            return nil
        }
    }
}

public extension Api.messages.Messages {
    // messages.messages#8c718e87 (layer 200) — без поля topics (forum topics добавили позже).
    // Структура: messages:Vector<Message> chats:Vector<Chat> users:Vector<User>.
    // В нашем текущем Cons_messages topics = [].
    static func parse_messages_teamgram_layer200(_ reader: BufferReader) -> Api.messages.Messages? {
        var _1: [Api.Message]?
        if let _ = reader.readInt32() {
            _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
        }
        var _2: [Api.Chat]?
        if let _ = reader.readInt32() {
            _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
        }
        var _3: [Api.User]?
        if let _ = reader.readInt32() {
            _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
        }
        if let _1 = _1, let _2 = _2, let _3 = _3 {
            return Api.messages.Messages.messages(Api.messages.Messages.Cons_messages(messages: _1, topics: [], chats: _2, users: _3))
        } else {
            return nil
        }
    }

    // messages.messagesSlice#3a54685e (layer 201) — без topics (forum topics) и searchFlood (flags.3),
    // добавленных позже. Ответ messages.getHistory для чата с историей.
    // Структура: flags count next_rate:flags.0?int offset_id_offset:flags.2?int
    // messages:Vector<Message> chats:Vector<Chat> users:Vector<User>.
    static func parse_messagesSlice_teamgram_layer201(_ reader: BufferReader) -> Api.messages.Messages? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Int32?
        _2 = reader.readInt32()
        var _3: Int32?
        if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
        var _4: Int32?
        if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
        var _5: [Api.Message]?
        if let _ = reader.readInt32() {
            _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
        }
        var _6: [Api.Chat]?
        if let _ = reader.readInt32() {
            _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
        }
        var _7: [Api.User]?
        if let _ = reader.readInt32() {
            _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
        }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
        let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
        let _c5 = _5 != nil
        let _c6 = _6 != nil
        let _c7 = _7 != nil
        if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
            return Api.messages.Messages.messagesSlice(Api.messages.Messages.Cons_messagesSlice(flags: _1!, count: _2!, nextRate: _3, offsetIdOffset: _4, searchFlood: nil, messages: _5!, topics: [], chats: _6!, users: _7!))
        } else {
            return nil
        }
    }
}

public extension Api.UserFull {
    // userFull#99e78045 (layer 201-205) — структура полей такая же что в нашем layer 222+
    // Cons_userFull (39 полей), кроме 6 последних, добавленных позже:
    // starsRating, starsMyPendingRating, starsMyPendingRatingDate, mainTab, savedMusic, note → nil.
    // Извлечено из апстрим-коммита b4832ff856^ (2025-07-14).
    static func parse_userFull_teamgram_layer201(_ reader: BufferReader) -> Api.UserFull? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Int32?
        _2 = reader.readInt32()
        var _3: Int64?
        _3 = reader.readInt64()
        var _4: String?
        if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
        var _5: Api.PeerSettings?
        if let signature = reader.readInt32() {
            _5 = Api.parse(reader, signature: signature) as? Api.PeerSettings
        }
        var _6: Api.Photo?
        if Int(_1!) & Int(1 << 21) != 0 {if let signature = reader.readInt32() {
            _6 = Api.parse(reader, signature: signature) as? Api.Photo
        } }
        var _7: Api.Photo?
        if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
            _7 = Api.parse(reader, signature: signature) as? Api.Photo
        } }
        var _8: Api.Photo?
        if Int(_1!) & Int(1 << 22) != 0 {if let signature = reader.readInt32() {
            _8 = Api.parse(reader, signature: signature) as? Api.Photo
        } }
        var _9: Api.PeerNotifySettings?
        if let signature = reader.readInt32() {
            _9 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
        }
        var _10: Api.BotInfo?
        if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
            _10 = Api.parse(reader, signature: signature) as? Api.BotInfo
        } }
        var _11: Int32?
        if Int(_1!) & Int(1 << 6) != 0 {_11 = reader.readInt32() }
        var _12: Int32?
        _12 = reader.readInt32()
        var _13: Int32?
        if Int(_1!) & Int(1 << 11) != 0 {_13 = reader.readInt32() }
        var _14: Int32?
        if Int(_1!) & Int(1 << 14) != 0 {_14 = reader.readInt32() }
        var _15: String?
        if Int(_1!) & Int(1 << 15) != 0 {_15 = parseString(reader) }
        var _16: String?
        if Int(_1!) & Int(1 << 16) != 0 {_16 = parseString(reader) }
        var _17: Api.ChatAdminRights?
        if Int(_1!) & Int(1 << 17) != 0 {if let signature = reader.readInt32() {
            _17 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
        } }
        var _18: Api.ChatAdminRights?
        if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
            _18 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
        } }
        var _19: Api.WallPaper?
        if Int(_1!) & Int(1 << 24) != 0 {if let signature = reader.readInt32() {
            _19 = Api.parse(reader, signature: signature) as? Api.WallPaper
        } }
        var _20: Api.PeerStories?
        if Int(_1!) & Int(1 << 25) != 0 {if let signature = reader.readInt32() {
            _20 = Api.parse(reader, signature: signature) as? Api.PeerStories
        } }
        var _21: Api.BusinessWorkHours?
        if Int(_2!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
            _21 = Api.parse(reader, signature: signature) as? Api.BusinessWorkHours
        } }
        var _22: Api.BusinessLocation?
        if Int(_2!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
            _22 = Api.parse(reader, signature: signature) as? Api.BusinessLocation
        } }
        var _23: Api.BusinessGreetingMessage?
        if Int(_2!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
            _23 = Api.parse(reader, signature: signature) as? Api.BusinessGreetingMessage
        } }
        var _24: Api.BusinessAwayMessage?
        if Int(_2!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
            _24 = Api.parse(reader, signature: signature) as? Api.BusinessAwayMessage
        } }
        var _25: Api.BusinessIntro?
        if Int(_2!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
            _25 = Api.parse(reader, signature: signature) as? Api.BusinessIntro
        } }
        var _26: Api.Birthday?
        if Int(_2!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
            _26 = Api.parse(reader, signature: signature) as? Api.Birthday
        } }
        var _27: Int64?
        if Int(_2!) & Int(1 << 6) != 0 {_27 = reader.readInt64() }
        var _28: Int32?
        if Int(_2!) & Int(1 << 6) != 0 {_28 = reader.readInt32() }
        var _29: Int32?
        if Int(_2!) & Int(1 << 8) != 0 {_29 = reader.readInt32() }
        var _30: Api.StarRefProgram?
        if Int(_2!) & Int(1 << 11) != 0 {if let signature = reader.readInt32() {
            _30 = Api.parse(reader, signature: signature) as? Api.StarRefProgram
        } }
        var _31: Api.BotVerification?
        if Int(_2!) & Int(1 << 12) != 0 {if let signature = reader.readInt32() {
            _31 = Api.parse(reader, signature: signature) as? Api.BotVerification
        } }
        var _32: Int64?
        if Int(_2!) & Int(1 << 14) != 0 {_32 = reader.readInt64() }
        var _33: Api.DisallowedGiftsSettings?
        if Int(_2!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
            _33 = Api.parse(reader, signature: signature) as? Api.DisallowedGiftsSettings
        } }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = _3 != nil
        let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
        let _c5 = _5 != nil
        let _c6 = (Int(_1!) & Int(1 << 21) == 0) || _6 != nil
        let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
        let _c8 = (Int(_1!) & Int(1 << 22) == 0) || _8 != nil
        let _c9 = _9 != nil
        let _c10 = (Int(_1!) & Int(1 << 3) == 0) || _10 != nil
        let _c11 = (Int(_1!) & Int(1 << 6) == 0) || _11 != nil
        let _c12 = _12 != nil
        let _c13 = (Int(_1!) & Int(1 << 11) == 0) || _13 != nil
        let _c14 = (Int(_1!) & Int(1 << 14) == 0) || _14 != nil
        let _c15 = (Int(_1!) & Int(1 << 15) == 0) || _15 != nil
        let _c16 = (Int(_1!) & Int(1 << 16) == 0) || _16 != nil
        let _c17 = (Int(_1!) & Int(1 << 17) == 0) || _17 != nil
        let _c18 = (Int(_1!) & Int(1 << 18) == 0) || _18 != nil
        let _c19 = (Int(_1!) & Int(1 << 24) == 0) || _19 != nil
        let _c20 = (Int(_1!) & Int(1 << 25) == 0) || _20 != nil
        let _c21 = (Int(_2!) & Int(1 << 0) == 0) || _21 != nil
        let _c22 = (Int(_2!) & Int(1 << 1) == 0) || _22 != nil
        let _c23 = (Int(_2!) & Int(1 << 2) == 0) || _23 != nil
        let _c24 = (Int(_2!) & Int(1 << 3) == 0) || _24 != nil
        let _c25 = (Int(_2!) & Int(1 << 4) == 0) || _25 != nil
        let _c26 = (Int(_2!) & Int(1 << 5) == 0) || _26 != nil
        let _c27 = (Int(_2!) & Int(1 << 6) == 0) || _27 != nil
        let _c28 = (Int(_2!) & Int(1 << 6) == 0) || _28 != nil
        let _c29 = (Int(_2!) & Int(1 << 8) == 0) || _29 != nil
        let _c30 = (Int(_2!) & Int(1 << 11) == 0) || _30 != nil
        let _c31 = (Int(_2!) & Int(1 << 12) == 0) || _31 != nil
        let _c32 = (Int(_2!) & Int(1 << 14) == 0) || _32 != nil
        let _c33 = (Int(_2!) & Int(1 << 15) == 0) || _33 != nil
        if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 && _c27 && _c28 && _c29 && _c30 && _c31 && _c32 && _c33 {
            // _15 — themeEmoticon (String) в layer 201, в текущей схеме theme это boxed ChatTheme.
            // String прочитан чтобы продвинуть byte-stream, theme передаём nil.
            _ = _15
            return Api.UserFull.userFull(Api.UserFull.Cons_userFull(flags: _1!, flags2: _2!, id: _3!, about: _4, settings: _5!, personalPhoto: _6, profilePhoto: _7, fallbackPhoto: _8, notifySettings: _9!, botInfo: _10, pinnedMsgId: _11, commonChatsCount: _12!, folderId: _13, ttlPeriod: _14, theme: nil, privateForwardName: _16, botGroupAdminRights: _17, botBroadcastAdminRights: _18, wallpaper: _19, stories: _20, businessWorkHours: _21, businessLocation: _22, businessGreetingMessage: _23, businessAwayMessage: _24, businessIntro: _25, birthday: _26, personalChannelId: _27, personalChannelMessage: _28, stargiftsCount: _29, starrefProgram: _30, botVerification: _31, sendPaidMessagesStars: _32, disallowedGifts: _33, starsRating: nil, starsMyPendingRating: nil, starsMyPendingRatingDate: nil, mainTab: nil, savedMusic: nil, note: nil))
        } else {
            return nil
        }
    }
}

public extension Api.User {
    // user#020b1422 (layer 201). Отличие от 222-конструктора 31774388 ровно одно: поле
    // stories_max_id на flags2.5 — на 201 это простой int, на 222 это объект RecentStory.
    // Форк-parse_user читает там RecentStory (сигнатура+тело) → на любом юзере СО сторис
    // (flags2.5 выставлен, напр. модель с stories_max_id) буфер съезжает и весь Updates не
    // парсится → sendMessage/getDifference-ответ = nil. Здесь читаем int и отбрасываем
    // (сторис в DIVO не используются), storiesMaxId = nil. Остальные поля идентичны 222.
    static func parse_user_teamgram_layer201(_ reader: BufferReader) -> Api.User? {
        var _1: Int32?
        _1 = reader.readInt32()
        var _2: Int32?
        _2 = reader.readInt32()
        var _3: Int64?
        _3 = reader.readInt64()
        var _4: Int64?
        if Int(_1!) & Int(1 << 0) != 0 {
            _4 = reader.readInt64()
        }
        var _5: String?
        if Int(_1!) & Int(1 << 1) != 0 {
            _5 = parseString(reader)
        }
        var _6: String?
        if Int(_1!) & Int(1 << 2) != 0 {
            _6 = parseString(reader)
        }
        var _7: String?
        if Int(_1!) & Int(1 << 3) != 0 {
            _7 = parseString(reader)
        }
        var _8: String?
        if Int(_1!) & Int(1 << 4) != 0 {
            _8 = parseString(reader)
        }
        var _9: Api.UserProfilePhoto?
        if Int(_1!) & Int(1 << 5) != 0 {
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.UserProfilePhoto
            }
        }
        var _10: Api.UserStatus?
        if Int(_1!) & Int(1 << 6) != 0 {
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.UserStatus
            }
        }
        var _11: Int32?
        if Int(_1!) & Int(1 << 14) != 0 {
            _11 = reader.readInt32()
        }
        var _12: [Api.RestrictionReason]?
        if Int(_1!) & Int(1 << 18) != 0 {
            if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
            }
        }
        var _13: String?
        if Int(_1!) & Int(1 << 19) != 0 {
            _13 = parseString(reader)
        }
        var _14: String?
        if Int(_1!) & Int(1 << 22) != 0 {
            _14 = parseString(reader)
        }
        var _15: Api.EmojiStatus?
        if Int(_1!) & Int(1 << 30) != 0 {
            if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
            }
        }
        var _16: [Api.Username]?
        if Int(_2!) & Int(1 << 0) != 0 {
            if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Username.self)
            }
        }
        // flags2.5: на 201 это int (stories_max_id) — читаем и отбрасываем (на 222 здесь RecentStory).
        if Int(_2!) & Int(1 << 5) != 0 {
            _ = reader.readInt32()
        }
        var _18: Api.PeerColor?
        if Int(_2!) & Int(1 << 8) != 0 {
            if let signature = reader.readInt32() {
                _18 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
        }
        var _19: Api.PeerColor?
        if Int(_2!) & Int(1 << 9) != 0 {
            if let signature = reader.readInt32() {
                _19 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
        }
        var _20: Int32?
        if Int(_2!) & Int(1 << 12) != 0 {
            _20 = reader.readInt32()
        }
        var _21: Int64?
        if Int(_2!) & Int(1 << 14) != 0 {
            _21 = reader.readInt64()
        }
        var _22: Int64?
        if Int(_2!) & Int(1 << 15) != 0 {
            _22 = reader.readInt64()
        }
        let _c1 = _1 != nil
        let _c2 = _2 != nil
        let _c3 = _3 != nil
        let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
        let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
        let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
        let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
        let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
        let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
        let _c10 = (Int(_1!) & Int(1 << 6) == 0) || _10 != nil
        let _c11 = (Int(_1!) & Int(1 << 14) == 0) || _11 != nil
        let _c12 = (Int(_1!) & Int(1 << 18) == 0) || _12 != nil
        let _c13 = (Int(_1!) & Int(1 << 19) == 0) || _13 != nil
        let _c14 = (Int(_1!) & Int(1 << 22) == 0) || _14 != nil
        let _c15 = (Int(_1!) & Int(1 << 30) == 0) || _15 != nil
        let _c16 = (Int(_2!) & Int(1 << 0) == 0) || _16 != nil
        let _c18 = (Int(_2!) & Int(1 << 8) == 0) || _18 != nil
        let _c19 = (Int(_2!) & Int(1 << 9) == 0) || _19 != nil
        let _c20 = (Int(_2!) & Int(1 << 12) == 0) || _20 != nil
        let _c21 = (Int(_2!) & Int(1 << 14) == 0) || _21 != nil
        let _c22 = (Int(_2!) & Int(1 << 15) == 0) || _22 != nil
        if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c18 && _c19 && _c20 && _c21 && _c22 {
            return Api.User.user(Api.User.Cons_user(flags: _1!, flags2: _2!, id: _3!, accessHash: _4, firstName: _5, lastName: _6, username: _7, phone: _8, photo: _9, status: _10, botInfoVersion: _11, restrictionReason: _12, botInlinePlaceholder: _13, langCode: _14, emojiStatus: _15, usernames: _16, storiesMaxId: nil, color: _18, profileColor: _19, botActiveUsers: _20, botVerificationIcon: _21, sendPaidMessagesStars: _22))
        } else {
            return nil
        }
    }
}

public extension Api.functions.messages {
    // messages.sendMessage#fbf2340a (layer 201) — DIVO encode-фикс.
    // Форк кодирует sendMessage новым 222-конструктором 545cd15a с полями suggested_post (flags.22)
    // и schedule_repeat_period (flags.24), которых на layer 201 нет → teamgram-сервер не декодирует
    // метод и молча дропает (sendMessage не доходит до bff/msg). Кодируем под 201: constructor fbf2340a,
    // сбрасываем биты 22/24, эти два поля не пишем. Остальные биты/поля идентичны 222.
    static func sendMessage_teamgram_layer201(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-68013046)
        let flags201 = flags & ~((Int32(1) << 22) | (Int32(1) << 24))
        serializeInt32(flags201, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags201) & Int(1 << 0) != 0 {
            replyTo!.serialize(buffer, true)
        }
        serializeString(message, buffer: buffer, boxed: false)
        serializeInt64(randomId, buffer: buffer, boxed: false)
        if Int(flags201) & Int(1 << 2) != 0 {
            replyMarkup!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags201) & Int(1 << 10) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 17) != 0 {
            quickReplyShortcut!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 18) != 0 {
            serializeInt64(effect!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 21) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.sendMessage(teamgram_layer201)", parameters: [("flags", String(describing: flags201)), ("peer", String(describing: peer)), ("message", String(describing: message)), ("randomId", String(describing: randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
            let reader = BufferReader(buffer)
            var result: Api.Updates?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Updates
            }
            return result
        })
    }

    // messages.sendMedia#a550cd78 (layer 201). 222-добавки suggested_post(22)/schedule_repeat_period(24) отсекаются маской.
    static func sendMedia_teamgram_layer201(flags: Int32, peer: Api.InputPeer, replyTo: Api.InputReplyTo?, media: Api.InputMedia, message: String, randomId: Int64, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, effect: Int64?, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1521431176)
        // whitelist бит 0,1,2,3,5,6,7,10,13,14,15,16,17,18,19,21 (отсекает 222-биты 22/24)
        let flags201 = flags & 3138799
        serializeInt32(flags201, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        if Int(flags201) & Int(1 << 0) != 0 {
            replyTo!.serialize(buffer, true)
        }
        media.serialize(buffer, true)
        serializeString(message, buffer: buffer, boxed: false)
        serializeInt64(randomId, buffer: buffer, boxed: false)
        if Int(flags201) & Int(1 << 2) != 0 {
            replyMarkup!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags201) & Int(1 << 10) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 17) != 0 {
            quickReplyShortcut!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 18) != 0 {
            serializeInt64(effect!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 21) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.sendMedia(teamgram_layer201)", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
            let reader = BufferReader(buffer)
            var result: Api.Updates?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Updates
            }
            return result
        })
    }

    // messages.editMessage#dfd14005 (layer 201). 222-добавка schedule_repeat_period отсекается маской.
    static func editMessage_teamgram_layer201(flags: Int32, peer: Api.InputPeer, id: Int32, message: String?, media: Api.InputMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, scheduleDate: Int32?, quickReplyShortcutId: Int32?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-539934715)
        // whitelist бит 1,2,3,11,14,15,16,17 (отсекает 222-бит schedule_repeat_period)
        let flags201 = flags & 247822
        serializeInt32(flags201, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        serializeInt32(id, buffer: buffer, boxed: false)
        if Int(flags201) & Int(1 << 11) != 0 {
            serializeString(message!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 14) != 0 {
            media!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 2) != 0 {
            replyMarkup!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags201) & Int(1 << 15) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 17) != 0 {
            serializeInt32(quickReplyShortcutId!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.editMessage(teamgram_layer201)", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
            let reader = BufferReader(buffer)
            var result: Api.Updates?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Updates
            }
            return result
        })
    }

    // messages.forwardMessages#bb9fa475 (layer 201). На 201 нет reply_to/effect/schedule_repeat_period/suggested_post — отсекаются маской.
    static func forwardMessages_teamgram_layer201(flags: Int32, fromPeer: Api.InputPeer, id: [Int32], randomId: [Int64], toPeer: Api.InputPeer, topMsgId: Int32?, scheduleDate: Int32?, sendAs: Api.InputPeer?, quickReplyShortcut: Api.InputQuickReplyShortcut?, videoTimestamp: Int32?, allowPaidStars: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-1147165579)
        // whitelist бит 5,6,8,9,10,11,12,13,14,17,19,20,21 (отсекает 222-биты replyTo/effect/schedule_repeat_period/suggested_post)
        let flags201 = flags & 3833696
        serializeInt32(flags201, buffer: buffer, boxed: false)
        fromPeer.serialize(buffer, true)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(id.count))
        for item in id {
            serializeInt32(item, buffer: buffer, boxed: false)
        }
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(randomId.count))
        for item in randomId {
            serializeInt64(item, buffer: buffer, boxed: false)
        }
        toPeer.serialize(buffer, true)
        if Int(flags201) & Int(1 << 9) != 0 {
            serializeInt32(topMsgId!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 10) != 0 {
            serializeInt32(scheduleDate!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 13) != 0 {
            sendAs!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 17) != 0 {
            quickReplyShortcut!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 20) != 0 {
            serializeInt32(videoTimestamp!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 21) != 0 {
            serializeInt64(allowPaidStars!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.forwardMessages(teamgram_layer201)", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
            let reader = BufferReader(buffer)
            var result: Api.Updates?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Updates
            }
            return result
        })
    }

    // messages.saveDraft#d372c5ce (layer 201). 222-добавка suggested_post отсекается маской. Возвращает Bool.
    static func saveDraft_teamgram_layer201(flags: Int32, replyTo: Api.InputReplyTo?, peer: Api.InputPeer, message: String, entities: [Api.MessageEntity]?, media: Api.InputMedia?, effect: Int64?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Bool>) {
        let buffer = Buffer()
        buffer.appendInt32(-747452978)
        // whitelist бит 1,3,4,5,6,7 (отсекает 222-бит suggested_post)
        let flags201 = flags & 250
        serializeInt32(flags201, buffer: buffer, boxed: false)
        if Int(flags201) & Int(1 << 4) != 0 {
            replyTo!.serialize(buffer, true)
        }
        peer.serialize(buffer, true)
        serializeString(message, buffer: buffer, boxed: false)
        if Int(flags201) & Int(1 << 3) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags201) & Int(1 << 5) != 0 {
            media!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 7) != 0 {
            serializeInt64(effect!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "messages.saveDraft(teamgram_layer201)", parameters: []), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Bool? in
            let reader = BufferReader(buffer)
            var result: Api.Bool?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Bool
            }
            return result
        })
    }
}

public extension Api.functions.contacts {
    // Форк кодирует addContact 222-конструктором d9ba2e54 с полем note (flags.1?TextWithEntities),
    // которого на layer 201 нет → teamgram-сервер не декодирует метод и молча дропает (контакт не
    // добавляется на сервере, локально клиент оптимистично пишет «добавлен»). Кодируем под 201:
    // constructor e8f463d0, сбрасываем бит note (flags.1), поле note не пишем. Бит 0
    // (add_phone_privacy_exception) и остальные поля идентичны 222.
    static func addContact_teamgram_layer201(flags: Int32, id: Api.InputUser, firstName: String, lastName: String, phone: String, note: Api.TextWithEntities?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-386636848)
        let flags201 = flags & ~(Int32(1) << 1)
        serializeInt32(flags201, buffer: buffer, boxed: false)
        id.serialize(buffer, true)
        serializeString(firstName, buffer: buffer, boxed: false)
        serializeString(lastName, buffer: buffer, boxed: false)
        serializeString(phone, buffer: buffer, boxed: false)
        return (FunctionDescription(name: "contacts.addContact(teamgram_layer201)", parameters: [("flags", String(describing: flags201)), ("id", String(describing: id)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("phone", String(describing: phone))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
            let reader = BufferReader(buffer)
            var result: Api.Updates?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Updates
            }
            return result
        })
    }
}

public extension Api.functions.stories {
    // Форк кодирует sendStory 222-конструктором 737fc2ec с полем albums (flags.8?Vector<int>),
    // которого на layer 201 нет → teamgram-сервер не декодирует метод и молча дропает (постинг
    // сторис не доходит, клиент висит на «Uploading…»). Кодируем под 201: constructor e4e6694b,
    // сбрасываем бит 8, albums не пишем. Поля и биты 0-7 идентичны 222
    // (caption.0/entities.1/pinned.2/period.3/noforwards.4/mediaAreas.5/fwdFrom.6/fwdModified.7).
    static func sendStory_teamgram_layer201(flags: Int32, peer: Api.InputPeer, media: Api.InputMedia, mediaAreas: [Api.MediaArea]?, caption: String?, entities: [Api.MessageEntity]?, privacyRules: [Api.InputPrivacyRule], randomId: Int64, period: Int32?, fwdFromId: Api.InputPeer?, fwdFromStory: Int32?, albums: [Int32]?) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.Updates>) {
        let buffer = Buffer()
        buffer.appendInt32(-454661813)
        let flags201 = flags & ~(Int32(1) << 8)
        serializeInt32(flags201, buffer: buffer, boxed: false)
        peer.serialize(buffer, true)
        media.serialize(buffer, true)
        if Int(flags201) & Int(1 << 5) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(mediaAreas!.count))
            for item in mediaAreas! {
                item.serialize(buffer, true)
            }
        }
        if Int(flags201) & Int(1 << 0) != 0 {
            serializeString(caption!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 1) != 0 {
            buffer.appendInt32(481674261)
            buffer.appendInt32(Int32(entities!.count))
            for item in entities! {
                item.serialize(buffer, true)
            }
        }
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(privacyRules.count))
        for item in privacyRules {
            item.serialize(buffer, true)
        }
        serializeInt64(randomId, buffer: buffer, boxed: false)
        if Int(flags201) & Int(1 << 3) != 0 {
            serializeInt32(period!, buffer: buffer, boxed: false)
        }
        if Int(flags201) & Int(1 << 6) != 0 {
            fwdFromId!.serialize(buffer, true)
        }
        if Int(flags201) & Int(1 << 6) != 0 {
            serializeInt32(fwdFromStory!, buffer: buffer, boxed: false)
        }
        return (FunctionDescription(name: "stories.sendStory(teamgram_layer201)", parameters: [("flags", String(describing: flags201)), ("peer", String(describing: peer)), ("media", String(describing: media)), ("randomId", String(describing: randomId))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> Api.Updates? in
            let reader = BufferReader(buffer)
            var result: Api.Updates?
            if let signature = reader.readInt32() {
                result = Api.parse(reader, signature: signature) as? Api.Updates
            }
            return result
        })
    }

    // На layer 201 stories.getPeerMaxIDs возвращает Vector<int> (constructor 535983c3), а форк (222,
    // 78499170) ждёт Vector<RecentStory> и парсит элементы как boxed-объекты → давится на сыром int
    // («can't parse magic 0x… in RecentStory»). Из-за этого не синкаются peer story max-id (бейджи
    // сторис-стрипа / «My Story»). Запрос идентичен (сервер на 201-сессии всё равно отдаёт Vector<int>),
    // ответ читаем как [Int32] и заворачиваем в RecentStory(maxId:) — caller (AccountViewTracker) берёт maxId.
    static func getPeerMaxIDs_teamgram_layer201(id: [Api.InputPeer]) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<[Api.RecentStory]>) {
        let buffer = Buffer()
        buffer.appendInt32(2018087280)
        buffer.appendInt32(481674261)
        buffer.appendInt32(Int32(id.count))
        for item in id {
            item.serialize(buffer, true)
        }
        return (FunctionDescription(name: "stories.getPeerMaxIDs(teamgram_layer201)", parameters: [("id", String(describing: id))]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> [Api.RecentStory]? in
            let reader = BufferReader(buffer)
            var result: [Api.RecentStory]?
            if let _ = reader.readInt32() {
                result = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)?.map { maxId in
                    Api.RecentStory.recentStory(Api.RecentStory.Cons_recentStory(flags: 1 << 1, maxId: maxId))
                }
            }
            return result
        })
    }
}
