import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import MessageUI
import TelegramPresentationData
import AccountContext
import ShareController
import AlertUI
import PresentationDataUtils
import SearchUI
import CountrySelectionUI
import ChatScheduleTimeController
import Postbox
import DivoUIKit

public class EventsSearchController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext

    private var contactsNode: EventsSearchControllerNode {
        return self.displayNode as! EventsSearchControllerNode
    }

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    private var searchContentNode: NavigationBarSearchContentNode?

    public init(context: AccountContext) {
        self.context = context

        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .black,
            disabledButtonColor: DivoColorPalette.disabledButtonBackground,
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)

        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))

        super.init(navigationBarPresentationData: navigationBarData)

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        NotificationCenter.default.addObserver(self, selector: #selector(handleWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        self.title = ""

        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)

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

        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search, activate: {

        })
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        self.presentationDataDisposable?.dispose()
    }

    private func makeNavigationBarPresentationData() -> NavigationBarPresentationData {
        let theme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .black,
            disabledButtonColor: DivoColorPalette.disabledButtonBackground,
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
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

        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search)

        self.title = ""

        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }

    override public func loadDisplayNode() {
        self.displayNode = EventsSearchControllerNode(context: self.context)

        self.contactsNode.selectCountryCode = { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme, displayCodes: false)
                controller.completeWithCountryCode = { _, countryId, name in

                    if let strongSelf = self {
                        strongSelf.contactsNode.updateCountry(countryId: countryId, countryName: name)
                    }
                }
                controller.dismissed = {

                }
                strongSelf.push(controller)
            }
        }

        self.contactsNode.scheduleTimeController = { [weak self] in
            self?.scheduleTimeController()
        }

        self.displayNodeDidLoad()
    }

    private func scheduleTimeController() {
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
                self?.contactsNode.updateTime(time)
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

        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

}
