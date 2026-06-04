//
//  RosterUser.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 01.06.2026.
//

import Foundation
import UIKit

public enum RosterUserStatus: Equatable {
    case available(handle: String, role: String)
    case alreadyAdded(agencyName: String)
}

public struct RosterSearchUser: Equatable {
    public let id: Int
    public let name: String
    public let avatarUrl: String?
    public let isPremium: Bool
    public let status: RosterUserStatus

    public init(id: Int, name: String, avatarUrl: String? = nil, isPremium: Bool, status: RosterUserStatus) {
        self.id = id
        self.name = name
        self.avatarUrl = avatarUrl
        self.isPremium = isPremium
        self.status = status
    }
}

public enum AddRosterScreenState: Equatable {
    case initial
    case idle
    case loading
    case empty
    case success(users: [RosterSearchUser])
    case failed(networkError: Bool)
}
