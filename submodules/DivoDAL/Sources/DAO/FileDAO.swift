import Foundation

/// Data Access Object for File endpoints (openapi tag: File).
public final class FileDAO {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// POST /file/upload-file — Upload single file (multipart). No auth required.
    public func uploadFile(multipart: MultipartForm) async throws -> Data {
        return try await client.upload(path: APIPath.fileUploadFile, method: HTTPMethod.post.rawValue, multipart: multipart)
    }

    /// POST /file/upload-files — Upload multiple files (multipart). No auth required.
    public func uploadFiles(multipart: MultipartForm) async throws -> Data {
        return try await client.upload(path: APIPath.fileUploadFiles, method: HTTPMethod.post.rawValue, multipart: multipart)
    }

    /// GET /file/resize — Resize image. No auth required.
    public func resize(url: String? = nil, width: Int? = nil, height: Int? = nil) async throws -> Data {
        var query: [String: String] = [:]
        if let url = url { query["url"] = url }
        if let width = width { query["width"] = String(width) }
        if let height = height { query["height"] = String(height) }
        return try await client.requestRaw(path: APIPath.fileResize, method: HTTPMethod.get.rawValue, query: query.isEmpty ? nil : query)
    }
}
