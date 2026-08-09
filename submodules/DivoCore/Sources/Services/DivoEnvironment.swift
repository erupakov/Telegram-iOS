import Foundation

/// Целевое окружение сборки: stage (отладка) или prod (боевое). Значение вшивается в `Info.plist`
/// ключом `DivoEnvironment` на этапе сборки (флаг `--define=divoEnv=prod`, см. `Telegram/BUILD`).
/// Дефолт — stage: если ключа нет (забыли флаг / плист расширения без ключа), уходим на отладочный
/// контур, а не на боевой — безопаснее ошибиться в сторону stage.
public enum DivoEnvironment: String {
    case stage
    case prod

    /// Единственный резолвер «какое я окружение». Конкретные значения (REST-URL, teamgram-IP,
    /// Firebase) живут у своих потребителей и берут env отсюда. `Network.swift` (TelegramCore,
    /// не импортит DivoCore) читает тот же ключ из `Bundle.main` напрямую — держать логику в синхроне.
    public static var current: DivoEnvironment {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "DivoEnvironment") as? String,
              let env = DivoEnvironment(rawValue: raw) else {
            return .stage
        }
        return env
    }

    public var isProduction: Bool {
        return self == .prod
    }
}
