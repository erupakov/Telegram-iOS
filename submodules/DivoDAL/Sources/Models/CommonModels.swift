import Foundation

/// API error payload from Divo backend (OpenAPI Error schema: message, errors).
public struct DivoAPIErrorPayload {
    public let message: String?
    public let errors: [String: Any]?

    public init(message: String?, errors: [String: Any]?) {
        self.message = message
        self.errors = errors
    }

    static func parse(from data: Data) -> DivoAPIErrorPayload? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let message = json["message"] as? String
        let errors = json["errors"] as? [String: Any]
        return DivoAPIErrorPayload(message: message, errors: errors)
    }
}

/// Typed errors for Divo API responses.
public enum DivoAPIError: Error {
    case unauthorized
    case forbidden
    case validation(message: String?, errors: [String: Any]?)
    case serverError(statusCode: Int)
    case decoding(Error)
    case network(Error)
}
