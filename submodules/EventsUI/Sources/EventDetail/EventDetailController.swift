import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import TelegramBaseController

public final class EventDetailController: TelegramBaseController {
    
    private var controllerNode: EventDetailControllerNode {
        return self.displayNode as! EventDetailControllerNode
    }
    
    private let getEventDisposable = MetaDisposable()
    
    private var customBackSwipeGestureRecognizer: UIScreenEdgePanGestureRecognizer?
    
    private let eventData: EventData
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private var navigationBarIsTransparent = true

    init(context: AccountContext, eventData: EventData) {
        self.context = context
        self.eventData = eventData
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let darkNavigationTheme = NavigationBarTheme(
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
        
        let navigationBarData = NavigationBarPresentationData(theme: darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))
        
        super.init(context: context, navigationBarPresentationData: navigationBarData, mediaAccessoryPanelVisibility: .none, locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        updateNavigation()
    }
    
    deinit {
        self.getEventDisposable.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateNavigation() {
        self.statusBar.statusBarStyle = .White
        
//        self.navigationController?.navigationBar.tintColor = .white
        
        let likeLabel = UILabel()
        likeLabel.text = "1K"
        likeLabel.textColor = .white
        likeLabel.font = .systemFont(ofSize: 17, weight: .bold)
        
        let likeImageView = UIImageView(image: UIImage(bundleImageName: "Contact List/HeartActionIcon")!)
        likeImageView.tintColor = .white
        
        let customLikeView = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        customLikeView.addSubview(likeImageView)
        customLikeView.addSubview(likeLabel)
        
        likeImageView.translatesAutoresizingMaskIntoConstraints = false
        likeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            likeImageView.leadingAnchor.constraint(equalTo: customLikeView.leadingAnchor, constant: 0),
            likeImageView.centerYAnchor.constraint(equalTo: customLikeView.centerYAnchor),
            likeImageView.widthAnchor.constraint(equalToConstant: 25),
            likeImageView.heightAnchor.constraint(equalToConstant: 25),
            
            likeLabel.leadingAnchor.constraint(equalTo: likeImageView.trailingAnchor, constant: 5),
            likeLabel.centerYAnchor.constraint(equalTo: customLikeView.centerYAnchor)
        ])
        
        let likeButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Contact List/HeartActionIcon"), color: .white)
        let shareButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionAction"), color: .white)
        let bookmarkButtonImg = generateTintedImage(image: UIImage(bundleImageName: "Instant View/Bookmark"), color: .white)
        
        let likeButton = UIBarButtonItem(image: likeButtonImg, style: .plain, target: self, action: #selector(self.likePressed))
        
        let shareButton = UIBarButtonItem(image: shareButtonImg, style: .plain, target: self, action: #selector(self.sharePressed))
        let bookmarkButton =  UIBarButtonItem(image: bookmarkButtonImg, style: .plain, target: self, action: #selector(self.bookmarkPressed))
        
//        self.navigationItem.leftBarButtonItem = backButton
        self.navigationItem.rightBarButtonItems = [likeButton, shareButton, bookmarkButton]
    }
    
    @objc private func backPressed() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func likePressed() {
        print("Like button pressed")
    }
    
    @objc private func sharePressed() {
        print("Share button pressed")
    }
    
    @objc private func bookmarkPressed() {
        print("Bookmark button pressed")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = EventDetailControllerNode(context: self.context, presentationData: self.presentationData)
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getEvent()
    }
    
    private func getEvent() {
        let supportPeer = Promise<EventModel?>()
        supportPeer.set(context.engine.eventsEngine.getEvent(eventId: eventData.id))
        self.getEventDisposable.set((supportPeer.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { eventModel in
            
            if let eventModel = eventModel {
                let datePartPrefix = eventModel.eventDate.prefix(while: { $0 != "T" })
                
                let data = EventData(
                    id: eventModel.id,
                    title: eventModel.title,
                    subtitle: eventModel.description,
                    imageName: "Components/Model",
                    profileImageName: "Components/Model",
                    profileName: "@nyfw",
                    timeRemaining: String(datePartPrefix),
                    type: eventModel.eventType ?? "",
                    coverPhoto: eventModel.coverPhoto
                )
                self.controllerNode.updateEventData(data)
                print("🔕", eventModel)
            }
        }))
    }
}
