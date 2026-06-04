//
//  GeoSearchResponse.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 04.06.2026.
//

import Foundation

public struct GeoSearchResponse: Decodable {
    public let message: String?
    public let data: [GeoAddressItem]?
    public let errors: [String]?
}

public struct GeoAddressItem: Decodable {
    public let area: String?
    public let index: String?
    public let formatted: String?
    public let latitude: Double?
    public let longitude: Double?
    public let city: GeoCity?
    public let country: GeoCountry?
}

public struct GeoCity: Decodable {
    public let id: Int?
    public let countryCode: String?
    public let countryName: String?
    public let areaName: String?
    public let name: String?
}

public struct GeoCountry: Decodable {
    public let name: String?
    public let code: String?
}
