import Foundation
import UIKit
import Display
import SwiftSignalKit
import DivoCore
import OnboardingUI

// DIVO: онбординг вшит в auth-флоу как PUSH-шаг (не модалка поверх таббара).
//
// Точка входа — divoCompleteAuthorizationWithDivoLink (см. +DivoPhoneLink): для соц-новых
// (ветка D) сразу, для phone — после успешного phone-link, если онбординг локально не пройден.
// teamgram-аккаунт к этому моменту уже authorized, но auth-overlay УДЕРЖАН в AppDelegate
// (флаг divoHoldOverlayForOnboarding ставится ДО завершения teamgram, поэтому гонки нет) —
// таббар построен, но скрыт под overlay'ем. На финале overlay снимаем сами (self.dismiss()).
extension AuthorizationSequenceController {
    /// Показывает онбординг (fullScreen-модалкой на удержанном auth-overlay). Путь регистрации
    /// submit-сервис определяет сам по pending-флагам (соц-новый / phone-новый / existing-not-done).
    func divoPushOnboarding() {
        let isSocial = DivoConfig.pendingSocialRegistration != nil
        divoLog("[Auth UI] онбординг → push в auth-стек (\(isSocial ? "social" : "phone"))", level: .info)

        // Глушим auth-state observer: аккаунт уже authorized, overlay удержан вручную. Иначе поздний
        // `.unauthorized(.empty)` (гашение старого unauth-аккаунта) дёрнет updateState(.empty) →
        // setViewControllers([welcome]) и МОЛЧА затрёт онбординг (баг «выбросило на велком»).
        // После онбординга overlay снимается явно (dismiss); при отмене — divoLogoutTeamgram.
        self.stateDisposable?.dispose()
        self.stateDisposable = nil

        // Откат при фейле submit-цепочки: сервис постит onboardingChainFailedNotification
        // (onFinish при фейле НЕ зовётся — submit-экран показывает retry). Слушаем здесь, чтобы
        // по правилу атомарности сделать logout teamgram + снять overlay.
        self.divoOnboardingChainFailedObserver = NotificationCenter.default.addObserver(
            forName: DivoConfig.onboardingChainFailedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            divoLog("[Auth UI] онбординг-цепочка не прошла → logout teamgram + welcome (со снеком)", level: .error)
            self.divoClearOnboardingChainObserver()
            // Фейл цепочки — НЕ молча: показываем сообщение перед откатом (правило Marina).
            self.divoLogoutTeamgram(failureText: DivoStrings.onboardingChainFailed)
        }

        let submitService = DivoOnboardingSubmitService()
        // forceFresh: false — резюмим сохранённый шаг онбординга (req: при перезаходе тот же экран).
        // Чистый старт для нового юзера гарантирует чистка стора на logout (см. divoLogoutTeamgram).
        let onboarding = OnboardingRegistrationEntry.makeController(forceFresh: false, submitService: submitService, onFinish: { [weak self] success in
            guard let self else { return }
            self.divoClearOnboardingChainObserver()
            if success {
                // Цепочка прошла целиком (submit пометил markOnboardingCompleted) → снимаем модалку
                // онбординга и overlay → открывается уже готовый таббар.
                DivoConfig.pendingSocialRegistration = nil
                DivoConfig.pendingPhoneOnboarding = false
                DivoConfig.pendingPhoneNumber = nil
                self.divoHoldOverlayForOnboarding = false
                // Снимаем модалку онбординга через прямую ссылку (а не viewControllers.last?.presentedViewController,
                // который == nil из-за переназначения презентации на nav-контейнер), затем сам overlay → таббар.
                self.divoOnboardingController?.dismiss(animated: false)
                self.dismiss()
            } else {
                // Отмена крестиком — юзер сам решил → откат молча (divoLogoutTeamgram снимет модалку).
                self.divoLogoutTeamgram()
            }
        })

        // Презентуем fullScreen НА верхнем контроллере overlay (НЕ на self — present на Display-
        // навигаторе крэшит, см. [[reference_navigationcontroller_present_crash]]). Полноценный
        // modal-контекст: у онбординга нормальный UIKit-lifecycle (viewDidAppear → submit стартует),
        // safe area и PHPicker работают — в отличие от вложенного Display-хоста, который ломал
        // и lifecycle (пустой серый submit-экран), и safe area (кнопки уезжали под бары).
        onboarding.modalPresentationStyle = .fullScreen
        self.viewControllers.last?.present(onboarding, animated: true)
        // Прямая ссылка на модалку для надёжного дисмисса (см. divoOnboardingController).
        self.divoOnboardingController = onboarding
    }

    /// Phone-флоу без онбординга (существующий юзер, онбординг уже пройден): завершаем —
    /// снимаем hold и сам overlay (AppDelegate его удержал, т.к. hold ставится до завершения teamgram).
    func divoFinishWithoutOnboarding(complete: @escaping () -> Void) {
        self.divoHoldOverlayForOnboarding = false
        complete()
        self.dismiss()
    }

    func divoClearOnboardingChainObserver() {
        if let observer = self.divoOnboardingChainFailedObserver {
            NotificationCenter.default.removeObserver(observer)
            self.divoOnboardingChainFailedObserver = nil
        }
    }
}
