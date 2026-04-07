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
    public let agencyPhoto: UserFile?
    public let startDate: String?
    public let endDate: String?
    public let isCurrent: Bool?
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
