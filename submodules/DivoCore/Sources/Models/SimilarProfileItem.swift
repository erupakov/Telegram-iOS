//
//  SimilarProfileItem.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 08.03.2026.
//

import Foundation

public struct SimilarProfileItem {
    public let id: Int
    public let name: String?
    public let age: String?
    public let countryCode: String?
    public let countryName: String?
    public let avatarURL: URL?

    public init(id: Int, name: String?, age: String?, countryCode: String?, countryName: String?, avatarURL: URL?) {
        self.id = id
        self.name = name
        self.age = age
        self.countryCode = countryCode
        self.countryName = countryName
        self.avatarURL = avatarURL
    }
}

public struct SearchSimilarRequest: Encodable {
    public let photoId: Int?
    public let topK: Int?
    
    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case topK = "top_k"
    }

    public init(photoId: Int?, topK: Int?) {
        self.photoId = photoId
        self.topK = topK
    }
}

public struct SearchSimilarResponse: Decodable {
    public let photoId: Int?
    public let results: [SimilarFaceDto?]
    
    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case results
    }
}

public struct SimilarFaceDto: Decodable {
    public let birthday: String?
    public let countryCode: String?
    public let countryName: String?
    public let fullName: String?
    public let image: String?
    public let index: Int?
    public let rank: Int?
    public let role: String?
    public let score: Double?
    public let userId: Int?
    
    enum CodingKeys: String, CodingKey {
        case birthday
        case countryCode = "country_code"
        case countryName = "country_name"
        case fullName = "full_name"
        case image
        case index
        case rank
        case role
        case score
        case userId = "user_id"
    }
}
