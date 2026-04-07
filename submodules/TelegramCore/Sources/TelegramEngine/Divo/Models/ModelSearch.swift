//
//  ModelSearch.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.04.2026.
//

import Foundation

public struct ModelsSearchRequest: Encodable {
    public let offset: Int
    public let limit: Int
    public let query: String
    public let role: [String]?
    public let isSkills: Bool?
    public let isEvents: Bool?
    public let isProfiles: Bool?
    public let isPosts: Bool?
    public let withoutNfts: Bool?
    public let subscribedOnly: Bool?
    public let modelsOnly: Bool?
    public let modelParameters: ModelSearchParameters?
    
    public init(
        offset: Int,
        limit: Int,
        query: String,
        role: [String]? = nil,
        isSkills: Bool? = nil,
        isEvents: Bool? = nil,
        isProfiles: Bool? = nil,
        isPosts: Bool? = nil,
        withoutNfts: Bool? = nil,
        subscribedOnly: Bool? = nil,
        modelsOnly: Bool? = nil,
        modelParameters: ModelSearchParameters? = nil
    ) {
        self.offset = offset
        self.limit = limit
        self.query = query
        self.role = role
        self.isSkills = isSkills
        self.isEvents = isEvents
        self.isProfiles = isProfiles
        self.isPosts = isPosts
        self.withoutNfts = withoutNfts
        self.subscribedOnly = subscribedOnly
        self.modelsOnly = modelsOnly
        self.modelParameters = modelParameters
    }
}

public struct ModelSearchParameters: Encodable {
    public let gender: [String]?
    public let geoCityId: Int?
    public let age: RangeParam?
    public let weight: RangeParam?
    public let height: RangeParam?
    public let breastSize: RangeParam?
    public let waist: RangeParam?
    public let shoesSize: RangeParam?
    public let hips: RangeParam?
    public let eyeColor: [Int]?
    public let skinColor: [Int]?
    public let hairColor: [Int]?
    public let hairLength: [Int]?
    
    public init(
        gender: [String]?,
        geoCityId: Int?,
        age: RangeParam?,
        weight: RangeParam?,
        height: RangeParam?,
        breastSize: RangeParam?,
        waist: RangeParam?,
        shoesSize: RangeParam?,
        hips: RangeParam?,
        eyeColor: [Int]?,
        skinColor: [Int]?,
        hairColor: [Int]?,
        hairLength: [Int]?
    ) {
        self.gender = gender
        self.geoCityId = geoCityId
        self.age = age
        self.weight = weight
        self.height = height
        self.breastSize = breastSize
        self.waist = waist
        self.shoesSize = shoesSize
        self.hips = hips
        self.eyeColor = eyeColor
        self.skinColor = skinColor
        self.hairColor = hairColor
        self.hairLength = hairLength
    }
}

public struct RangeParam: Encodable {
    public let from: Int
    public let to: Int
    
    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}

// MARK: - RESPONSE MODELS

public struct ModelsSearchResponse: Decodable {
    public let message: String?
    public let data: SearchDataContainer
    public let errors: [String]?
}

public struct SearchDataContainer: Decodable {
    public let items: [SearchUserDTO]
    public let pagination: Pagination
}

public struct SearchUserDTO: Decodable {
    public let id: Int
    public let feedId: Int
    public let title: String
    public let description: String?
    public let entity: String?
    public let type: String?
    public let likesCount: Int?
    public let isLikedByUser: Bool?
    public let isFavoriteByUser: Bool?
    public let user: SearchUserInfo?
    public let files: [SearchFile]?
    public let searchImage: SearchFile?
    public let additionalData: AdditionalData?
}

public struct AdditionalData: Decodable {
    public let owner: Owner?
    public let amount: Int?
    public let status: String?
    public let creator: Owner?
    public let isCanBuy: Bool?
    public let owner_id: Int?
    public let createdAt: String?
    public let amountCurrency: String?
    public let alternativeAmount: Int?
    public let alternativeAmountCurrency: String?
    
}

public struct Owner: Decodable {
    public let id: Int?
    public let photo: UserFile?
    public let avatar: UserFile?
    public let fullName: String?
    public let roleLabel: String?
}

public struct SearchFile: Decodable {
    public let order: Int?
    public let fullName: String?
    public let fullUrl: String?
    public let fileExtension: String?
    public let videoThumbnail: String?
    public let fileUuid: String?

    enum CodingKeys: String, CodingKey {
        case order, fullUrl, fileUuid, fullName, videoThumbnail
        case fileExtension = "extension"
    }
}

public struct SearchUserInfo: Decodable {
    public let id: Int
    public let fullName: String?
    public let role: String?
    public let roleLabel: String?
    public let city: UserCity?
    public let age: Int?
    public let height: Double?
    public let weight: Double?
    public let emojiCounts: EmojiCounts?
    public let totalEmojisCount: Int?
}

public struct EmojiCounts: Decodable {
    public let thumbsUp: Int
    public let thumbsDown: Int
    public let heart: Int
    public let fire: Int
}

struct SearchCityInfo: Codable {
    let id: Int
    let countryCode: String
    let countryName: String
    let name: String
}

struct SearchImageInfo: Codable {
    let fullUrl: String
}
