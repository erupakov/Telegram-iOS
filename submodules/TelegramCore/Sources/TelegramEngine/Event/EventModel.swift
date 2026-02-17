//
//  EventModel.swift
//  Telegram
//
//  Created by Radomyr Sidenko on 28.11.2025.
//

public class EventModel {
    public let id: Int
    public let title: String
    public let description: String
    public let eventDate: String
    public let eventTime: String
    public let creatorName: String?
    public let creatorPhoto: TelegramMediaImage?
    
    public let coverPhoto: TelegramMediaImage?
    public let enabledParameterKeys: [String]?
    
    public let eventType: String?
    public let gallery: [TelegramMediaImage]?
    
//    let stats: Stats?
//    parameters: nil,
//    applyParameters: nil,
//    previousEvents: nil,
    
    public init(
        id: Int = 0,
        title: String,
        description: String,
        eventDate: String,
        eventTime: String,
        coverPhoto: TelegramMediaImage?,
        enabledParameterKeys: [String]? = nil,
        eventType: String? = nil,
        gallery: [TelegramMediaImage]? = nil,
        creatorName: String? = nil,
        creatorPhoto: TelegramMediaImage? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.eventDate = eventDate
        self.eventTime = eventTime
        self.coverPhoto = coverPhoto
        self.enabledParameterKeys = enabledParameterKeys
        self.eventType = eventType
        self.gallery = gallery
        self.creatorName = creatorName
        self.creatorPhoto = creatorPhoto
    }
}
//
//public struct Stats {
//    let participantsCount: Int
//    let viewsCount: Int
//    let likesCount: Int
//    let isLiked: Bool
//    
//    public init(participantsCount: Int, viewsCount: Int, likesCount: Int, isLiked: Bool) {
//        self.participantsCount = participantsCount
//        self.viewsCount = viewsCount
//        self.likesCount = likesCount
//        self.isLiked = isLiked
//    }
//}
