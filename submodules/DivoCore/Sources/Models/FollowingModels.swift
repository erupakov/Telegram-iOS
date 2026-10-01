import Foundation

public struct FollowingListRequest: Encodable {
    public let offset: Int
    public let limit: Int

    public init(offset: Int, limit: Int) {
        self.offset = offset
        self.limit = limit
    }
}

public struct FollowingResponse: Decodable {
    public let message: String?
    public let data: FollowingData
}

public struct FollowingData: Decodable {
    public let items: [FollowingUser]
}

/// Профиль в списке подписок (`POST /follower/following`). `roleLabel` уже локализован
/// сервером по `Accept-Language`. Аватар приходит в `avatar` (кроп 288×288); если его нет —
/// падаем на `photo` (полноразмерное фото профиля).
public struct FollowingUser: Decodable {
    public let id: Int
    public let fullName: String?
    public let role: String
    public let roleLabel: String
    public let avatar: FollowingPhoto?
    public let photo: FollowingPhoto?

    public var avatarURLString: String? {
        return avatar?.fullUrl ?? photo?.fullUrl
    }
}

public struct FollowingPhoto: Decodable {
    public let fullUrl: String?
}
