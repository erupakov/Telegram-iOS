import Foundation

/// DIVO: best-effort синхронизация авы в teamgram-контур (источник правды — DIVO REST, teamgram
/// вторичен). Кладёт `.photoUpdate` в `PendingTelegramOpsQueue`. Зеркалит [[DivoTeamgramName]].
public enum DivoTeamgramPhoto {
    /// Звать после успешного REST-сохранения авы либо на reconcile при пустой teamgram-аве.
    public static func syncToTeamgram() {
        PendingTelegramOpsQueue.shared.enqueue(.photoUpdate)
    }

    /// Байты авы для заливки: avatar → photo → agency.photo, качает с CDN (публичный, без токена).
    public static func resolveAvatarForSync() async throws -> Data? {
        let detail = try await AuthRestService.shared.userDetail()
        guard let file = detail.avatar ?? detail.photo ?? detail.agency?.photo,
              let rawUrl = file.fullUrl, !rawUrl.isEmpty,
              let url = CDNURLHelper.convertToCDNURL(rawUrl) else {
            divoLog("[ava] resolveAvatarForSync: авы в REST-профиле нет", level: .info)
            return nil
        }
        divoLog("[ava] resolveAvatarForSync: качаю аву \(url.absoluteString)", level: .info)
        let (data, _) = try await URLSession.shared.data(from: url)
        divoLog("[ava] resolveAvatarForSync: скачано \(data.count) байт", level: .info)
        return data
    }
}
