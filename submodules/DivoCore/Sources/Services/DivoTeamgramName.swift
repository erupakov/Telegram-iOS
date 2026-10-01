import Foundation

/// DIVO: best-effort синхронизация отображаемого имени в teamgram-контур. Источник правды — DIVO
/// (REST), teamgram-имя вторично (показывается в чатах). Кладёт `.nameUpdate` в персистентную
/// очередь `PendingTelegramOpsQueue`: она сразу пытается обновить имя через MTProto, а при сбое
/// (нет сети / транзиент) докатывает операцию на следующем старте. Вызывать ТОЛЬКО после успешного
/// REST-сохранения имени в DIVO.
public enum DivoTeamgramName {
    /// Имя и фамилия пришли уже раздельными (экран редактирования с двумя полями) — шлём в teamgram
    /// как есть, без угадывания границы слов. Одновременно запоминаем два поля локально: teamgram и
    /// DIVO хранят имя по-разному (два поля vs одна строка), а reconcile при старте пере-режет DIVO
    /// fullName наивным split'ом — поэтому граница слов достоверно живёт только здесь. Экраны правки
    /// префиллят два поля из этого стора (см. [[localName]]).
    public static func syncToTeamgram(firstName: String, lastName: String) {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty else { return }
        storeLocalName(firstName: first, lastName: last)
        PendingTelegramOpsQueue.shared.enqueue(.nameUpdate(firstName: first, lastName: last))
    }

    private static let localFirstNameKey = "divo.selfName.first"
    private static let localLastNameKey = "divo.selfName.last"

    /// Запомнить последние введённые имя/фамилию (точная граница слов) для префилла экранов правки.
    public static func storeLocalName(firstName: String, lastName: String) {
        UserDefaults.standard.set(firstName, forKey: localFirstNameKey)
        UserDefaults.standard.set(lastName, forKey: localLastNameKey)
    }

    /// Локально сохранённые имя/фамилия (nil, если ещё не сохраняли на этом устройстве).
    public static func localName() -> (firstName: String, lastName: String)? {
        guard let first = UserDefaults.standard.string(forKey: localFirstNameKey) else { return nil }
        return (first, UserDefaults.standard.string(forKey: localLastNameKey) ?? "")
    }

    /// Снять локальное имя на логауте/сбросе сессии — иначе следующий аккаунт префиллит чужое имя.
    public static func clearLocalName() {
        UserDefaults.standard.removeObject(forKey: localFirstNameKey)
        UserDefaults.standard.removeObject(forKey: localLastNameKey)
    }

    /// Разбить единое DIVO `fullName` на имя/фамилию, но с приоритетом локально сохранённых двух полей:
    /// если их склейка совпадает с `fullName` — берём их (точная граница), иначе честный naive split
    /// актуального `fullName`. Используется для префилла экранов правки (EditProfile / SetName).
    public static func splitPreservingLocal(fullName: String) -> (firstName: String, lastName: String) {
        let full = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let local = localName() {
            let joined = [local.firstName, local.lastName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !local.firstName.isEmpty, joined == full {
                return (local.firstName, local.lastName)
            }
        }
        return split(fullName: full)
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
        // Без своей сессии `/user/info` отдаёт профиль fallback-токена — чужое имя в teamgram не шлём.
        guard DivoConfig.hasDivoSession else {
            divoLog("[name] reconcile: нет DIVO-сессии — пропускаю", level: .info)
            return
        }
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
