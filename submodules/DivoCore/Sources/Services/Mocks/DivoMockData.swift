import Foundation

public enum DivoMockData {

    // MARK: - Generic

    static let genericSuccess = """
    {"message": "OK", "data": null, "errors": []}
    """.data(using: .utf8)!

    // MARK: - /dictionary/gender

    static let dictionaryGender = """
    {
        "data": [
            {"id": "male", "title": "Male"},
            {"id": "female", "title": "Female"},
            {"id": "non_binary", "title": "Non-binary"}
        ]
    }
    """.data(using: .utf8)!

    // MARK: - /dictionary/appearances

    static let dictionaryAppearances = """
    {
        "data": {
            "hairLength": [
                {"id": 1, "title": "Short"},
                {"id": 2, "title": "Medium"},
                {"id": 3, "title": "Long"}
            ],
            "hairColor": [
                {"id": 1, "title": "Blonde"},
                {"id": 2, "title": "Brown"},
                {"id": 3, "title": "Black"},
                {"id": 4, "title": "Red"}
            ],
            "eyeColor": [
                {"id": 1, "title": "Blue"},
                {"id": 2, "title": "Green"},
                {"id": 3, "title": "Brown"},
                {"id": 4, "title": "Gray"}
            ],
            "skinColor": [
                {"id": 1, "title": "Light"},
                {"id": 2, "title": "Medium"},
                {"id": 3, "title": "Dark"}
            ]
        }
    }
    """.data(using: .utf8)!

    // MARK: - /feedline/search

    static func feedlineSearch(offset: Int, limit: Int) -> Data {
        let allItems = searchItems
        let end = min(offset + limit, allItems.count)
        let slice = offset < allItems.count ? Array(allItems[offset..<end]) : []
        let itemsJSON = slice.joined(separator: ",\n")
        return """
        {
            "message": "OK",
            "data": {
                "items": [\(itemsJSON)],
                "pagination": {
                    "meta": {
                        "limit": \(limit),
                        "currentOffset": \(offset),
                        "totalCount": \(allItems.count)
                    }
                }
            },
            "errors": []
        }
        """.data(using: .utf8)!
    }

    // MARK: - /feedline/list

    static func feedlineList(offset: Int, limit: Int) -> Data {
        let allItems = feedlineItems
        let end = min(offset + limit, allItems.count)
        let slice = offset < allItems.count ? Array(allItems[offset..<end]) : []
        let itemsJSON = slice.joined(separator: ",\n")
        return """
        {
            "message": "OK",
            "data": {
                "items": [\(itemsJSON)]
            },
            "errors": []
        }
        """.data(using: .utf8)!
    }

    // MARK: - /user/{id} & /user/info

    static func userDetail(id: Int, useCurrentRole: Bool = true) -> Data {
        let role = useCurrentRole ? DivoConfig.currentUserRole : .model
        let imgId = 100 + id
        let roleString = role.rawValue
        let roleLabel: String
        let fullName: String
        let modelBlock: String
        let agencyBlock: String
        let agencyEmployeeBlock: String
        let customerBlock: String

        switch role {
        case .model:
            roleLabel = "Model"
            fullName = "Mock Model \(id)"
            modelBlock = """
            {
                        "height": 175.0,
                        "weight": 58.0,
                        "bust": 86.0,
                        "waist": 62.0,
                        "hips": 90.0,
                        "shoeSize": 38.0,
                        "hairColor": {"id": 2, "title": "Brown"},
                        "hairLength": {"id": 2, "title": "Medium"},
                        "eyeColor": {"id": 1, "title": "Blue"},
                        "skinColor": {"id": 1, "title": "Light"}
                    }
            """
            agencyBlock = "null"
            agencyEmployeeBlock = "null"
            customerBlock = "null"
        case .newFace:
            roleLabel = "New Face"
            fullName = "Mock New Face \(id)"
            modelBlock = """
            {
                        "height": 170.0,
                        "weight": 55.0,
                        "bust": 84.0,
                        "waist": 60.0,
                        "hips": 88.0,
                        "shoeSize": 37.0,
                        "hairColor": {"id": 1, "title": "Blonde"},
                        "hairLength": {"id": 3, "title": "Long"},
                        "eyeColor": {"id": 2, "title": "Green"},
                        "skinColor": {"id": 1, "title": "Light"}
                    }
            """
            agencyBlock = "null"
            agencyEmployeeBlock = "null"
            customerBlock = "null"
        case .agency:
            roleLabel = "Agency"
            fullName = "Mock Agency \(id)"
            modelBlock = "null"
            agencyBlock = "null"
            agencyEmployeeBlock = """
            {
                        "agencyId": 1,
                        "agencyName": "Elite Models",
                        "position": "Manager"
                    }
            """
            customerBlock = "null"
        case .fan:
            roleLabel = "Fan"
            fullName = "Mock Fan \(id)"
            modelBlock = "null"
            agencyBlock = "null"
            agencyEmployeeBlock = "null"
            customerBlock = """
            {
                        "interests": ["Fashion", "Photography"]
                    }
            """
        }

        return """
        {
            "message": "OK",
            "data": {
                "id": \(id),
                "fullName": "\(fullName)",
                "gender": {"id": "female", "title": "Female"},
                "birthday": "1998-05-14",
                "city": {"id": 1, "countryCode": "US", "countryName": "United States", "areaName": null, "name": "New York"},
                "email": "user\(id)@mock.test",
                "phone": null,
                "photo": {"fileName": "photo.jpg", "fullUrl": "https://picsum.photos/id/\(imgId)/400/600", "extension": "jpg", "fileUuid": "mock-photo-\(id)"},
                "avatar": {"fileName": "avatar.jpg", "fullUrl": "https://picsum.photos/id/\(imgId)/200/200", "extension": "jpg", "fileUuid": "mock-avatar-\(id)"},
                "role": "\(roleString)",
                "subrole": null,
                "roleLabel": "\(roleLabel)",
                "measuringSystem": "metric",
                "pushNotifications": true,
                "isRegistrationFinished": true,
                "model": \(modelBlock),
                "customer": \(customerBlock),
                "agency": \(agencyBlock),
                "agencyEmployee": \(agencyEmployeeBlock),
                "statistic": {"subscribersCount": 42, "subscriptionsCount": 15, "postsCount": 8},
                "isFavorite": false,
                "isFollowed": false,
                "userRatingStatus": null,
                "userSocialNetworks": [
                    {"type": "instagram", "url": "https://instagram.com/mockuser\(id)"}
                ]
            },
            "errors": []
        }
        """.data(using: .utf8)!
    }

    // MARK: - /user/engagement

    static let userEngagement = """
    {
        "data": {
            "liked": {
                "items": [],
                "pagination": {"meta": {"limit": 1, "currentOffset": 0, "totalCount": 128}}
            },
            "viewed": {
                "items": [],
                "pagination": {"meta": {"limit": 1, "currentOffset": 0, "totalCount": 540}}
            },
            "followed": {
                "items": [],
                "pagination": {"meta": {"limit": 1, "currentOffset": 0, "totalCount": 42}}
            }
        }
    }
    """.data(using: .utf8)!

    // MARK: - /user-gallery/list

    static func galleryList(offset: Int, limit: Int) -> Data {
        let allItems: [String] = (1...12).map { i in
            let imgId = 300 + i
            return """
            {
                "id": \(i),
                "photo": {
                    "fileName": "gallery_\(i).jpg",
                    "fullUrl": "https://picsum.photos/id/\(imgId)/400/600",
                    "extension": "jpg",
                    "fileUuid": "mock-gallery-\(i)"
                },
                "likesCount": \(i * 5),
                "isLikedByUser": false,
                "preview": {
                    "fileName": "gallery_\(i)_preview.jpg",
                    "fullUrl": "https://picsum.photos/id/\(imgId)/200/200",
                    "extension": "jpg",
                    "fileUuid": "mock-gallery-preview-\(i)"
                }
            }
            """
        }
        let end = min(offset + limit, allItems.count)
        let slice = offset < allItems.count ? Array(allItems[offset..<end]) : []
        let itemsJSON = slice.joined(separator: ",\n")
        return """
        {
            "message": "OK",
            "data": {
                "items": [\(itemsJSON)],
                "pagination": {
                    "meta": {"limit": \(limit), "currentOffset": \(offset), "totalCount": \(allItems.count)}
                }
            },
            "errors": []
        }
        """.data(using: .utf8)!
    }

    // MARK: - /publication/list (empty)

    static let emptyPaginatedList = """
    {
        "message": "OK",
        "data": {
            "items": [],
            "pagination": {"meta": {"limit": 20, "currentOffset": 0, "totalCount": 0}}
        },
        "errors": []
    }
    """.data(using: .utf8)!

    // MARK: - /fr/detect (1 face, чтобы можно было нажать Find)

    static let frDetect = """
    {
        "faces": [
            {
                "area": 0.25,
                "bbox": {"x1": 0.3, "x2": 0.7, "y1": 0.2, "y2": 0.6},
                "index": 0
            }
        ]
    }
    """.data(using: .utf8)!

    // MARK: - /fr/search (empty — для проверки empty state)

    static let frSearchEmpty = """
    {
        "bbox": {"x1": 0.3, "x2": 0.7, "y1": 0.2, "y2": 0.6},
        "face_info": {"age": null, "emotion": null, "gender": null, "race": null},
        "results": []
    }
    """.data(using: .utf8)!

    // MARK: - /event/list (empty)

    static let emptyEventList = """
    {
        "message": "OK",
        "data": {
            "items": [],
            "pagination": {"total": 0, "limit": 20, "offset": 0}
        },
        "error": null
    }
    """.data(using: .utf8)!

    // MARK: - /event/types

    static let eventTypes = """
    {
        "message": "OK",
        "data": [
            {"id": 1, "title": "Photoshoot"},
            {"id": 2, "title": "Fashion Show"},
            {"id": 3, "title": "Casting"}
        ],
        "errors": []
    }
    """.data(using: .utf8)!

    // MARK: - /event/{id}

    static let eventDetail = """
    {
        "message": "OK",
        "data": {
            "id": 1,
            "title": "Mock Photoshoot",
            "description": "A mock event for testing",
            "status": "active",
            "type": {"id": 1, "title": "Photoshoot"},
            "startDate": "2026-05-01T10:00:00Z",
            "endDate": "2026-05-01T18:00:00Z",
            "city": {"id": 1, "countryCode": "US", "countryName": "United States", "name": "New York"},
            "files": [],
            "creator": {"id": 1, "fullName": "Mock Agency", "role": "agency_employee", "roleLabel": "Agency"},
            "participants": [],
            "requirements": null
        },
        "errors": []
    }
    """.data(using: .utf8)!

    // MARK: - /agency/list

    static let agencyList = """
    {
        "message": "OK",
        "data": {
            "items": [
                {"id": 1, "title": "Elite Models", "logo": null},
                {"id": 2, "title": "IMG Models", "logo": null},
                {"id": 3, "title": "Storm Models", "logo": null}
            ]
        },
        "errors": []
    }
    """.data(using: .utf8)!

    // MARK: - /agency/{id}/models/list

    static let agencyModelsList = """
    {
        "message": "OK",
        "data": {
            "items": [],
            "pagination": {"total": 0, "limit": 20, "offset": 0}
        },
        "errors": []
    }
    """.data(using: .utf8)!

    // MARK: - /model-work-history

    static let emptyWorkHistory = """
    {
        "message": "OK",
        "data": {
            "items": []
        },
        "errors": []
    }
    """.data(using: .utf8)!

    // MARK: - Search Items (25)

    private static let searchItems: [String] = (1...25).map { i in
        let names = ["Emma Stone", "Liam Park", "Sofia Reyes", "Noah Kim", "Mia Chen",
                     "Oliver Müller", "Ava Johnson", "Lucas Silva", "Isabella Brown", "Ethan Lee",
                     "Charlotte Davis", "James Wilson", "Amelia Garcia", "Benjamin Moore", "Harper Taylor",
                     "Alexander White", "Evelyn Martin", "William Thompson", "Abigail Anderson", "Henry Jackson",
                     "Emily Harris", "Daniel Clark", "Elizabeth Lewis", "Matthew Robinson", "Ella Walker"]
        let cities = ["New York", "London", "Paris", "Tokyo", "Milan",
                      "Berlin", "Los Angeles", "Barcelona", "Seoul", "Moscow"]
        let roles = ["model", "new_face", "model", "new_face", "model"]
        let roleLabels = ["Model", "New Face", "Model", "New Face", "Model"]
        let name = names[(i - 1) % names.count]
        let city = cities[(i - 1) % cities.count]
        let role = roles[(i - 1) % roles.count]
        let roleLabel = roleLabels[(i - 1) % roleLabels.count]
        let age = 18 + (i % 15)
        let imgId = 100 + i
        return """
        {
            "id": \(i),
            "feedId": \(1000 + i),
            "title": "\(name)",
            "description": null,
            "entity": "user",
            "type": "profile",
            "likesCount": \(i * 12),
            "isLikedByUser": \(i == 1),
            "isFavoriteByUser": \(i == 1),
            "user": {
                "id": \(i),
                "fullName": "\(name)",
                "role": "\(role)",
                "roleLabel": "\(roleLabel)",
                "city": {"id": \(i), "countryCode": "US", "countryName": "United States", "areaName": null, "name": "\(city)"},
                "age": \(age),
                "height": \(165.0 + Double(i % 20)),
                "weight": \(52.0 + Double(i % 15)),
                "emojiCounts": null,
                "totalEmojisCount": null
            },
            "files": [],
            "searchImage": {
                "order": 0,
                "fullName": "photo_\(i).jpg",
                "fullUrl": "https://picsum.photos/id/\(imgId)/400/600",
                "extension": "jpg",
                "videoThumbnail": null,
                "fileUuid": "mock-uuid-\(i)"
            },
            "additionalData": null
        }
        """
    }

    // MARK: - Feedline Items (30)

    private static let feedlineItems: [String] = (1...30).map { i in
        let names = ["Anna Petrova", "Maria Santos", "Jessica Kim", "Laura Weber", "Nina Ivanova",
                     "Sophie Dubois", "Yuki Tanaka", "Camila Lopez", "Diana Volkov", "Grace Park",
                     "Zara Ahmed", "Elena Rossi", "Fatima Al-Rashid", "Priya Sharma", "Ingrid Svensson",
                     "Mei Lin", "Aisha Okafor", "Valentina Cruz", "Hana Novak", "Leah Cohen",
                     "Ruby Chang", "Freya Hansen", "Amara Diallo", "Isla Murphy", "Nadia Petrov",
                     "Carmen Ruiz", "Suki Yamamoto", "Lena Fischer", "Maya Johansson", "Zoe Laurent"]
        let name = names[(i - 1) % names.count]
        let imgId = 200 + i
        return """
        {
            "id": \(i),
            "feedId": \(2000 + i),
            "title": "\(name)",
            "description": null,
            "entity": "user",
            "type": "profile",
            "likesCount": \(i * 8),
            "isLikedByUser": false,
            "isFavoriteByUser": false,
            "user": {
                "id": \(100 + i),
                "fullName": "\(name)",
                "role": "model",
                "subrole": null,
                "roleLabel": "Model"
            },
            "files": [
                {
                    "order": 0,
                    "fullName": "photo_\(i).jpg",
                    "fullUrl": "https://picsum.photos/id/\(imgId)/400/600",
                    "extension": "jpg",
                    "videoThumbnail": null,
                    "fileUuid": "mock-feed-uuid-\(i)"
                }
            ],
            "searchImage": {
                "order": 0,
                "fullName": "avatar_\(i).jpg",
                "fullUrl": "https://picsum.photos/id/\(imgId)/200/200",
                "extension": "jpg",
                "videoThumbnail": null,
                "fileUuid": "mock-feed-avatar-\(i)"
            }
        }
        """
    }
}
