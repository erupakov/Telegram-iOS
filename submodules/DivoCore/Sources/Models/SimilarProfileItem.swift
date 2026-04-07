//
//  SimilarProfileItem.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 08.03.2026.
//

import Foundation

public struct SimilarProfileItem {
    public let id: Int
    public let name: String
    public let info: String
    public let avatarURL: URL?

    public init(id: Int, name: String, info: String, avatarURL: URL?) {
        self.id = id
        self.name = name
        self.info = info
        self.avatarURL = avatarURL
    }
}
