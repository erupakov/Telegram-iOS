import UIKit
import DivoCore

/// Данные из соц-провайдера (Google/Apple) для префилла онбординга. Любое поле может быть nil:
/// Apple не отдаёт фото, имя приходит только при первом входе. Дата рождения провайдерами не
/// предоставляется — поэтому её здесь нет (юзер заполняет сам).
public struct OnboardingSocialPrefill {
    public let firstName: String?
    public let lastName: String?
    public let photoUrl: String?

    public init(firstName: String?, lastName: String?, photoUrl: String?) {
        self.firstName = firstName
        self.lastName = lastName
        self.photoUrl = photoUrl
    }

    /// Строит префилл из соц-провайдерских данных: `displayName` режется на first/last по пробелам.
    /// Возвращает `nil`, если префиллить нечего (ни имени, ни фото) — чтобы не таскать пустой объект.
    public init?(displayName: String?, photoUrl: String?) {
        let trimmed = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let first = parts.first
        let last = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : nil
        if first == nil, (photoUrl ?? "").isEmpty { return nil }
        self.init(firstName: first, lastName: last, photoUrl: photoUrl)
    }
}

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
    ///   - prefill: данные из соц-провайдера (имя/фото) для предзаполнения формы. `nil` для phone-флоу.
    ///   - onFinish: вызывается когда онбординг завершён (`true` — успех submit'а, `false` — закрытие крестиком).
    public static func makeController(
        forceFresh: Bool,
        submitService: OnboardingSubmitService = MockOnboardingSubmitService(),
        prefill: OnboardingSocialPrefill? = nil,
        onFinish: @escaping (Bool) -> Void
    ) -> UIViewController {
        // Удерживаем coordinator через associated object на VC: пока VC жив — жив coordinator.
        let coordinator = OnboardingRegistrationCoordinator(
            submitService: submitService,
            forceFresh: forceFresh,
            socialPrefill: prefill,
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
