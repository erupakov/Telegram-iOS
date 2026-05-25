import Foundation
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import DivoCore
import TelegramPresentationData
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramNotices

// DIVO: auto-signUp flow без экрана ввода имени.
//
// По дизайну DIVO на этапе регистрации нет шага «введите имя», поэтому при попадании
// в state .signUp мы автоматически дёргаем auth.signUp с placeholder firstName="User".
// Когда Eugene реализует empty-Divo endpoint (P1.5/1.6 плана) — переключимся на нормальный flow.
//
// Файл живёт отдельно, чтобы минимизировать конфликты при merge upstream:
// в AuthorizationSequenceController.swift остаётся только однострочный вызов в case .signUp.
extension AuthorizationSequenceController {
    func divoHandleAutoSignUp(firstName: String, lastName: String) {
        // Пушим splashController в стек, чтобы DivoSplashOverlayView получил сигнал ready
        // и dismiss'ился — иначе юзер видит зависший splash, пока signUp летит на сервер.
        var controllers: [ViewController] = []
        if !self.otherAccountPhoneNumbers.1.isEmpty {
            controllers.append(self.splashController())
        }
        controllers.append(self.splashController())
        self.setViewControllers(controllers, animated: !self.viewControllers.isEmpty)

        let effectiveFirstName = firstName.isEmpty ? "User" : firstName
        self.actionDisposable.set((signUpWithName(
            accountManager: self.sharedContext.accountManager,
            account: self.account,
            firstName: effectiveFirstName,
            lastName: lastName,
            avatarData: nil,
            avatarVideo: nil,
            videoStartTimestamp: nil,
            disableJoinNotifications: false,
            forcedPasswordSetupNotice: { value in
                guard let entry = CodableEntry(ApplicationSpecificCounterNotice(value: value)) else { return nil }
                return (ApplicationSpecificNotice.forcedPasswordSetupKey(), entry)
            }
        ) |> deliverOnMainQueue).startStrict(error: { [weak self] error in
            Queue.mainQueue().async {
                guard let strongSelf = self else { return }
                divoLog("[Auth UI] signUp auto-flow error: \(error)", level: .error)

                let text: String
                switch error {
                case .limitExceeded:
                    text = strongSelf.presentationData.strings.Login_CodeFloodError
                case .codeExpired:
                    text = strongSelf.presentationData.strings.Login_CodeExpiredError
                case .invalidFirstName:
                    text = strongSelf.presentationData.strings.Login_InvalidFirstNameError
                case .invalidLastName:
                    text = strongSelf.presentationData.strings.Login_InvalidLastNameError
                case .generic:
                    text = strongSelf.presentationData.strings.Login_UnknownError
                }

                // Сбрасываем state в .empty — иначе постбокс сохранит просроченный codeHash,
                // и при следующем cold start приложение опять зациклится на signUp.
                let account = strongSelf.account
                let _ = strongSelf.engine.auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty)).startStandalone()

                strongSelf.currentWindow?.present(
                    textAlertController(sharedContext: strongSelf.sharedContext, title: nil, text: text, actions: [
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})
                    ]),
                    on: .root,
                    blockInteraction: false,
                    completion: {}
                )
            }
        }))
    }
}
