import Foundation
import DivoCore

public enum DivoAuthOutcome {
    case enteredApp
    case needsOnboarding(divoUserId: Int)
    case needsTelegramLink(divoUserId: Int, phone: String?)
    case failed(Error)
}

public final class AuthFlowCoordinator {
    public static let shared = AuthFlowCoordinator()

    private let rest = AuthRestService.shared
    private let firebase = FirebaseAuthClient.shared

    private init() {}

    public func runGoogleFlow() async -> DivoAuthOutcome {
        // Шаг 5: signInWithGoogle → loginSocial → router 4 веток
        DivoConsoleLogger.shared.log("AuthFlowCoordinator.runGoogleFlow — skeleton", level: .info)
        return .failed(DivoFirebaseAuthError.notConfigured)
    }

    public func runAppleFlow() async -> DivoAuthOutcome {
        // Шаг 5: signInWithApple → loginSocial → router 4 веток
        DivoConsoleLogger.shared.log("AuthFlowCoordinator.runAppleFlow — skeleton", level: .info)
        return .failed(DivoFirebaseAuthError.notConfigured)
    }

    public func runPhoneFlowAfterTelegramSignIn(telegramUserId: Int64, phone: String) async -> DivoAuthOutcome {
        // Шаг 5: telegramLink с phone → если нашёл существующего → enteredApp;
        //         если не нашёл → /api/auth/registration → telegramLink → enteredApp
        DivoConsoleLogger.shared.log("AuthFlowCoordinator.runPhoneFlow — skeleton (tgUid=\(telegramUserId), phone=\(phone))", level: .info)
        return .failed(DivoFirebaseAuthError.notConfigured)
    }
}
