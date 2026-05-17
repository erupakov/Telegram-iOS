import Foundation
import DivoCore

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
        guard let data = defaults.data(forKey: Self.key) else {
            divoLog("OnboardingProgressStore.load: no saved data", level: .debug)
            return nil
        }
        do {
            let state = try JSONDecoder().decode(OnboardingRegistrationState.self, from: data)
            divoLog("OnboardingProgressStore.load: restored at \(state.currentStep), \(state.formValues.values.reduce(0) { $0 + $1.count }) field values", level: .info)
            return state
        } catch {
            divoLog("OnboardingProgressStore.load: decode failed (\(error)) — clearing", level: .warning)
            defaults.removeObject(forKey: Self.key)
            return nil
        }
    }

    public func save(_ state: OnboardingRegistrationState) {
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: Self.key)
        } catch {
            divoLog("OnboardingProgressStore.save: encode failed — \(error)", level: .error)
        }
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
        divoLog("OnboardingProgressStore.clear: wiped saved progress", level: .info)
    }

    public var hasSavedProgress: Bool {
        return defaults.data(forKey: Self.key) != nil
    }
}
