import Foundation

public struct WorkHistoryResponse: Decodable {
    public let message: String?
    public let data: WorkHistoryData
    public let errors: [String]?
}

public struct WorkHistoryData: Decodable {
    public let items: [WorkHistoryItem]
}

public struct WorkHistoryItem: Decodable {
    public let id: Int
    public let agencyId: Int?
    public let agencyName: String?
    public let agencyDisplayName: String?
    public let startDate: String?
    public let endDate: String?
    public let isCurrent: Bool?
    
    public init(
        id: Int,
        agencyId: Int?,
        agencyName: String?,
        agencyDisplayName: String?,
        startDate: String?,
        endDate: String?,
        isCurrent: Bool?
    ) {
        self.id = id
        self.agencyId = agencyId
        self.agencyName = agencyName
        self.agencyDisplayName = agencyDisplayName
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
    public let errors: [String]?
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
    public let errors: [String]?
}
