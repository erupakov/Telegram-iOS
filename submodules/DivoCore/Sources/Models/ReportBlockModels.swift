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

/// POST /messenger/block-user — блокировка пользователя в мессенджере.
public struct BlockUserRequest: Encodable {
    public let recipientId: Int

    public init(recipientId: Int) {
        self.recipientId = recipientId
    }
}

public struct BlockUserResponse: Decodable {
    public let message: String?
}
