import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import DivoCore
import MessageUI
import TelegramPresentationData
import AccountContext
import ShareController
import AlertUI
import PresentationDataUtils
import SearchUI
import LegacyMediaPickerUI
import CountrySelectionUI
import ChatScheduleTimeController
import Postbox
import DivoUIKit

public class AddWorkExperienceController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    private let editItem: WorkHistoryItem?

    private var createEventNode: AddWorkExperience {
        return self.displayNode as! AddWorkExperience
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    public init(context: AccountContext, editItem: WorkHistoryItem? = nil) {
        self.context = context
        self.editItem = editItem

        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let brownColor = DivoColorPalette.accentCopperDeep

        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: brownColor,
            disabledButtonColor: DivoColorPalette.disabledButtonBackground,
            primaryTextColor: .black,
            backgroundColor: .white,
            opaqueBackgroundColor: .white,
            enableBackgroundBlur: false,
            separatorColor: DivoColorPalette.separatorSystem,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)

        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))

        super.init(navigationBarPresentationData: navigationBarData)

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        NotificationCenter.default.addObserver(self, selector: #selector(handleWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)

        let titleLabel = UILabel()
        titleLabel.attributedText = Font.helveticaNeue(
            editItem != nil ? DivoStrings.navEditExperience : DivoStrings.navCreateExperience,
            20,
            .black
        )
        titleLabel.sizeToFit()
        self.navigationItem.titleView = titleLabel

        let navFont = UIFont.systemFont(ofSize: 17, weight: .regular)
        let navFontAttributes: [NSAttributedString.Key: Any] = [.font: navFont, .kern: -0.4]

        let createItem = UIBarButtonItem(title: DivoStrings.create, style: .plain, target: self, action: #selector(createPressed))
        createItem.tintColor = brownColor
        createItem.setTitleTextAttributes(navFontAttributes, for: .normal)
        createItem.setTitleTextAttributes(navFontAttributes, for: .highlighted)
        self.navigationItem.rightBarButtonItem = createItem

        self.navigationItem.backBarButtonItem?.setTitleTextAttributes(navFontAttributes, for: .normal)
        self.navigationItem.backBarButtonItem?.setTitleTextAttributes(navFontAttributes, for: .highlighted)

        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings

                strongSelf.presentationData = presentationData

                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        }).strict()
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        self.presentationDataDisposable?.dispose()
    }

    private func makeNavigationBarPresentationData() -> NavigationBarPresentationData {
        let brownColor = DivoColorPalette.accentCopperDeep
        let theme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: brownColor,
            disabledButtonColor: DivoColorPalette.disabledButtonBackground,
            primaryTextColor: .black,
            backgroundColor: .white,
            opaqueBackgroundColor: .white,
            enableBackgroundBlur: false,
            separatorColor: DivoColorPalette.separatorSystem,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)
        return NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))
    }

    @objc private func handleWillEnterForeground() {
        self.navigationBar?.updatePresentationData(makeNavigationBarPresentationData(), transition: .immediate)
    }

    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(makeNavigationBarPresentationData(), transition: .immediate)

        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }

    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        let theme = self.presentationData.theme

        self.displayNode = AddWorkExperience(context: self.context, editItem: self.editItem, addPhoto: { [weak self] in
            presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: theme, present: { c, a in
                self?.view.endEditing(true)
                self?.present(c, in: .window(.root), with: a)
            }, openCurrent: nil, completion: { image in
                self?.createEventNode.currentPhoto = image
//                self?.avatarAsset = nil
//                self?.avatarAdjustments = nil
            }, videoCompletion: { image, asset, adjustments in
                self?.createEventNode.currentPhoto = image
//                self?.avatarAsset = asset
//                self?.avatarAdjustments = adjustments
            })
        })

        self.createEventNode.scheduleTimeController = { [weak self] type in
            self?.scheduleTimeController(type: type)
        }
        self.createEventNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
        }
        self.createEventNode.onSaveSuccess = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        self.displayNodeDidLoad()
    }

    @objc private func createPressed() {
        self.createEventNode.applyButtonTapped()
    }

    private func showAlert(text: String) {

        let alertController = textAlertController(
            context: context, title: nil,
            text: text, actions: [
                TextAlertAction(type: .genericAction, title: "Ok", action: {
                    print("ok")
                })
            ])
        present(alertController, in: .window(.root))
    }

    private func scheduleTimeController(type: TimeType) {
        let peerId = PeerId(0)
        let controller = TimeController(
            context: context,
            updatedPresentationData: nil,
            peerId: peerId,
            mode: .date,
            style: .default,
            currentTime: nil,
            minimalTime: nil,
            completion: { [weak self] time in
                self?.createEventNode.updateTime(time, type: type)
            })
        present(controller, in: .window(.root))
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.updatePresentationData(makeNavigationBarPresentationData(), transition: .immediate)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.createEventNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

}
