import Foundation

/// Публичный DIVO-профиль, привязанный к Telegram-пользователю.
public struct DivoPublicProfileInfo {
    public let userId: Int
    public let fullName: String

    public init(userId: Int, fullName: String) {
        self.userId = userId
        self.fullName = fullName
    }
}

/// Резолвит публичный DIVO-профиль по Telegram-id пира (`GET /user/by-telegram`).
/// nil — если у пользователя нет привязанного DIVO-профиля (бэк отдаёт 4xx): это штатный
/// случай для не-DIVO контактов, а не ошибка, поэтому наружу его не показываем.
public func resolveDivoPublicProfile(telegramId: Int64) async -> DivoPublicProfileInfo? {
    do {
        let response: UserDetailResponse = try await DivoAPIClient.shared.request(
            path: "/user/by-telegram?telegramId=\(telegramId)"
        )
        guard let fullName = response.data.fullName, !fullName.isEmpty else {
            return nil
        }
        return DivoPublicProfileInfo(userId: response.data.id, fullName: fullName)
    } catch {
        divoLog("resolveDivoPublicProfile(\(telegramId)) failed: \(error)")
        return nil
    }
}
