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
    let coverPhotoURL: String?
    let profilePhotoURL: String?
    let location: String
    let eventDateFormatted: String

    init(
        id: Int = 0,
        title: String,
        subtitle: String,
        imageName: String = "",
        profileImageName: String = "",
        profileName: String,
        timeRemaining: String,
        type: String = "",
        coverPhoto: TelegramMediaImage? = nil,
        profilePhoto: TelegramMediaImage? = nil,
        coverPhotoURL: String? = nil,
        profilePhotoURL: String? = nil,
        location: String = "",
        eventDateFormatted: String = ""
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
        self.coverPhotoURL = coverPhotoURL
        self.profilePhotoURL = profilePhotoURL
        self.location = location
        self.eventDateFormatted = eventDateFormatted
    }

    private static func mockDateFormatted(_ isoDate: String) -> String {
        let locale = Locale(identifier: DivoStrings.current.rawValue)
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = iso.date(from: isoDate) else { return isoDate }
        let datePart = DateFormatter()
        datePart.locale = locale
        datePart.setLocalizedDateFormatFromTemplate("MMM d")
        let timePart = DateFormatter()
        timePart.locale = locale
        timePart.timeStyle = .short
        timePart.dateStyle = .none
        return datePart.string(from: date) + " \u{00B7} " + timePart.string(from: date)
    }

    private static func mockTimeRemaining(_ isoDate: String) -> String {
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = iso.date(from: isoDate) else { return "" }
        let interval = date.timeIntervalSince(Date())
        guard interval > 0 else { return "" }
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.day, .hour, .minute]
        f.calendar = Calendar.current
        f.calendar?.locale = Locale(identifier: DivoStrings.current.rawValue)
        return f.string(from: interval) ?? ""
    }

    static func mockEvents() -> [EventData] {
        let mockDate = "2026-05-27T17:00:00"
        return [
            EventData(
                id: 1,
                title: "FASHION MODEL EVENT",
                subtitle: "Fashion Show",
                profileName: "@nyfw",
                timeRemaining: mockTimeRemaining(mockDate),
                coverPhotoURL: "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: mockDateFormatted(mockDate)
            ),
            EventData(
                id: 2,
                title: "FASHION MODEL EVENT",
                subtitle: "Runway",
                profileName: "@nyfw",
                timeRemaining: mockTimeRemaining(mockDate),
                coverPhotoURL: "https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: mockDateFormatted(mockDate)
            ),
            EventData(
                id: 3,
                title: "FASHION MODEL EVENT",
                subtitle: "Casting",
                profileName: "@nyfw",
                timeRemaining: mockTimeRemaining(mockDate),
                coverPhotoURL: "https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: mockDateFormatted(mockDate)
            ),
            EventData(
                id: 4,
                title: "FASHION MODEL EVENT",
                subtitle: "Photo Shoot",
                profileName: "@nyfw",
                timeRemaining: mockTimeRemaining(mockDate),
                coverPhotoURL: "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: mockDateFormatted(mockDate)
            ),
            EventData(
                id: 5,
                title: "FASHION MODEL EVENT",
                subtitle: "Fashion Week",
                profileName: "@nyfw",
                timeRemaining: mockTimeRemaining(mockDate),
                coverPhotoURL: "https://images.unsplash.com/photo-1445205170230-053b83016050?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: mockDateFormatted(mockDate)
            ),
            EventData(
                id: 6,
                title: "FASHION MODEL EVENT",
                subtitle: "Gala",
                profileName: "@nyfw",
                timeRemaining: mockTimeRemaining(mockDate),
                coverPhotoURL: "https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "New York",
                eventDateFormatted: mockDateFormatted(mockDate)
            ),
            EventData(
                id: 7,
                title: "HAUTE COUTURE SHOW",
                subtitle: "Fashion Show",
                profileName: "@parisfashion",
                timeRemaining: mockTimeRemaining("2026-06-03T19:00:00"),
                coverPhotoURL: "https://images.unsplash.com/photo-1509631179647-0177331693ae?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "Paris",
                eventDateFormatted: mockDateFormatted("2026-06-03T19:00:00")
            ),
            EventData(
                id: 8,
                title: "RUNWAY CASTING",
                subtitle: "Casting",
                profileName: "@milanfw",
                timeRemaining: mockTimeRemaining("2026-06-05T10:00:00"),
                coverPhotoURL: "https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "Milan",
                eventDateFormatted: mockDateFormatted("2026-06-05T10:00:00")
            ),
            EventData(
                id: 9,
                title: "EDITORIAL SHOOT",
                subtitle: "Photo Shoot",
                profileName: "@vogueitalia",
                timeRemaining: mockTimeRemaining("2026-05-29T14:00:00"),
                coverPhotoURL: "https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "London",
                eventDateFormatted: mockDateFormatted("2026-05-29T14:00:00")
            ),
            EventData(
                id: 10,
                title: "BRAND LOOKBOOK",
                subtitle: "Photo Shoot",
                profileName: "@zara",
                timeRemaining: mockTimeRemaining("2026-06-08T11:00:00"),
                coverPhotoURL: "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400&q=80",
                profilePhotoURL: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&q=80",
                location: "Barcelona",
                eventDateFormatted: mockDateFormatted("2026-06-08T11:00:00")
            ),
        ]
    }
}
