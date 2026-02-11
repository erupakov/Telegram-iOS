import Foundation

/// Data Access Object for Messenger endpoints (openapi tag: Messenger).
public final class MessengerDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /messenger/threads/{thread}/pin-message
    public func pinMessage(thread: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerThreadPinMessage(thread: thread), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/threads/{thread}/unpin-message
    public func unpinMessage(thread: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerThreadUnpinMessage(thread: thread), method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /messenger/threads/{thread}/pinned
    public func pinned(thread: Int) async throws -> Data {
        return try await client.requestRaw(path: APIPath.messengerThreadPinned(thread: thread), method: HTTPMethod.get.rawValue)
    }

    /// GET /messenger/threads/{thread}/search/{query}
    public func threadSearch(thread: Int, query: String) async throws -> Data {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        return try await client.requestRaw(path: "/messenger/threads/\(thread)/search/\(encoded)", method: HTTPMethod.get.rawValue)
    }

    /// POST /messenger/threads/{thread}/messages/token
    public func messagesToken(thread: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerThreadMessagesToken(thread: thread), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/threads/{thread}/messages/phone
    public func messagesPhone(thread: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerThreadMessagesPhone(thread: thread), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/threads/{thread}/messages
    public func messages(thread: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerThreadMessages(thread: thread), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/threads/{thread}/images
    public func images(thread: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerThreadImages(thread: thread), method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/threads/{thread}/documents
    public func documents(thread: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerThreadDocuments(thread: thread), method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /messenger/threads-search/{query}
    public func threadsSearch(query: String) async throws -> Data {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        return try await client.requestRaw(path: "/messenger/threads-search/\(encoded)", method: HTTPMethod.get.rawValue)
    }

    /// POST /messenger/start-dialog
    public func startDialog(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerStartDialog, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/start-system-dialog
    public func startSystemDialog(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerStartSystemDialog, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/block-user
    public func blockUser(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerBlockUser, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/unblock-user
    public func unblockUser(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerUnblockUser, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/block/{recipientId}
    public func block(recipientId: Int, body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerBlock(recipientId: recipientId), method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /messenger/get-users-for-messenging
    public func getUsersForMessenging() async throws -> Data {
        return try await client.requestRaw(path: APIPath.messengerGetUsersForMessenging, method: HTTPMethod.get.rawValue)
    }

    /// POST /messenger/thread-leave/{thread}
    public func threadLeave(thread: Int) async throws -> Data {
        return try await client.requestRaw(path: APIPath.messengerThreadLeave(thread: thread), method: HTTPMethod.post.rawValue)
    }

    /// POST /messenger/privates/token
    public func privatesToken(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerPrivatesToken, method: HTTPMethod.post.rawValue, body: body)
    }

    /// POST /messenger/privates/phone
    public func privatesPhone(body: [String: Any]?) async throws -> Data {
        return try await client.requestJSON(path: APIPath.messengerPrivatesPhone, method: HTTPMethod.post.rawValue, body: body)
    }

    /// GET /messenger/friends
    public func friends() async throws -> Data {
        return try await client.requestRaw(path: APIPath.messengerFriends, method: HTTPMethod.get.rawValue)
    }
}
