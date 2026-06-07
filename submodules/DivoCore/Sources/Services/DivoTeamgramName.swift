import Foundation

/// DIVO: best-effort синхронизация отображаемого имени в teamgram-контур. Источник правды — DIVO
/// (REST), teamgram-имя вторично (показывается в чатах). Кладёт `.nameUpdate` в персистентную
/// очередь `PendingTelegramOpsQueue`: она сразу пытается обновить имя через MTProto, а при сбое
/// (нет сети / транзиент) докатывает операцию на следующем старте. Вызывать ТОЛЬКО после успешного
/// REST-сохранения имени в DIVO.
public enum DivoTeamgramName {
    public static func syncToTeamgram(fullName: String?) {
        let trimmed = (fullName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // teamgram-аккаунт хранит имя двумя полями (first/last), у DIVO одно `fullName` — режем по
        // пробелам: первое слово в firstName, остаток в lastName (на отображение в чатах не влияет —
        // имя склеивается обратно).
        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let firstName = parts.first ?? trimmed
        let lastName = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
        PendingTelegramOpsQueue.shared.enqueue(.nameUpdate(firstName: firstName, lastName: lastName))
    }
}
