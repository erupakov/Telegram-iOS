import Foundation

/// Data Access Object for Follower endpoints (openapi tag: Follower).
public final class FollowerDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /follower/follow
    public func follow(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.followerFollow, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /follower/unfollow
    public func unfollow(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.followerUnfollow, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /follower/following
    public func following(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.followerFollowing, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /follower/followers
    public func followers(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.followerFollowers, method: HTTPMethod.post.rawValue, body: body)
    }
}
