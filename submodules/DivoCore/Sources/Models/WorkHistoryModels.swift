import Foundation

public struct WorkHistoryResponse: Decodable {
    public let message: String?
    public let data: WorkHistoryData
    public let errors: DivoResponseErrors?

    private enum CodingKeys: String, CodingKey { case message, data, errors }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.errors = try container.decodeIfPresent(DivoResponseErrors.self, forKey: .errors)
        self.data = (try? container.decode(WorkHistoryData.self, forKey: .data)) ?? WorkHistoryData(items: [])
    }
}

public struct WorkHistoryData: Decodable {
    public let items: [WorkHistoryItem]

    public init(items: [WorkHistoryItem]) {
        self.items = items
    }

    private enum CodingKeys: String, CodingKey { case items }

    /// Пустая история: бэк (PHP) может отдать `data: []` или `data: null` вместо `{"items": []}` —
    /// это «нет записей», а не ошибка загрузки.
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.items = try container.decodeIfPresent([WorkHistoryItem].self, forKey: .items) ?? []
        } else {
            self.items = []
        }
    }
}

public struct WorkHistoryItem: Decodable {
    public let id: Int
    public let agencyId: Int?
    /// userId пользователя-агентства для перехода в его публичный профиль. nil — у агентства нет
    /// привязанного аккаунта, строка не кликабельна.
    public let agencyUserId: Int?
    public let agencyName: String?
    public let agencyDisplayName: String?
    public let agencyAvatarLink: String?
    public let startDate: String?
    public let endDate: String?
    public let isCurrent: Bool?

    public init(
        id: Int,
        agencyId: Int?,
        agencyUserId: Int? = nil,
        agencyName: String?,
        agencyDisplayName: String?,
        agencyAvatarLink: String? = nil,
        startDate: String?,
        endDate: String?,
        isCurrent: Bool?
    ) {
        self.id = id
        self.agencyId = agencyId
        self.agencyUserId = agencyUserId
        self.agencyName = agencyName
        self.agencyDisplayName = agencyDisplayName
        self.agencyAvatarLink = agencyAvatarLink
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
    }
}

extension WorkHistoryItem {
    public var formattedPeriod: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let startStr = startDate, let start = inputFormatter.date(from: startStr) else {
            return "—"
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        displayFormatter.locale = Locale(identifier: DivoStrings.current.localeIdentifier)

        let startString = displayFormatter.string(from: start)
        let endString: String
        let end: Date

        if isCurrent == true {
            end = Date()
            endString = DivoStrings.present
        } else if let endStr = endDate, let endDate = inputFormatter.date(from: endStr) {
            end = endDate
            endString = displayFormatter.string(from: endDate)
        } else {
            end = Date()
            endString = DivoStrings.present
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: start, to: end)
        let years = components.year ?? 0
        let months = components.month ?? 0

        var durationString = ""
        if years > 0 { durationString += DivoStrings.yearsCount(years) }
        if months > 0 {
            if !durationString.isEmpty { durationString += " " }
            durationString += DivoStrings.monthsCount(months)
        }
        if durationString.isEmpty { durationString = DivoStrings.oneMonth }

        return "\(startString) - \(endString) · \(durationString)"
    }
}

public struct WorkHistoryDeleteResponse: Decodable {
    public let message: String?
    public let errors: DivoResponseErrors?
}

public struct CreateWorkHistoryRequest: Encodable {
    public let agencyId: Int?
    public let agencyName: String?
    public let startDate: String
    public let endDate: String?
    public let isCurrent: Bool

    public init(agencyId: Int?, agencyName: String?, startDate: String, endDate: String?, isCurrent: Bool) {
        self.agencyId = agencyId
        self.agencyName = agencyName
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
    }
}

public struct WorkHistorySaveResponse: Decodable {
    public let message: String?
    public let errors: DivoResponseErrors?
}
