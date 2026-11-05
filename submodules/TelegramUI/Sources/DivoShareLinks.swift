import Foundation
import Display
import AccountContext
import DivoCore
import ProfileScreenUI
import EventsUI

/// Экран для DIVO-ссылки «Поделиться»: https://api.divo.fashion/profile/{id} или /event/{id}
/// (а также divo.fashion). nil — ссылка не DIVO-шная, открывается как обычно.
/// `tabIndex` — вкладка, к которой относится экран (для открытия извне приложения).
func divoShareLinkTarget(context: AccountContext, url: URL) -> (tabIndex: Int, controller: ViewController)? {
    guard let host = url.host?.lowercased(),
          host == DivoConfig.shareHost.lowercased() || host == "divo.fashion" || host == "www.divo.fashion" else {
        return nil
    }

    let pathComponents = url.pathComponents.filter { $0 != "/" }
    guard pathComponents.count == 2, let id = Int(pathComponents[1]) else {
        return nil
    }

    switch pathComponents[0].lowercased() {
    case "profile":
        return (0, PublicProfileScreenController(context: context, model: ProfileModel(userId: id)))
    case "event":
        return (1, EventDetailController(context: context, eventId: id))
    default:
        return nil
    }
}
