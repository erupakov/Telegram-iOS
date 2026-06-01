import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import DivoCore
import DivoAuthUI
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramNotices

// DIVO: headless teamgram-авторизация по УЖЕ известному телефону — без экранов ввода номера и кода.
//
// Применяется ветками после Firebase-входа:
//   A (reinstall)       → teamgram signIn по user/info.phone;
//   B (DIVO-1 миграция) → teamgram signUp по user/info.phone (+ telegram-link делает вызывающая сторона);
//   D (новый, signUp-часть) — тот же signUp по сгенерённому phone.
// Телефон известен, на teamgram-стенде код фиксированный (PIN 12345), поэтому весь flow проводим
// программно: юзер не видит ни номера, ни ввода кода — только светлый лоадинг.
//
// Композиция уже ПУБЛИЧНЫХ функций TelegramCore (ноль правок upstream Authorization.swift):
//   sendAuthorizationCode → authorizeWithCode(.phoneCode("12345"))
//     ├─ .loggedIn     → switchToAuthorizedAccount внутри → app выходит из auth (ветка A)
//     └─ .signUp(data) → beginSignUp → signUpWithName("User","")            (ветки B/D)
// Успех не требует ручного authorizationCompleted: switchToAuthorizedAccount сам переключает
// аккаунт в accountManager, и приложение выходит из auth (как divoHandleAutoSignUp).
//
// Файл отдельный — минимизируем конфликты при merge upstream (как +DivoSignUp).

private enum DivoHeadlessAuthError {
    case sendCode(AuthorizationCodeRequestError)
    case verify(AuthorizationCodeVerificationError)
    case signUp(SignUpError)
}

extension AuthorizationSequenceController {
    private static let divoTeamgramPin = "12345"

    /// Headless teamgram-вход по известному телефону. На стенде код фиксированный (PIN 12345).
    /// По завершении аккаунт переключается на авторизованный внутри TelegramCore — app сам выйдет из auth.
    func divoHeadlessAuth(phone: String) {
        divoLog("[Auth UI] divoHeadlessAuth — старт по phone=\(phone)", level: .info)

        // DIVO: соц-новый (ветка D) → после входа онбординг пушем в этот же auth-overlay. Удерживаем
        // overlay ДО завершения teamgram (без гонки с teardown). Ветки A/B (существующие) — без онбординга.
        if DivoConfig.pendingSocialRegistration != nil {
            self.divoHoldOverlayForOnboarding = true
        }

        // Подавляем пуш экранов ввода номера/кода из observer'а состояния — иначе они мелькают.
        self.divoSuppressAuthScreens = true
        // Светлый лоадинг на время всего flow (переиспользуем лоадер auto-signUp). Без phone/code экранов.
        self.setViewControllers([DivoSignUpLoadingController()], animated: !self.viewControllers.isEmpty)

        let accountManager = self.sharedContext.accountManager
        let firebaseSecretStream = self.sharedContext.firebaseSecretStream
        let forcedPasswordSetupNotice: (Int32) -> (NoticeEntryKey, CodableEntry)? = { value in
            guard let entry = CodableEntry(ApplicationSpecificCounterNotice(value: value)) else { return nil }
            return (ApplicationSpecificNotice.forcedPasswordSetupKey(), entry)
        }

        let pushConfiguration = self.sharedContext.authorizationPushConfiguration
        |> take(1)
        |> timeout(2.0, queue: .mainQueue(), alternate: .single(nil))

        let signal: Signal<Void, DivoHeadlessAuthError> = pushConfiguration
        |> castError(DivoHeadlessAuthError.self)
        |> mapToSignal { [weak self] pushConfiguration -> Signal<Void, DivoHeadlessAuthError> in
            guard let self else { return .complete() }
            // sendCode ставит postbox-state .confirmationCodeEntry и возвращает (возможно DC-смигрированный) account.
            return sendAuthorizationCode(
                accountManager: accountManager,
                account: self.account,
                phoneNumber: phone,
                apiId: self.account.networkArguments.apiId,
                apiHash: self.account.networkArguments.apiHash,
                pushNotificationConfiguration: pushConfiguration,
                firebaseSecretStream: firebaseSecretStream,
                syncContacts: true,
                forcedPasswordSetupNotice: forcedPasswordSetupNotice
            )
            |> mapError { DivoHeadlessAuthError.sendCode($0) }
            |> mapToSignal { sendResult -> Signal<Void, DivoHeadlessAuthError> in
                switch sendResult {
                case .loggedIn:
                    // Мгновенный логин (futureLoginToken и т.п.) — код вводить не нужно.
                    return .complete()
                case let .sentCode(account):
                    // Используем ИМЕННО account из .sentCode — на нём лежит .confirmationCodeEntry.
                    return authorizeWithCode(
                        accountManager: accountManager,
                        account: account,
                        code: .phoneCode(AuthorizationSequenceController.divoTeamgramPin),
                        termsOfService: nil,
                        forcedPasswordSetupNotice: forcedPasswordSetupNotice
                    )
                    |> mapError { DivoHeadlessAuthError.verify($0) }
                    |> mapToSignal { codeResult -> Signal<Void, DivoHeadlessAuthError> in
                        switch codeResult {
                        case .loggedIn:
                            // Ветка A: аккаунт уже существовал — signIn прошёл.
                            return .complete()
                        case let .signUp(data):
                            // teamgram-аккаунта нет: ставим .signUp-state через beginSignUp — дальше
                            // отрабатывает УЖЕ существующий observer → divoHandleAutoSignUp →
                            // signUpWithName("User"). Не дублируем signUpWithName здесь (и заодно
                            // обходим несовпадение Never/Void в then).
                            let _ = beginSignUp(account: account, data: data).startStandalone()
                            return .complete()
                        }
                    }
                }
            }
        }

        self.actionDisposable.set((signal |> deliverOnMainQueue).startStrict(error: { [weak self] error in
            self?.divoHandleHeadlessAuthError(error)
        }, completed: { [weak self] in
            // signUp-ветка дальше идёт в divoHandleAutoSignUp (свой лоадер) — phone/code экранов уже не будет.
            self?.divoSuppressAuthScreens = false
            divoLog("[Auth UI] divoHeadlessAuth — цепочка ОК (signIn → вошёл; signUp → передан в auto-signUp)", level: .info)
        }))
    }

    private func divoHandleHeadlessAuthError(_ error: DivoHeadlessAuthError) {
        self.divoSuppressAuthScreens = false
        // teamgram не завершился — overlay не удерживаем (онбординга не будет, возвращаемся на welcome).
        self.divoHoldOverlayForOnboarding = false
        // Соц-попытка (ветка D) не удалась — снимаем pending, иначе онбординг может всплыть позже.
        DivoConfig.pendingSocialRegistration = nil
        divoLog("[Auth UI] divoHeadlessAuth error: \(error)", level: .error)

        // Сбрасываем state в .empty — иначе постбокс сохранит просроченный codeHash и cold start
        // зациклится на confirmationCodeEntry/signUp.
        let account = self.account
        let _ = self.engine.auth.setState(state: UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .empty)).startStandalone()

        // TODO P1-fallback: на .verify(.invalidCode)/.verify(.codeExpired) стенд ждёт реальный SMS —
        // показать нативный confirmationCodeEntry-экран (номер уже введён, его НЕ показываем повторно),
        // а не сбрасывать в .empty. Пока стенд берёт фиксированный 12345, так что это редкий путь.
        let text: String
        switch error {
        case .sendCode(.timeout):
            text = self.presentationData.strings.Login_NetworkError
        case .sendCode(.limitExceeded), .verify(.limitExceeded), .signUp(.limitExceeded):
            text = self.presentationData.strings.Login_CodeFloodError
        case .verify(.codeExpired), .signUp(.codeExpired):
            text = self.presentationData.strings.Login_CodeExpiredError
        default:
            text = self.presentationData.strings.Login_UnknownError
        }

        // Лоадер был выставлен вручную; setState(.empty) НЕ перерисует UI, если state уже был .empty
        // (sendCode упал до смены состояния → distinctUntilChanged не эмитит) → иначе вечный спиннер.
        // Возвращаем welcome явно — с него можно повторить вход.
        if !(self.viewControllers.first is DivoAuthWelcomeController) {
            self.setViewControllers([self.welcomeController()], animated: true)
        }

        self.currentWindow?.present(
            textAlertController(sharedContext: self.sharedContext, title: nil, text: text, actions: [
                TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})
            ]),
            on: .root,
            blockInteraction: false,
            completion: {}
        )
    }
}
