import UIKit
import DivoCore
import DivoAuth

public enum DivoAuthAppleHandler {
    @MainActor
    public static func signIn(from controller: DivoAuthWelcomeController?) async {
        guard DivoNetworkMonitor.shared.isConnected else {
            DivoConsoleLogger.shared.log("Apple sign-in skipped: no internet", level: .info)
            controller?.showError(message: DivoStrings.noInternetConnection)
            return
        }

        let anchor = controller?.view.window
        do {
            let result = try await FirebaseAuthClient.shared.signInWithApple(presentingFrom: anchor)
            DivoConsoleLogger.shared.log(
                "Apple sign-in OK: uid=\(result.uid) email=\(result.email ?? "nil")",
                level: .info
            )
        } catch DivoFirebaseAuthError.userCancelled {
            DivoConsoleLogger.shared.log("Apple sign-in cancelled by user", level: .debug)
        } catch {
            DivoConsoleLogger.shared.log("Apple sign-in failed: \(error)", level: .error)
            if !DivoNetworkMonitor.shared.isConnected {
                controller?.showError(message: DivoStrings.noInternetConnection)
            } else {
                controller?.showError(message: DivoStrings.authSignInFailed)
            }
        }
    }
}
