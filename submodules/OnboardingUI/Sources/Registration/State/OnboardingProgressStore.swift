import Foundation

/// Сохраняет/восстанавливает `OnboardingRegistrationState` между запусками приложения.
///
/// На каждом forward/back/мутации coordinator вызывает `save()`. При входе в онбординг
/// coordinator зовёт `load()` — если есть незавершённый прогресс, продолжаем с него.
///
/// Тестовый запуск из настроек обходит `load()` через `forceFresh: true` — для разработки
/// обычно не хочется возобновлять прошлый прогон.
public final class OnboardingProgressStore {

    private static let key = "DivoOnboarding.registrationProgress.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> OnboardingRegistrationState? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        do {
            return try JSONDecoder().decode(OnboardingRegistrationState.self, from: data)
        } catch {
            // Кривой формат после миграции — затираем и начинаем чисто.
            defaults.removeObject(forKey: Self.key)
            return nil
        }
    }

    public func save(_ state: OnboardingRegistrationState) {
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: Self.key)
        } catch {
            // Не критично — в худшем случае юзер пройдёт онбординг ещё раз.
        }
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }

    public var hasSavedProgress: Bool {
        return defaults.data(forKey: Self.key) != nil
    }
}
