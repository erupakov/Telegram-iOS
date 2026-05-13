import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramBaseController
import TelegramCore
import DivoCore
import DivoUIKit
import AppBundle
import ProfileScreenUI

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

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(context: context, navigationBarPresentationData: nil)

        self.tabBarItem.title = DivoStrings.tabSettings
        let settingsIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconSettings"), color: DivoColorPalette.tabInactiveIcon)
        let settingsIconSelected = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconSettings"), color: DivoColorPalette.tabActiveIcon)
        self.tabBarItem.image = settingsIcon
        self.tabBarItem.selectedImage = settingsIconSelected

        NotificationCenter.default.addObserver(forName: DivoConfig.tokenDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.reloadProfile()
        }
        NotificationCenter.default.addObserver(forName: DivoConfig.profileDidUpdateNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.reloadProfile()
        }

        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.tabBarItem.title = DivoStrings.tabSettings
        }
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = DivoSettingsNode(context: self.context)
        
        self.controllerNode.onProfileTapped = { [weak self] in
            self?.openMyProfile()
        }
        self.controllerNode.onSetUsernameTapped = { [weak self] in
            // TODO: open set username flow
            _ = self
        }
        self.controllerNode.onFillParametersTapped = { [weak self] in
            self?.openMyParameters()
        }
        self.controllerNode.onLearnMoreTapped = { [weak self] in
            // TODO: open learn more
            _ = self
        }
        
        self.controllerNode.presentController = { [weak self] vc in
            self?.view.window?.rootViewController?.present(vc, animated: true)
        }
        
        self.displayNodeDidLoad()
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

    @objc private func qrTapped() {
        // TODO: open QR scanner
    }

    @objc private func editTapped() {
        openMyProfile()
    }

    private func openMyProfile() {
        let profileModel = ProfileModel(
            name: "",
            age: 0,
            location: "",
            isVerified: false,
            likesCount: "0",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            isMyProfile: true
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
                let response: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/info"
                )
                self.isProfileLoaded = true
                self.userDetailData = response.data
                self.controllerNode.updateWithProfile(response.data)
            } catch {
                self.controllerNode.markFailed()
                self.controllerNode.showSnackbar(
                    message: DivoStrings.failedLoadInteractionList, // Замените на вашу строку, например DivoStrings.serverUnavailable
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
}

extension DivoSettingsController: EditParametersDelegate {
    func didUpdateParametersData() {
        self.reloadProfile()

        self.controllerNode.showSnackbar(
            message: DivoStrings.prametersUpdated,
            style: .success
        )
    }
}