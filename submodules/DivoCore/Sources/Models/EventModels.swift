import Foundation

// MARK: - Event List

public struct EventListRequest: Encodable {
    public let offset: Int
    public let limit: Int
    public let creatorId: Int?

    public init(offset: Int, limit: Int, creatorId: Int?) {
        self.offset = offset
        self.limit = limit
        self.creatorId = creatorId
    }
}


public struct EventListResponse: Decodable {
    public let message: String?
    public let data: EventListData
    public let error: String?
}

public struct EventListData: Decodable {
    public let items: [EventListItem]
    public let pagination: EventPagination?
}

public struct EventPagination: Decodable {
    public let meta: Meta?
}

public struct EventListItem: Decodable {
    public let id: Int
    public let title: String?
    public let description: String?
    public let type: EventFullIdTitle?
    public let isApplied: Bool?
    public let appliesCount: Int?
    public let maxAttendees: Int?
    public let viewsCount: Int?
    public let userReachCount: Int?
    public let date: String?
    public let dateTo: String?
    public let place: String?
    public let paymentType: EventFullIdTitle?
    public let paymentFrequency: EventFullIdTitle?
    public let cost: String?
    public let address: EventFullAddress?
    public let files: [EventFile]?
    public let modelAttributes: EventFullModelAttributes?
    public let creator: EventFullCreator?
    public let previsiousEventsFromSameOrigin: [EventSmallItem]?
    public let applicationDeadline: String?
}

public struct EventSmallItem: Decodable {
    public let id: Int
    public let title: String?
    public let date: String?
    public let dateTo: String?
    public let place: String?
    public let photo: EventFile?
    public let type: EventFullIdTitle?
    public let address: EventAddress?
}

public struct EventTypeItem: Decodable {
    public let id: Int?
    public let title: String?
}

public struct EventAddress: Decodable {
    public let street: String?
    public let house: String?
    public let apartment: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let city: EventFullDetailCity?
}

public struct EventCity: Decodable {
    public let id: Int?
    public let countryCode: String?
    public let countryName: String?
    public let areaName: String?
    public let name: String?
}

public struct EventUser: Decodable {
    public let id: Int
    public let fullName: String?
    public let role: String?
    public let photo: UserFile?
    public let avatar: UserFile?
}

public struct EventFile: Decodable {
    public let order: Int?
    public let fileName: String?
    public let fullUrl: String?
    public let fileExtension: String?
    public let fileUuid: String?

    enum CodingKeys: String, CodingKey {
        case order, fullUrl, fileUuid, fileName
        case fileExtension = "extension"
    }
}

// MARK: - Event Detail (Full)

public struct EventFullDetailResponse: Decodable {
    public let message: String?
    public let data: EventFullDetailData?
    public let errors: [String]?
}

public struct EventFullDetailData: Decodable {
    public let id: Int
    public let title: String?
    public let description: String?
    public let type: EventFullIdTitle?
    public let isApplied: Bool?
    public let appliesCount: Int?
    public let viewsCount: Int?
    public let userReachCount: Int?
    public let date: String?
    public let dateTo: String?
    public let place: String?
    public let paymentType: EventFullIdTitle?
    public let paymentFrequency: EventFullIdTitle?
    public let cost: String?
    public let isPublic: Bool?
    public let ndaRequired: Bool?
    public let applicationDeadline: String?
    /// Дата подачи; бэк пока возвращает null → UI берёт fallback.
    public let applicationDate: String?
    public let maxAttendees: Int?
    public let requirements: String?
    public let address: EventFullAddress?
    public let files: [EventFile]?
    public let modelAttributes: EventFullModelAttributes?
    public let creator: EventFullCreator?
    public let previsiousEventsFromSameOrigin: [EventSmallItem]?
    public let appliedMembers: [EventAppliedMember]?
}

public struct EventAppliedMember: Decodable {
    public let id: Int
    public let appliedAt: String?
    public let status: String?
    public let user: EventAppliedUser?
}

public struct EventAppliedUser: Decodable {
    public let id: Int
    public let fullName: String?
    public let roleLabel: String?
    public let avatar: UserFile?
    public let photo: UserFile?
    public let isVerified: Bool?
}

// MARK: - Address & City (Full Detail)

public struct EventFullAddress: Decodable {
    public let street: String?
    public let house: String?
    public let apartment: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let city: EventFullDetailCity?
}

public struct EventFullDetailCity: Decodable {
    public let id: Int?
    public let countryCode: String?
    public let countryName: String?
    public let areaName: String?
    public let name: String?
}

// MARK: - Model Attributes

public struct EventFullModelAttributes: Decodable {
    public let role: [String]?
    public let age: EventFullRange?
    public let gender: [EventFullStringIdTitle]?
    public let height: EventFullRange?
    public let weight: EventFullRange?
    public let breastSize: EventFullRange?
    public let waist: EventFullRange?
    public let hips: EventFullRange?
    public let shoesSize: EventFullRange?
    public let hairColor: [EventFullIdTitle]?
    public let hairLength: [EventFullIdTitle]?
    public let eyeColor: [EventFullIdTitle]?
    public let skinColor: [EventFullIdTitle]?
    public let measuringSystem: String?
}

public struct EventFullRange: Decodable {
    public let from: Float?
    public let to: Float?
}

// MARK: - Creator (Full Detail)

public struct EventFullCreator: Decodable {
    public let id: Int?
    public let fullName: String?
    public let photo: UserFile?
    public let avatar: UserFile?
    public let roleLabel: String?
    public let isVerified: Bool?
}

// MARK: - Helpers

public struct EventFullIdTitle: Decodable {
    public let id: Int?
    public let title: String?
}

public struct EventFullStringIdTitle: Decodable {
    /// e.g. "male", "female"
    public let id: String?
    public let title: String?
}

// MARK: - Event Types

public struct EventTypesRequest: Encodable {
    public let offset: Int
    public let limit: Int

    public init(offset: Int, limit: Int) {
        self.offset = offset
        self.limit = limit
    }
}

public struct EventTypesResponse: Decodable {
    public let message: String?
    public let data: EventTypesData
}

public struct EventTypesData: Decodable {
    public let items: [EventTypeItem]
}

// MARK: - Create / Update Event

public struct CreateEventPreview: Codable {
    public let title: String
    public let description: String
    public let type: String
    public let typeId: Int
    public let date: String
    public let address: EventAddressRequest
    public let countryCode: String?
    public let cityName: String?
    public let files: [EventFileRequest]

    public let isFree: Bool?
    public let cost: String?
    public let isPublic: Bool?
    public let ndaRequired: Bool?
    public let applicationDeadline: String?
    public let maxAttendees: Int?
    public let requirements: String?

    public let role: [String]?
    public let gender: [String]?
    public let age: EventRangeRequest?
    public let height: EventRangeRequest?
    public let weight: EventRangeRequest?
    public let breastSize: EventRangeRequest?
    public let waist: EventRangeRequest?
    public let hips: EventRangeRequest?
    public let shoesSize: EventRangeRequest?
    public let hairColor: [String]?
    public let hairLength: [String]?
    public let eyeColor: [String]?
    public let skinColor: [String]?

    public init(
        title: String,
        description: String,
        type: String,
        typeId: Int,
        date: String,
        address: EventAddressRequest,
        countryCode: String?,
        cityName: String?,
        files: [EventFileRequest],
        isFree: Bool?,
        cost: String?,
        isPublic: Bool?,
        ndaRequired: Bool?,
        applicationDeadline: String?,
        maxAttendees: Int?,
        requirements: String?,
        role: [String]?,
        gender: [String]?,
        age: EventRangeRequest?,
        height: EventRangeRequest?,
        weight: EventRangeRequest?,
        breastSize: EventRangeRequest?,
        waist: EventRangeRequest?,
        hips: EventRangeRequest?,
        shoesSize: EventRangeRequest?,
        hairColor: [String]?,
        hairLength: [String]?,
        eyeColor: [String]?,
        skinColor: [String]?
    ) {
        self.title = title
        self.description = description
        self.type = type
        self.typeId = typeId
        self.date = date
        self.address = address
        self.countryCode = countryCode
        self.cityName = cityName
        self.files = files
        self.isFree = isFree
        self.cost = cost
        self.isPublic = isPublic
        self.ndaRequired = ndaRequired
        self.applicationDeadline = applicationDeadline
        self.maxAttendees = maxAttendees
        self.requirements = requirements
        self.role = role
        self.gender = gender
        self.age = age
        self.height = height
        self.weight = weight
        self.breastSize = breastSize
        self.waist = waist
        self.hips = hips
        self.shoesSize = shoesSize
        self.hairColor = hairColor
        self.hairLength = hairLength
        self.eyeColor = eyeColor
        self.skinColor = skinColor
    }
}

public struct CreateEventRequest: Codable {
    public let title: String
    public let description: String
    public let typeId: Int
    public let date: String
    public let dateTo: String
    public let address: EventAddressRequest
    public let files: [EventFileRequest]

    public let paymentType: Int?
    public let paymentFrequency: Int?
    public let cost: String?
    
    public let isPublic: Bool?
    public let ndaRequired: Bool?
    public let applicationDeadline: String?
    public let maxAttendees: Int?
    public let requirements: String?
    
    public let role: [String]?
    public let gender: [String]?
    public let age: EventRangeRequest?
    public let height: EventRangeRequest?
    public let weight: EventRangeRequest?
    public let breastSize: EventRangeRequest?
    public let waist: EventRangeRequest?
    public let hips: EventRangeRequest?
    public let shoesSize: EventRangeRequest?
    public let hairColor: [Int]?
    public let hairLength: [Int]?
    public let eyeColor: [Int]?
    public let skinColor: [Int]?
    
    public let measuringSystem: String?

    public init(
        title: String,
        description: String,
        typeId: Int,
        date: String,
        dateTo: String,
        address: EventAddressRequest,
        files: [EventFileRequest],
        paymentType: Int?,
        paymentFrequency: Int?,
        cost: String?,
        isPublic: Bool?,
        ndaRequired: Bool?,
        applicationDeadline: String?,
        maxAttendees: Int?,
        requirements: String?,
        role: [String]?,
        gender: [String]?,
        age: EventRangeRequest?,
        height: EventRangeRequest?,
        weight: EventRangeRequest?,
        breastSize: EventRangeRequest?,
        waist: EventRangeRequest?,
        hips: EventRangeRequest?,
        shoesSize: EventRangeRequest?,
        hairColor: [Int]?,
        hairLength: [Int]?,
        eyeColor: [Int]?,
        skinColor: [Int]?,
        measuringSystem: String?
    ) {
        self.title = title
        self.description = description
        self.typeId = typeId
        self.date = date
        self.dateTo = dateTo
        self.address = address
        self.files = files
        self.paymentType = paymentType
        self.paymentFrequency = paymentFrequency
        self.cost = cost
        self.isPublic = isPublic
        self.ndaRequired = ndaRequired
        self.applicationDeadline = applicationDeadline
        self.maxAttendees = maxAttendees
        self.requirements = requirements
        self.role = role
        self.gender = gender
        self.age = age
        self.height = height
        self.weight = weight
        self.breastSize = breastSize
        self.waist = waist
        self.hips = hips
        self.shoesSize = shoesSize
        self.hairColor = hairColor
        self.hairLength = hairLength
        self.eyeColor = eyeColor
        self.skinColor = skinColor
        self.measuringSystem = measuringSystem
    }
}

public struct EventAddressRequest: Codable {
    public let street: String?
    public let house: String?
    public let apartment: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let cityId: Int

    public init(
        street: String?,
        house: String?,
        apartment: String?,
        formatted: String?,
        latitude: Double?,
        longitude: Double?,
        cityId: Int
    ) {
        self.street = street
        self.house = house
        self.apartment = apartment
        self.formatted = formatted
        self.latitude = latitude
        self.longitude = longitude
        self.cityId = cityId
    }
}

public struct EventFileRequest: Codable {
    public let order: Int
    public let fileUuid: String

    public init(order: Int, fileUuid: String) {
        self.order = order
        self.fileUuid = fileUuid
    }
}

public struct EventRangeRequest: Codable {
    public let from: Float
    public let to: Float

    public init(from: Float, to: Float) {
        self.from = from
        self.to = to
    }
}

public struct CreateEventResponse: Codable {
    public let message: String?
    public let errors: [String]?

    public init(message: String?, errors: [String]?) {
        self.message = message
        self.errors = errors
    }
}

public struct DeleteEventResponse: Codable {
    public let message: String?
    public let errors: [String]?

    public init(message: String?, errors: [String]?) {
        self.message = message
        self.errors = errors
    }
}

// MARK: - Apply

public struct ApplyEventRequest: Encodable {
    public let eventId: Int

    public init(eventId: Int) {
        self.eventId = eventId
    }
}

public struct ApplyEventResponse: Decodable {
    public let message: String?
}
