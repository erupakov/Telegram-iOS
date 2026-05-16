import UIKit
import DivoCore

/// Публичная точка входа в регистрационный онбординг.
///
/// Вызывающая сторона (Settings/Auth flow) получает готовый `UIViewController` —
/// этот контроллер можно сразу `present(...)` модально или встроить в свой стек.
/// Coordinator живёт всё время жизни этого контроллера.
public enum OnboardingRegistrationEntry {

    /// Создаёт корневой UI онбординга с подключённым coordinator.
    /// - Parameters:
    ///   - forceFresh: `true` — стираем сохранённый прогресс и стартуем с самого начала.
    ///     Тестовый запуск из DIVO Settings всегда `true`, реальный пост-авторизационный
    ///     флоу — обычно `false` (продолжаем незавершённый прогон).
    ///   - submitService: мок или реальный сабмит-сервис. По умолчанию — `MockOnboardingSubmitService`.
    ///   - onFinish: вызывается когда онбординг завершён (`true` — успех submit'а, `false` — закрытие крестиком).
    public static func makeController(
        forceFresh: Bool,
        submitService: OnboardingSubmitService = MockOnboardingSubmitService(),
        onFinish: @escaping (Bool) -> Void
    ) -> UIViewController {
        // Удерживаем coordinator через associated object на VC: пока VC жив — жив coordinator.
        let coordinator = OnboardingRegistrationCoordinator(
            submitService: submitService,
            forceFresh: forceFresh,
            onFinish: onFinish
        )
        let nav = coordinator.navigationController
        objc_setAssociatedObject(nav, &CoordinatorAOKey.key, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return nav
    }
}

private enum CoordinatorAOKey {
    static var key: UInt8 = 0
}
