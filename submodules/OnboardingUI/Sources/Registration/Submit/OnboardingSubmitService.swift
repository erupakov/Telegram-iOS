import Foundation
import DivoCore

/// Контракт submit-сервиса онбординга. Реальная реализация подключается, когда бэк
/// объявит финальный registration endpoint; пока используется `MockOnboardingSubmitService`.
public protocol OnboardingSubmitService: AnyObject {
    /// Отправляет финализированное состояние онбординга на бэк.
    /// Возвращает асинхронный результат; ошибка — Swift Error (на стороне UI оборачиваем
    /// в `DivoAPIError.userFacingMessage` при показе snackbar).
    func submit(state: OnboardingRegistrationState, registry: OnboardingRoleRegistry) async throws
}

/// Мок-реализация submit-сервиса. Логирует payload в `DivoConsoleLogger`,
/// после небольшой задержки возвращает успех. Чтобы проверить error-path,
/// поставь `failureProbability > 0` или используй `.alwaysFail`.
public final class MockOnboardingSubmitService: OnboardingSubmitService {

    public enum Mode {
        case alwaysSucceed
        case alwaysFail(MockError)
        case probabilistic(failureProbability: Double, error: MockError)
    }

    public struct MockError: Error, LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
    }

    private let mode: Mode
    private let delay: TimeInterval

    public init(mode: Mode = .alwaysSucceed, delay: TimeInterval = 1.0) {
        self.mode = mode
        self.delay = delay
    }

    public func submit(state: OnboardingRegistrationState, registry: OnboardingRoleRegistry) async throws {
        let json = FormSerializer.jsonString(state: state, registry: registry)
        divoLog("Onboarding submit (mock). Payload:\n\(json)", level: .info)

        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        switch mode {
        case .alwaysSucceed:
            divoLog("Onboarding submit (mock): success", level: .info)
            return
        case .alwaysFail(let err):
            divoLog("Onboarding submit (mock): failure — \(err.message)", level: .error)
            throw err
        case .probabilistic(let probability, let err):
            if Double.random(in: 0..<1) < probability {
                divoLog("Onboarding submit (mock): failure — \(err.message)", level: .error)
                throw err
            }
            divoLog("Onboarding submit (mock): success", level: .info)
        }
    }
}
