import Foundation

/// DIVI-103: подписка (follow) на человека должна заводить его в контакты Telegram. Все экраны
/// follow-а (профиль/лента/поиск) постят `divoFollowStateChanged` — ловим их в одной точке и ставим
/// best-effort op в очередь. Реальное добавление контакта делает executor очереди, когда поднят
/// авторизованный teamgram-контекст (см. AppDelegate+DivoOnboarding). На unfollow контакт не трогаем.
public final class DivoFollowContactSync {
    public static let shared = DivoFollowContactSync()

    private var observer: NSObjectProtocol?

    private init() {}

    public func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: DivoConfig.divoFollowStateChanged, object: nil, queue: nil
        ) { note in
            guard let userId = note.userInfo?["userId"] as? Int,
                  let isFollowed = note.userInfo?["isFollowed"] as? Bool, isFollowed else { return }
            PendingTelegramOpsQueue.shared.enqueue(.addContact(divoUserId: userId))
        }
    }
}
