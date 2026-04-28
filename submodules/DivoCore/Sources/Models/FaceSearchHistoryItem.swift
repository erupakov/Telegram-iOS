import Foundation

public struct FaceSearchHistoryItem: Codable, Equatable {
    public let id: String
    public let resultsCount: Int
    public let date: Date
    public let faceImageFileName: String
    public let sourceImageFileName: String
    public let faceIndex: Int
    public let faceBBox: FRBoundingBox?
    public let similarityPercent: Int
    public let filterParts: [String]
    public let searchFields: [String: String]

    public init(
        resultsCount: Int,
        date: Date,
        faceImageFileName: String,
        sourceImageFileName: String,
        faceIndex: Int,
        faceBBox: FRBoundingBox?,
        similarityPercent: Int = 30,
        filterParts: [String] = [],
        searchFields: [String: String] = [:]
    ) {
        self.id = UUID().uuidString
        self.resultsCount = resultsCount
        self.date = date
        self.faceImageFileName = faceImageFileName
        self.sourceImageFileName = sourceImageFileName
        self.faceIndex = faceIndex
        self.faceBBox = faceBBox
        self.similarityPercent = similarityPercent
        self.filterParts = filterParts
        self.searchFields = searchFields
    }

    public init(
        id: String,
        resultsCount: Int,
        date: Date,
        faceImageFileName: String,
        sourceImageFileName: String,
        faceIndex: Int,
        faceBBox: FRBoundingBox?,
        similarityPercent: Int = 30,
        filterParts: [String] = [],
        searchFields: [String: String] = [:]
    ) {
        self.id = id
        self.resultsCount = resultsCount
        self.date = date
        self.faceImageFileName = faceImageFileName
        self.sourceImageFileName = sourceImageFileName
        self.faceIndex = faceIndex
        self.faceBBox = faceBBox
        self.similarityPercent = similarityPercent
        self.filterParts = filterParts
        self.searchFields = searchFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        resultsCount = try container.decode(Int.self, forKey: .resultsCount)
        date = try container.decode(Date.self, forKey: .date)
        faceImageFileName = try container.decode(String.self, forKey: .faceImageFileName)
        sourceImageFileName = try container.decodeIfPresent(String.self, forKey: .sourceImageFileName) ?? ""
        faceIndex = try container.decodeIfPresent(Int.self, forKey: .faceIndex) ?? 0
        faceBBox = try container.decodeIfPresent(FRBoundingBox.self, forKey: .faceBBox)
        similarityPercent = try container.decodeIfPresent(Int.self, forKey: .similarityPercent) ?? 30
        filterParts = try container.decodeIfPresent([String].self, forKey: .filterParts) ?? []
        searchFields = try container.decodeIfPresent([String: String].self, forKey: .searchFields) ?? [:]
    }
}
