import Foundation
import UIKit
import TelegramCore

struct EventData {
    let title: String
    let subtitle: String
    let imageName: String
    let profileImageName: String
    let profileName: String
    let timeRemaining: String
    let type: String
    let coverPhotoId: TelegramMediaImage?
    
    init(
        title: String,
        subtitle: String,
        imageName: String,
        profileImageName: String,
        profileName: String,
        timeRemaining: String,
        type: String = "",
        coverPhotoId: TelegramMediaImage? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.profileImageName = profileImageName
        self.profileName = profileName
        self.timeRemaining = timeRemaining
        self.type = type
        self.coverPhotoId = coverPhotoId
    }
}
