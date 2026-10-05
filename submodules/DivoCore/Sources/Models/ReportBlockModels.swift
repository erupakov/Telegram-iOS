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

/// POST /user/block и POST /user/unblock — блокировка / разблокировка пользователя по его DIVO userId.
public struct UserBlockRequest: Encodable {
    public let userId: Int

    public init(userId: Int) {
        self.userId = userId
    }
}

public struct UserBlockResponse: Decodable {
    public let message: String?
}

/// Элемент GET /user/blocked. Бэк может отдать пользователя плоско или обёрткой
/// (`user` / `blockedUser`) — разбираем оба варианта.
public struct DivoBlockedUser: Decodable, Equatable {
    public let id: Int
    public let fullName: String?
    public let nickname: String?
    public let avatarUrl: String?

    private enum CodingKeys: String, CodingKey {
        case id, userId, fullName, nickname, avatar, photo
        case user, blockedUser
        case blockedUserSnake = "blocked_user"
        case userIdSnake = "user_id"
        case fullNameSnake = "full_name"
    }

    public init(id: Int, fullName: String?, nickname: String?, avatarUrl: String?) {
        self.id = id
        self.fullName = fullName
        self.nickname = nickname
        self.avatarUrl = avatarUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        for key in [CodingKeys.user, .blockedUser, .blockedUserSnake] {
            if let nested = try? container.decodeIfPresent(DivoBlockedUser.self, forKey: key) {
                self = nested
                return
            }
        }
        if let id = try? container.decode(Int.self, forKey: .id) {
            self.id = id
        } else if let id = try? container.decode(Int.self, forKey: .userId) {
            self.id = id
        } else {
            self.id = try container.decode(Int.self, forKey: .userIdSnake)
        }
        self.fullName = (try? container.decodeIfPresent(String.self, forKey: .fullName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .fullNameSnake))
        self.nickname = try? container.decodeIfPresent(String.self, forKey: .nickname)
        let avatar = (try? container.decodeIfPresent(UserFile.self, forKey: .avatar))
            ?? (try? container.decodeIfPresent(UserFile.self, forKey: .photo))
        self.avatarUrl = avatar?.fullUrl
    }

    /// Имя для списка: ФИО → никнейм → «#id».
    public var displayName: String {
        if let fullName, !fullName.isEmpty { return fullName }
        if let nickname, !nickname.isEmpty { return nickname }
        return "#\(id)"
    }
}

/// GET /user/blocked. `data` — массив или пагинированный объект (`items` / `list` / `data` / `users`).
public struct BlockedUsersResponse: Decodable {
    public let users: [DivoBlockedUser]

    private enum CodingKeys: String, CodingKey {
        case data
    }

    private enum PageKeys: String, CodingKey {
        case items, list, data, users
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try? container.decode([DivoBlockedUser].self, forKey: .data) {
            self.users = list
            return
        }
        let page = try container.nestedContainer(keyedBy: PageKeys.self, forKey: .data)
        for key in [PageKeys.items, .list, .data, .users] {
            if let list = try? page.decode([DivoBlockedUser].self, forKey: key) {
                self.users = list
                return
            }
        }
        self.users = []
    }
}
