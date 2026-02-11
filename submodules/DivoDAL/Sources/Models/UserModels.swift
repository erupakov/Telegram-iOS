import Foundation

/// Placeholder for /user/info and /user/{id} response. Refine when backend schema is fixed.
public struct UserInfo: Codable {
    public let id: Int?
    public let email: String?
    // Add other fields as API contract is defined.
}
