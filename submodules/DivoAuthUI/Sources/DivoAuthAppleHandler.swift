import UIKit
import DivoCore
import DivoAuth

public enum DivoAuthAppleHandler {
    @MainActor
    public static func signIn(from controller: DivoAuthWelcomeController?) async -> DivoAuthOutcome? {
        guard DivoNetworkMonitor.shared.isConnected else {
            divoLog("Apple sign-in skipped: no internet", level: .info)
            controller?.showError(message: DivoStrings.noInternetConnection)
            return nil
        }

        // Ставим до показа шторки Apple — к её закрытию лоадер уже на месте, велком не мелькает.
        // Снимется при ошибке/отмене; при успехе сменится лоадером headless-флоу.
        controller?.showAuthLoading()
        let anchor = controller?.view.window
        do {
            let result = try await FirebaseAuthClient.shared.signInWithApple(presentingFrom: anchor)
            divoLog("Apple sign-in OK: uid=\(result.uid) email=\(result.email ?? "nil")", level: .info)
            let outcome = await AuthRestRouter.route(firebaseUid: result.uid, providerId: result.providerId)
            DivoAuthOutcomePresenter.present(outcome, on: controller, displayName: result.displayName, photoUrl: result.photoUrl)
            return outcome
        } catch DivoFirebaseAuthError.userCancelled {
            divoLog("Apple sign-in cancelled by user", level: .debug)
            controller?.hideAuthLoading()
            return nil
        } catch {
            divoLog("Apple sign-in failed: \(error)", level: .error)
            if !DivoNetworkMonitor.shared.isConnected {
                controller?.showError(message: DivoStrings.noInternetConnection)
            } else {
                let message = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.authSignInFailed
                controller?.showError(message: message)
            }
            return nil
        }
    }
}
