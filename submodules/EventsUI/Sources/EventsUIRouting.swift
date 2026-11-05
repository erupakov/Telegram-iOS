import Foundation
import Display
import AccountContext

/// Переходы из EventsUI на экраны модулей, которые сами зависят от EventsUI (ProfileScreenUI
/// импортирует EventsUI, поэтому напрямую создать профиль отсюда нельзя). Фабрики регистрирует
/// TelegramUI при сборке корневого контроллера.
public enum EventsUIRouting {
    /// Публичный профиль DIVO-пользователя по его DIVO userId.
    public static var makeUserProfileController: ((AccountContext, Int) -> ViewController)?
}
