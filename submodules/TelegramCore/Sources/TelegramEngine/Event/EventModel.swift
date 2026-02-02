//
//  EventModel.swift
//  Telegram
//
//  Created by Radomyr Sidenko on 28.11.2025.
//

public class EventModel {
    public let title: String
    public let description: String
//    let eventType: eventType,
    public let eventDate: String
    public let eventTime: String
//    let location: nil,
    public let coverPhotoId: TelegramMediaImage?
    public let enabledParameterKeys: [String]?
    
    public init(title: String, description: String, eventDate: String, eventTime: String, coverPhotoId: TelegramMediaImage?, enabledParameterKeys: [String]?) {
        self.title = title
        self.description = description
        self.eventDate = eventDate
        self.eventTime = eventTime
        self.coverPhotoId = coverPhotoId
        self.enabledParameterKeys = enabledParameterKeys
    }
}
