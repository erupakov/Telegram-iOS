import Foundation

public final class CDNURLHelper {
    private static let oldBaseURL = "https://divostorage.s3.eu-central-1.amazonaws.com"
    private static let newBaseURL = "https://cdn.divo.global"

    /// Преобразует старый S3 URL в новый CDN URL
    /// - Parameter urlString: Исходный URL
    /// - Returns: URL с заменённым базовым адресом
    public static func convertToCDN(_ urlString: String?) -> String? {
        guard let urlString = urlString else { return nil }

        // Если URL уже содержит новый домен, возвращаем как есть
        if urlString.contains(newBaseURL) {
            return urlString
        }

        // Заменяем старый домен на новый
        return urlString.replacingOccurrences(of: oldBaseURL, with: newBaseURL)
    }

    /// Преобразует URL в CDN URL и возвращает как URL
    /// - Parameter urlString: Исходный URL
    /// - Returns: URL объект с заменённым адресом
    public static func convertToCDNURL(_ urlString: String?) -> URL? {
        guard let convertedString = convertToCDN(urlString) else { return nil }
        return URL(string: convertedString)
    }
}

