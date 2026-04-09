//
//  UserGalleryModels.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

public struct GalleryListRequest: Encodable {
    public let offset: Int
    public let limit: Int
    public let userId: Int

    public init(offset: Int, limit: Int, userId: Int) {
        self.offset = offset
        self.limit = limit
        self.userId = userId
    }
}

public struct UserGalleryResponse: Decodable {
    public let message: String?
    public let data: UserPhotos
    public let errors: [String]?
}

public struct UserPhotos: Decodable {
    public let items: [UserPhoto]
    public let pagination: Pagination
}

public struct UserPhoto: Decodable {
    public let id: Int
    public let photo: UserFile
    public let likesCount: Int?
    public let isLikedByUser: Bool
    public let preview: UserFile?

    public init(id: Int, photo: UserFile, likesCount: Int?, isLikedByUser: Bool, preview: UserFile?) {
        self.id = id
        self.photo = photo
        self.likesCount = likesCount
        self.isLikedByUser = isLikedByUser
        self.preview = preview
    }
}

// MARK: - Video Gallery Models (New API)

public struct UserVideoGalleryResponse: Decodable {
    public let message: String?
    public let data: UserVideoItems
    public let errors: [String]?
}

public struct UserVideoItems: Decodable {
    public let items: [UserVideoItem]
    public let pagination: Pagination
}

public struct UserVideoItem: Decodable {
    public let id: Int
    public let title: String?
    public let description: String?
    public let type: String?
    public let likesCount: Int
    public let isLikedByUser: Bool
    public let files: [UserVideoFile]

    public init(id: Int, title: String?, description: String?, type: String?, likesCount: Int, isLikedByUser: Bool, files: [UserVideoFile]) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.likesCount = likesCount
        self.isLikedByUser = isLikedByUser
        self.files = files
    }
}

public struct UserVideoFile: Decodable {
    public let order: Int?
    public let fileName: String?
    public let fullUrl: String?
    public let fileUuid: String?
    public let fileExtension: String?
    public let description: String?

    private enum CodingKeys: String, CodingKey {
        case order, fileName, fullUrl, fileUuid, description
        case fileExtension = "extension"
    }

    public init(order: Int?, fileName: String?, fullUrl: String?, fileUuid: String?, fileExtension: String?, description: String?) {
        self.order = order
        self.fileName = fileName
        self.fullUrl = fullUrl
        self.fileUuid = fileUuid
        self.fileExtension = fileExtension
        self.description = description
    }
}

public struct Pagination: Decodable {
    public let meta: Meta
}

public struct Meta: Decodable {
    public let limit: Int
    public let currentOffset: Int
    public let totalCount: Int
}

public struct AddPublicationRequest: Codable {
    public let title: String
    public let description: String
    public let type: String
    public let files: [VideoFileData]

    public init(title: String, description: String, type: String, files: [VideoFileData]) {
        self.title = title
        self.description = description
        self.type = type
        self.files = files
    }
}
            
public struct VideoFileData: Codable {
    public let order: Int
    public let fileUuid: String

    public init(order: Int, fileUuid: String) {
        self.order = order
        self.fileUuid = fileUuid
    }
}
            
public struct AddPublicationResponse: Decodable {
    public let message: String?
    public let data: UserPublication?
    public let errors: String?
}

public struct UserPublication: Decodable {
    public let id: Int?
    public let title: String?
    public let description: String?
    public let type: String?
    public let likesCount: Int?
    public let status: String?
    public let files: [UserPublicationFiles]?
}

public struct UserPublicationFiles: Decodable {
    public let order: Int?
    public let fileName: String?
    public let fullUrl: String?
    public let fileUuid: String?
    public let extensionType: String?
    public let description: String?

    private enum CodingKeys: String, CodingKey {
        case order, fileName, fullUrl, fileUuid, description
        case extensionType = "extension"
    }
}

public struct DeletePublicationResponse: Decodable {
    public let message: String?
    public let data: String?
    public let errors: [String]?
}