import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import TelegramBaseController
import LegacyMediaPickerUI
import Postbox
import MapResourceToAvatarSizes
import ContextUI
import DivoUIKit

public final class WorkExperienceController: TelegramBaseController {

    private var controllerNode: WorkExperience {
        return self.displayNode as! WorkExperience
    }

    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?

    private let model: ProfileModel
    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()
    private let createWorkExperienceDisposable = MetaDisposable()

    private var presentationData: PresentationData

    private var navigationBarIsTransparent = true
    private let peer: Peer?

    public init(context: AccountContext, model: ProfileModel, peer: Peer? = nil) {
        self.context = context
        self.model = model
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.peer = peer

        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: DivoColorPalette.accentCopperDeep,
            disabledButtonColor: DivoColorPalette.disabledButtonBackground,
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .black,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)
//
        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))

        super.init(context: context, navigationBarPresentationData: navigationBarData)

        updateNavigation()
    }

    deinit {
        self.supportPeerDisposable.dispose()
        self.createWorkExperienceDisposable.dispose()
    }


    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateNavigation() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        self.title = DivoStrings.workExperience

        if model.isMyProfile {
            let addItem = UIBarButtonItem(image: UIImage(bundleImageName: "Components/addIcon"), style: .plain, target: self, action: #selector(self.addPressed))
            addItem.tintColor = DivoColorPalette.accentCopperTint
            self.navigationItem.rightBarButtonItem = addItem
        }
    }

    @objc private func addPressed() {
        addWorkExperience()
    }

    private func addWorkExperience() {
        let controller = AddWorkExperienceController(context: self.context)
        self.push(controller)
    }

    @objc private func backPressed() {
        self.navigationController?.popViewController(animated: true)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getWorkHistory()
    }

    private func getWorkHistory() {
        controllerNode.setLoading(true)
        guard let userId = model.userId else {
            controllerNode.setLoading(false)
            return
        }
        Task {
            // Try structured API first
            var structuredItems: [WorkHistoryItem] = []
            do {
                let response: WorkHistoryResponse = try await DivoAPIClient.shared.request(
                    path: "/model-work-history?userId=\(userId)"
                )
                structuredItems = response.data.items
            } catch {
                print("[DivoAPI] model-work-history error: \(error)")
            }

            if !structuredItems.isEmpty {
                await MainActor.run {
                    self.controllerNode.reloadWorkHistory(items: structuredItems)
                }
                return
            }

            // Fallback: parse workExperience text from user profile
            do {
                let userResponse: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/\(userId)"
                )
                await MainActor.run {
                    self.controllerNode.reloadLegacyWorkHistory(model: userResponse.data)
                }
            } catch {
                await MainActor.run {
                    self.controllerNode.setLoading(false)
                }
                print("[DivoAPI] user/\(userId) fallback error: \(error)")
            }
        }
    }


    override public func loadDisplayNode() {
        self.displayNode = WorkExperience(
            controller: self,
            context: self.context,
            presentationData: self.presentationData,
            model: model)

        self.controllerNode.showItemOptions = { [weak self] item in
            self?.showItemOptions(item)
        }

        self.controllerNode.openAddWorkExperience = { [weak self] in
            self?.addWorkExperience()
        }


        self.displayNodeDidLoad()
    }

    private func showItemOptions(_ item: WorkHistoryItem) {
        let name = item.agencyDisplayName ?? item.agencyName ?? "Unknown"
        let alertController = textAlertController(
            context: context, title: name,
            text: DivoStrings.chooseAnAction, actions: [
                TextAlertAction(type: .genericAction, title: DivoStrings.edit, action: {
                    self.editWorkExperience(item)
                }),
                TextAlertAction(type: .destructiveAction, title: DivoStrings.delete, action: {
                    self.deleteWorkHistory(id: item.id)
                }),
                TextAlertAction(type: .defaultAction, title: DivoStrings.cancel, action: {})
            ])
        present(alertController, in: .window(.root))
    }

    private func editWorkExperience(_ item: WorkHistoryItem) {
        let controller = AddWorkExperienceController(context: self.context, editItem: item)
        self.push(controller)
    }

    private func deleteWorkHistory(id: Int) {
        Task {
            do {
                let _: WorkHistoryDeleteResponse = try await DivoAPIClient.shared.request(
                    path: "/model-work-history/\(id)",
                    method: "DELETE"
                )
                await MainActor.run {
                    self.getWorkHistory()
                }
            } catch {
                print("[DivoAPI] delete model-work-history/\(id) error: \(error)")
            }
        }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
