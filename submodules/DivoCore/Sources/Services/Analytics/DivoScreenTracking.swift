import UIKit
import ObjectiveC

/// Трекинг показа экранов (screen_view) с человеческими именами.
///
/// Авто-репортинг Firebase отключён через Info.plist (`FirebaseAutomaticScreenReportingEnabled = NO`),
/// иначе в Google Analytics летели бы технические имена классов (TabBarControllerImpl и т.п.).
/// Единственный источник screen_view — свизл `viewDidAppear(_:)` ниже: для экранов из карты
/// шлём человеческое имя, для остальных — имя класса (fallback, полное покрытие). Контейнеры,
/// системные и дебаг-контроллеры не трекаем.
public enum DivoScreenTracking {
    private static var installed = false

    /// Вызывается один раз на старте (из DivoFirebaseBootstrap). Идемпотентно.
    public static func install() {
        guard !installed else { return }
        installed = true

        guard let original = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewDidAppear(_:))),
              let swizzled = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.divo_viewDidAppear(_:))) else {
            divoLog("DivoScreenTracking.install — не нашёл методы для свизла", level: .error)
            return
        }
        method_exchangeImplementations(original, swizzled)
    }
}

private extension UIViewController {
    @objc func divo_viewDidAppear(_ animated: Bool) {
        // После обмена реализациями этот вызов уходит в оригинальный viewDidAppear.
        self.divo_viewDidAppear(animated)
        DivoScreenNames.track(self)
    }
}

enum DivoScreenNames {
    /// Имя класса контроллера → человеческое имя для аналитики.
    /// Нет в карте → берётся имя класса (вариант C: переименованные + дефолт для остальных).
    static let names: [String: String] = [
        // ModelsFeedUI
        "ModelsFeedController": "Лента моделей",
        "ModelsSearchController": "Поиск моделей",
        "SearchFilterController": "Фильтры поиска",
        // ProfileScreenUI
        "PublicProfileScreenController": "Профиль",
        "EditProfileController": "Редактирование профиля",
        "EditSocialLinksController": "Соцсети профиля",
        "WorkExperienceController": "Опыт работы",
        "AddWorkExperienceController": "Добавление опыта работы",
        "EditMenuViewController": "Меню редактирования профиля",
        "InteractionListViewController": "Лайки / Закладки / Подписки",
        "AddRosterModelController": "Добавление модели в ростер",
        "RosterApplyConfirmationController": "Подтверждение добавления модели",
        // OnboardingUI
        "OnboardingFormStepViewController": "Онбординг — форма",
        "OnboardingQuizViewController": "Онбординг — квиз",
        "OnboardingRoleResultViewController": "Онбординг — роль",
        "OnboardingSubmitViewController": "Онбординг — отправка",
        // DivoAuthUI / AuthorizationUI
        "DivoAuthWelcomeController": "Приветствие / Вход",
        "AuthorizationSequencePhoneEntryController": "Ввод телефона",
        // EventsUI
        "EventsController": "Список ивентов",
        "EventDetailController": "Детали ивента",
        "CreateEventController": "Создание / редактирование ивента",
        "EventApplyConfirmationController": "Подтверждение заявки",
        "ApplicationsListController": "Заявки на ивент",
        "EventsSearchController": "Поиск ивентов",
        "EventPublishedSuccessController": "Ивент опубликован",
        // FaceSearchUI
        "FaceSearchController": "Распознавание лиц",
        "FaceSearchResultsController": "Похожие профили",
        "FaceSearchHistoryController": "История поиска по лицу",
        // DivoUIKit
        "FilterOptionsController": "Фильтр — список",
        "RangeFilterController": "Фильтр — диапазон",
        "CitySearchController": "Выбор города",
        // DivoSettingsUI
        "DivoSettingsController": "Настройки",
        "DivoLanguagePickerController": "Выбор языка",
        "EditParametersController": "Параметры",
        "SetNameController": "Имя пользователя",
        // DivoGallery
        "ProfileGalleryController": "Галерея",
        // TelegramUI
        "ChatControllerImpl": "Чат"
    ]

    /// Контейнеры/служебное/дебаг — не трекаем вовсе.
    static let excluded: Set<String> = [
        "TabBarControllerImpl",
        "DebugMenuController",
        "DivoStandaloneLogsViewController"
    ]

    static func track(_ viewController: UIViewController) {
        // Контейнеры и системные алерты — не экраны.
        if viewController is UINavigationController
            || viewController is UITabBarController
            || viewController is UIAlertController {
            return
        }
        let className = String(describing: type(of: viewController))
        // UIKit-внутренние / приватные системные контроллеры.
        if className.hasPrefix("UI") || className.hasPrefix("_") {
            return
        }
        if excluded.contains(className) {
            return
        }
        divoTrackScreen(names[className] ?? className)
    }
}
