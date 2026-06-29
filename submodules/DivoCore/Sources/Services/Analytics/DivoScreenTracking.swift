import UIKit
import ObjectiveC

/// Трекинг показа экранов (screen_view) с человеческими именами.
///
/// Авто-репортинг Firebase отключён через Info.plist (`FirebaseAutomaticScreenReportingEnabled = NO`),
/// иначе в Google Analytics летели бы технические имена классов (TabBarControllerImpl и т.п.).
/// Единственный источник screen_view — свизл `viewDidAppear(_:)` ниже. Работает по whitelist:
/// трекаем только экраны из карты `names` с человеческим именем, всё незнакомое (контейнеры,
/// оверлеи, системные/телеграмные контроллеры) — пропускаем, чтобы в отчёте не было мусора.
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

    static func track(_ viewController: UIViewController) {
        let className = String(describing: type(of: viewController))
        guard let name = names[className] else { return }
        divoTrackScreen(name)
    }
}
