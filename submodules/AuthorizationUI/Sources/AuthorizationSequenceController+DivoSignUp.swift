import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import DivoCore
import DivoUIKit
import TelegramPresentationData
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramNotices

// DIVO: лоадинг-экран на время серверного auth-шага (signUpWithName / headless signIn).
// Апстрим в этот момент держит видимый экран с прогрессом на кнопке; мы экраны ввода имени/кода
// убрали, поэтому вместо пустого splash-stub показываем светлый экран со спиннером — иначе у
// юзера несколько секунд висит пустой серый/белый экран перед таббаром.
// `internal` (не private): переиспользуется из +DivoHeadlessAuth.swift.
final class DivoSignUpLoadingController: ViewController {
    private var activityIndicator: UIActivityIndicatorView?

    init() {
        super.init(navigationBarPresentationData: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = DivoColorPalette.screenBackground

        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = DivoColorPalette.primaryText
        indicator.startAnimating()
        self.displayNode.view.addSubview(indicator)
        self.activityIndicator = indicator

        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        if let indicator = self.activityIndicator {
            indicator.sizeToFit()
            let size = indicator.bounds.size
            indicator.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - size.width) / 2.0), y: floor((layout.size.height - size.height) / 2.0)), size: size)
        }
    }
}

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
        // Лоадинг-экран (светлый + спиннер) на время signUp. Он же сигналит ready стартовому
        // DivoSplashOverlayView (cold-start в signUp), и не оставляет пустого экрана в обычном флоу.
        var controllers: [ViewController] = []
        if !self.otherAccountPhoneNumbers.1.isEmpty {
            controllers.append(self.splashController())
        }
        controllers.append(DivoSignUpLoadingController())
        // DIVO: без анимации — бесшовная смена лоадера headless→signUp (оба DivoSignUpLoadingController),
        // без бокового слайда (см. divoHeadlessAuth). Иначе перед дверями мелькали экраны.
        self.setViewControllers(controllers, animated: false)

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
