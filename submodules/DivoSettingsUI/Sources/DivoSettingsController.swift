import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramBaseController
import AppBundle
import DivoCore
import DivoUIKit
import ProfileScreenUI
import OnboardingUI

public final class DivoSettingsController: TelegramBaseController {

    private var controllerNode: DivoSettingsNode {
        return self.displayNode as! DivoSettingsNode
    }

    private let _ready = Promise<Bool>(true)
    override public var ready: Promise<Bool> {
        return self._ready
    }

    private let context: AccountContext
    private var presentationData: PresentationData

    private var userDetailData: UserDetail?
    private var isProfileLoaded = false

    private var notificationObservers: [NSObjectProtocol] = []

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(context: context, navigationBarPresentationData: nil)

        self.tabBarItem.title = DivoStrings.tabSettings
        let settingsIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconSettings"), color: DivoColorPalette.tabInactiveIcon)
        let settingsIconSelected = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconSettings"), color: DivoColorPalette.tabActiveIcon)
        self.tabBarItem.image = settingsIcon
        self.tabBarItem.selectedImage = settingsIconSelected

        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(forName: DivoConfig.tokenDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reloadProfile()
        })
        notificationObservers.append(center.addObserver(forName: DivoConfig.profileDidUpdateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reloadProfile()
        })
        notificationObservers.append(center.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarItem.title = DivoStrings.tabSettings
        })
        notificationObservers.append(center.addObserver(forName: DivoDebugFlags.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            // Debug-флаг прячет/показывает «Launch onboarding»-row под логаутом.
            self?.controllerNode.applyOnboardingEntryVisibility()
        })
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
    }

    override public func loadDisplayNode() {
        self.displayNode = DivoSettingsNode(context: self.context)

        self.controllerNode.onProfileTapped = { [weak self] in
            self?.openMyProfile()
        }
        self.controllerNode.onSetUsernameTapped = { [weak self] in
            // TODO(DIVO): open set username flow.
            _ = self
        }
        self.controllerNode.onFillParametersTapped = { [weak self] in
            self?.openMyParameters()
        }
        self.controllerNode.onQrTapped = { [weak self] in
            // TODO(DIVO): open QR scanner.
            _ = self
        }

        self.controllerNode.presentController = { [weak self] vc in
            self?.view.window?.rootViewController?.present(vc, animated: true)
        }

        self.controllerNode.saveMeasuringSystem = { [weak self] measuring in
            self?.handleSaveMeasuringSystem(with: measuring)
        }

        self.controllerNode.onOnboardingEntryTapped = { [weak self] in
            self?.launchOnboardingDebug()
        }

        self.displayNodeDidLoad()
    }

    /// Запускает регистрационный онбординг модально, минуя авторизацию. Используется только из
    /// debug-row под логаутом (виден если включён `DivoDebugFlags.showOnboardingEntry`).
    /// `forceFresh: false` — продолжаем сохранённый прогресс, чтобы можно было закрыть онбординг,
    /// вернуться и продолжить заполнение. Сбросить прогресс — Debug Menu → Onboarding → Clear progress.
    private func launchOnboardingDebug() {
        weak var onboardingHolder: UIViewController?
        let controller = OnboardingRegistrationEntry.makeController(forceFresh: false) { _ in
            // Закрываем сам онбординг — работает для обоих кейсов:
            // - presented modal (как сейчас): `dismiss` идёт через presenting controller;
            // - pushed: pop'аем к предыдущему контроллеру в стэке.
            guard let onb = onboardingHolder else { return }
            if onb.presentingViewController != nil {
                onb.dismiss(animated: true)
                return
            }
            if let nav = onb.navigationController,
               let idx = nav.viewControllers.firstIndex(of: onb), idx > 0 {
                nav.popToViewController(nav.viewControllers[idx - 1], animated: true)
                return
            }
            onb.dismiss(animated: true)
        }
        onboardingHolder = controller
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !isProfileLoaded {
            loadProfileData()
        }
    }

    // MARK: - Actions

    private func openMyProfile() {
        guard let user = userDetailData else { return }
        let profileModel = ProfileModel(
            name: user.fullName ?? "",
            age: nil,
            location: "",
            isVerified: false,
            likesCount: "0",
            viewsCount: "0",
            savesCount: "0",
            biography: user.model?.description ?? "",
            socialMediaHandles: [],
            isMyProfile: true,
            userId: user.id,
            role: user.role,
            avatarImageURL: CDNURLHelper.convertToCDNURL(user.avatar?.fullUrl)
        )
        let profileController = PublicProfileScreenController(context: context, model: profileModel)
        if let nav = self.navigationController as? NavigationController {
            nav.pushViewController(profileController, animated: true)
        }
    }

    private func openMyParameters() {
        let profileController = EditParametersController(context: context, userDetailData: self.userDetailData)
        profileController.delegate = self
        if let nav = self.navigationController as? NavigationController {
            nav.pushViewController(profileController, animated: true)
        }
    }

    private func loadProfileData() {
        self.controllerNode.markLoading()

        Task { @MainActor in
            do {
                let response: UserDetailResponse = try await DivoAPIClient.shared.request(path: "/user/info")
                self.isProfileLoaded = true
                self.userDetailData = response.data
                self.controllerNode.updateWithProfile(response.data)
            } catch {
                self.controllerNode.markFailed()
                self.controllerNode.showSnackbar(
                    message: DivoStrings.failedLoadInteractionList,
                    style: .error,
                    retryAction: { [weak self] in
                        self?.controllerNode.hideSnackbar(animated: true)
                        self?.loadProfileData()
                    },
                    persistent: true
                )
            }
        }
    }

    private func reloadProfile() {
        isProfileLoaded = false
        loadProfileData()
    }

    private func handleSaveMeasuringSystem(with rawData: String?) {
        Task { @MainActor in
            do {
                let request = UpdateMeasuringSystemRequest(measuringSystem: rawData)
                let _: UpdateBiographyPageResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )
                self.reloadProfile()
            } catch {
                self.controllerNode.showSnackbar(
                    message: DivoStrings.failedMeasuringSystemUpdated,
                    style: .error
                )
            }
        }
    }
}

extension DivoSettingsController: EditParametersDelegate {
    func didUpdateParametersData() {
        self.reloadProfile()

        self.controllerNode.showSnackbar(
            message: DivoStrings.parametersUpdated,
            style: .success
        )
    }
}
