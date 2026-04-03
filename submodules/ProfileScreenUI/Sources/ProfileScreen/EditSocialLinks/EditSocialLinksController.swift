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
import LegacyMediaPickerUI
import CountrySelectionUI
import ChatScheduleTimeController

protocol EditSocialLinksDelegate: AnyObject {
    func didUpdateSocialLinksData()
}

public class EditSocialLinksController: ViewController, UINavigationControllerDelegate {
    private let context: AccountContext
    
    private var createEventNode: EditSocialLinksNode {
        return self.displayNode as! EditSocialLinksNode
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Any?
    private var linksData: LinksData

    weak var delegate: EditSocialLinksDelegate?

    public init(context: AccountContext, presentationData: PresentationData, linksData: LinksData) {
        self.context = context
        self.linksData = linksData

        self.presentationData = presentationData
        
        let darkNavigationTheme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)

        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(back: DivoStrings.back, close: DivoStrings.close))
        
        super.init(navigationBarPresentationData: navigationBarData)

        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style

        NotificationCenter.default.addObserver(self, selector: #selector(handleWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        self.title = DivoStrings.editSocialLinks
        
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
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        (self.presentationDataDisposable as? Disposable)?.dispose()
    }

    private func makeNavigationBarPresentationData() -> NavigationBarPresentationData {
        let theme = NavigationBarTheme(
            overallDarkAppearance: true,
            buttonColor: .white,
            disabledButtonColor: UIColor(rgb: 0x525252),
            primaryTextColor: .white,
            backgroundColor: .clear,
            opaqueBackgroundColor: .clear,
            enableBackgroundBlur: false,
            separatorColor: .clear,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear)
        return NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(back: DivoStrings.back, close: DivoStrings.close))
    }

    @objc private func handleWillEnterForeground() {
        self.navigationBar?.updatePresentationData(makeNavigationBarPresentationData(), transition: .immediate)
    }

    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        self.navigationBar?.updatePresentationData(makeNavigationBarPresentationData(), transition: .immediate)

        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        let theme = self.presentationData.theme

        self.displayNode = EditSocialLinksNode(context: self.context, presentationData: self.presentationData, linksData: linksData, addPhoto: { [weak self] in
            presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: theme, present: { c, a in
                self?.view.endEditing(true)
                self?.present(c, in: .window(.root), with: a)
            }, openCurrent: nil, completion: { image in
//                self?.createEventNode.currentPhoto = image
//                self?.avatarAsset = nil
//                self?.avatarAdjustments = nil
            }, videoCompletion: { image, asset, adjustments in
//                self?.createEventNode.currentPhoto = image
//                self?.avatarAsset = asset
//                self?.avatarAdjustments = adjustments
            })
        })

        self.createEventNode.showAlert = { [weak self] text in
            self?.showAlert(text: text)
        }
        
        self.createEventNode.saveSocialLinks = { [weak self] linksData in
            self?.saveSocialLinks(linksData: linksData)
        }

        self.displayNodeDidLoad()
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
    
    private func saveSocialLinks(linksData: LinksData) {
        Task { @MainActor in
            do {
                let request = UpdateSocialLinksRequest(
                    model: UpdateSocialLinksRequest.ModelData(
                        tiktokUrl: linksData.tiktokUrl != nil ? linksData.tiktokUrl : "",
                        youtubeUrl: linksData.youtubeUrl != nil ? linksData.youtubeUrl : "",
                        telegramUrl: linksData.telegramUrl != nil ? linksData.telegramUrl : "",
                        instagramUrl: linksData.instagramUrl != nil ? linksData.instagramUrl : "",
                        websiteUrl: linksData.websiteUrl != nil ? linksData.websiteUrl : ""
                    )
                )
                
                let response: UpdateSocialLinksResponse = try await DivoAPIClient.shared.request(
                    path: "/user/update-profile",
                    method: "POST",
                    body: request
                )
                
                print("✅ Social links successfully saved: \(response.message ?? "OK")")
                self.delegate?.didUpdateSocialLinksData()
                self.createEventNode.toggleSpinner(active: false)
                self.showAlert(text: DivoStrings.socialLinksUpdated)
                
                self.navigationController?.popViewController(animated: true)
                
            } catch {
                print("❌ Error saving social links: \(error)")
                self.createEventNode.toggleSpinner(active: false)
                self.showAlert(text: error.localizedDescription)
            }
        }
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
