import Foundation

/// Причина жалобы из справочника GET /dictionary/feed-report-types.
public struct FeedReportType: Decodable {
    public let id: String
    public let title: String
}

/// POST /feedline/report — жалоба на запись фида (профиль юзера в фиде).
public struct FeedReportRequest: Encodable {
    public let feedId: Int
    public let reportType: String

    public init(feedId: Int, reportType: String) {
        self.feedId = feedId
        self.reportType = reportType
    }
}

public struct FeedReportResponse: Decodable {
    public let message: String?
}

/// POST /user/report — жалоба на профиль по userId (когда нет feedId: поиск/FR/чат).
public struct UserReportRequest: Encodable {
    public let reportUserId: Int
    public let reportText: String

    public init(reportUserId: Int, reportText: String) {
        self.reportUserId = reportUserId
        self.reportText = reportText
    }

    private enum CodingKeys: String, CodingKey {
        case reportUserId = "report_user_id"
        case reportText = "report_text"
    }
}

/// POST /user/block и POST /user/unblock — блокировка / разблокировка по DIVO userId
/// (`users.id`, не id в teamgram). Контракт: docs/divo-api-user-block.md.
public struct UserBlockRequest: Encodable {
    public let userId: Int

    public init(userId: Int) {
        self.userId = userId
    }
}

/// Ответ block / unblock: `data` всегда `null`, решение — по HTTP-коду.
public struct UserBlockResponse: Decodable {
    public let message: String?
}

/// POST /user/blocked — страница списка заблокированных (`limit` 1…100).
public struct BlockedUsersRequest: Encodable {
    public let offset: Int
    public let limit: Int

    public init(offset: Int, limit: Int) {
        self.offset = offset
        self.limit = limit
    }
}

/// Элемент списка заблокированных. В список попадают и удалённые пользователи — признака у них нет.
public struct DivoBlockedUser: Decodable, Equatable {
    public let id: Int
    public let fullName: String?
    public let roleLabel: String?
    /// id в teamgram — по нему обновляем чат с заблокированным; `nil`, если связки нет или аккаунт удалён.
    public let telegramId: Int64?
    /// `avatar ?? photo` (у `avatar` бэк уже подставляет фото / фото агентства).
    public let imageUrl: String?

    private enum CodingKeys: String, CodingKey {
        case id, fullName, roleLabel, telegramId, avatar, photo
    }

    public init(id: Int, fullName: String?, roleLabel: String?, telegramId: Int64?, imageUrl: String?) {
        self.id = id
        self.fullName = fullName
        self.roleLabel = roleLabel
        self.telegramId = telegramId
        self.imageUrl = imageUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        self.roleLabel = try container.decodeIfPresent(String.self, forKey: .roleLabel)
        self.telegramId = try? container.decodeIfPresent(Int64.self, forKey: .telegramId)
        let avatar = try? container.decodeIfPresent(UserFile.self, forKey: .avatar)
        let photo = try? container.decodeIfPresent(UserFile.self, forKey: .photo)
        self.imageUrl = (avatar ?? photo)?.fullUrl
    }

    /// Имя для списка: ФИО → «#id» (у удалённых имени может не быть).
    public var displayName: String {
        if let fullName, !fullName.isEmpty { return fullName }
        return "#\(id)"
    }
}

public struct BlockedUsersResponse: Decodable {
    public let message: String?
    public let data: BlockedUsersPage?
}

public struct BlockedUsersPage: Decodable {
    public let items: [DivoBlockedUser]
    public let pagination: Pagination?

    public struct Pagination: Decodable {
        public let meta: Meta?
    }

    /// `currentOffset` = offset + число элементов страницы — его и передаём следующим offset.
    public struct Meta: Decodable {
        public let limit: Int?
        public let currentOffset: Int?
        public let totalCount: Int?
    }
}
