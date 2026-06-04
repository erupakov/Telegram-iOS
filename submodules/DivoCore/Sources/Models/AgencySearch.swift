//
//  AgencySearch.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 02.06.2026.
//

import Foundation

public struct AgencySearchRequest: Encodable {
    public let name: String?
    
    public init(
        name: String? = nil
    ) {
        self.name = name
    }
}

public struct AgencySearchResponse: Decodable {
    public let message: String?
    public let data: AgencySearchDataContainer
}

public struct AgencySearchDataContainer: Decodable {
    public let items: [AgencySearchUserDTO]
}

public struct AgencySearchUserDTO: Decodable {
    public let id: Int
    public let name: String?
    public let birthday: String?
    public let photo: UserFile?
    public let city: UserCity?
    public let userId: Int?
    public let role: String?
    public let isPremium: Bool?
    public let currentAgency: AgencySearchCurrentAgency?
}

public struct AgencySearchCurrentAgency: Decodable {
    public let id: Int?
    public let title: String?
}
