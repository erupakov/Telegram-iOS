import Foundation
import UIKit
import TelegramCore

struct EventData {
    let id: Int
    let title: String
    let subtitle: String
    let imageName: String
    let profileImageName: String
    let profileName: String
    let timeRemaining: String
    let type: String
    let coverPhoto: TelegramMediaImage?
    let profilePhoto: TelegramMediaImage?
    
    init(
        id: Int = 0,
        title: String,
        subtitle: String,
        imageName: String,
        profileImageName: String,
        profileName: String,
        timeRemaining: String,
        type: String = "",
        coverPhoto: TelegramMediaImage? = nil,
        profilePhoto: TelegramMediaImage? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.profileImageName = profileImageName
        self.profileName = profileName
        self.timeRemaining = timeRemaining
        self.type = type
        self.coverPhoto = coverPhoto
        self.profilePhoto = profilePhoto
    }
}
