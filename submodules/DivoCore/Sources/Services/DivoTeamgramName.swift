import Foundation

/// DIVO: best-effort синхронизация отображаемого имени в teamgram-контур. Источник правды — DIVO
/// (REST), teamgram-имя вторично (показывается в чатах). Кладёт `.nameUpdate` в персистентную
/// очередь `PendingTelegramOpsQueue`: она сразу пытается обновить имя через MTProto, а при сбое
/// (нет сети / транзиент) докатывает операцию на следующем старте. Вызывать ТОЛЬКО после успешного
/// REST-сохранения имени в DIVO.
public enum DivoTeamgramName {
    /// Имя и фамилия пришли уже раздельными (экран редактирования с двумя полями) — шлём в teamgram
    /// как есть, без угадывания границы слов.
    public static func syncToTeamgram(firstName: String, lastName: String) {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty else { return }
        PendingTelegramOpsQueue.shared.enqueue(.nameUpdate(firstName: first, lastName: last))
    }

    public static func syncToTeamgram(fullName: String?) {
        let parts = split(fullName: fullName ?? "")
        guard !parts.firstName.isEmpty else { return }
        PendingTelegramOpsQueue.shared.enqueue(.nameUpdate(firstName: parts.firstName, lastName: parts.lastName))
    }

    /// Разбить единое DIVO `fullName` на имя/фамилию: первое слово — имя, остаток — фамилия. teamgram
    /// хранит имя двумя полями, DIVO — одной строкой; точка разбиения при >2 словах условная (на
    /// отображение в чатах не влияет — имя склеивается обратно). Используется и для prefill DIVO-экрана.
    public static func split(fullName: String) -> (firstName: String, lastName: String) {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let first = parts.first ?? trimmed
        let last = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
        return (first, last)
    }

    /// Reconcile при старте authorized-контекста (зеркалит [[DivoTeamgramPhoto]]): DIVO — источник
    /// правды, teamgram-имя вторично. Если текущее teamgram-имя разошлось с DIVO — досылаем DIVO-имя.
    /// teamgram-имя читает вызывающий (postbox, есть только в TelegramUI), DIVO — тянем из REST.
    public static func reconcileToTeamgram(teamgramFirstName: String, teamgramLastName: String) async {
        guard let detail = try? await AuthRestService.shared.userDetail() else {
            divoLog("[name] reconcile: /user/info недоступен — пропускаю", level: .info)
            return
        }
        let full = (detail.fullName ?? detail.agency?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !full.isEmpty else { return }
        let tgJoined = [teamgramFirstName, teamgramLastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard tgJoined != full else {
            divoLog("[name] reconcile: teamgram-имя уже = DIVO", level: .info)
            return
        }
        divoLog("[name] reconcile: teamgram='\(tgJoined)' ≠ DIVO='\(full)' → досылаю DIVO-имя", level: .info)
        syncToTeamgram(fullName: full)
    }
}
