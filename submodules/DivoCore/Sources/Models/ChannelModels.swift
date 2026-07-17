import Foundation

// Каналы модели: GET /channels/list?user_id={id}. Бэк отдаёт только идентификаторы
// (title/подписчики/аватар/премиум в REST нет — для них нужен MTProto-резолв).
public struct ChannelsListResponse: Decodable {
    public let message: String?
    public let data: ChannelsListData?
}

public struct ChannelsListData: Decodable {
    public let items: [DivoChannel]?
}

public struct DivoChannel: Decodable {
    public let id: Int
    public let telegramChatId: Int64?
    public let username: String?
    public let inviteLink: String?
}

// Регистрация созданного канала: POST /channels/add. telegramChatId + inviteLink обязательны,
// username — только для публичных каналов (на момент создания обычно ещё не задан).
public struct ChannelAddRequest: Encodable {
    public let telegramChatId: Int64
    public let username: String?
    public let inviteLink: String

    public init(telegramChatId: Int64, username: String?, inviteLink: String) {
        self.telegramChatId = telegramChatId
        self.username = username
        self.inviteLink = inviteLink
    }
}

public struct ChannelAddResponse: Decodable {
    public let message: String?
}
