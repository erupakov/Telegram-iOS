import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import DivoCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import AppBundle
import LocalizedPeerData
import ContextUI
import TelegramBaseController
import DivoUIKit

public final class EventsController: TelegramBaseController {
    private var controllerNode: EventsControllerNode {
        return self.displayNode as! EventsControllerNode
    }

    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
//        getEvents()
        return self._ready
    }

    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    private let peerViewDisposable = MetaDisposable()

    private var isEmpty: Bool?
    private var tokenChangeObserver: NSObjectProtocol?

    private let createActionDisposable = MetaDisposable()
    private let clearDisposable = MetaDisposable()

    private var isAgency: Bool = false
    private var didLoadEvents: Bool = false
    private var cachedItems: [EventListItem] = []

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let navTheme = NavigationBarTheme(overallDarkAppearance: true, buttonColor: .black, disabledButtonColor: DivoColorPalette.navBarDisabledButtonColor, primaryTextColor: .white, backgroundColor: .clear, opaqueBackgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(theme: navTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))

        let icon: UIImage = DivoImage.iconEvents
        self.tabBarItem.title = DivoStrings.tabEvents
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon

        updateNavigation()

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
            }
        }).strict()

        self.tokenChangeObserver = NotificationCenter.default.addObserver(
            forName: DivoConfig.tokenDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchUserRole()
            self?.getEvents()
        }
        NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarItem.title = DivoStrings.tabEvents
            self?.renderCachedItems()
        }
    }

    private func updateNavigation() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        let copperColor = DivoColorPalette.accentSecondary

        let searchIcon = generateTintedImage(image: PresentationResourcesRootController.navigationSearchIcon(self.presentationData.theme), color: copperColor)
        let searchButton = UIBarButtonItem(image: searchIcon?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(self.searchPressed))

        var rightItems = [searchButton]

        if self.isAgency {
            let addIcon = generateTintedImage(image: PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme), color: copperColor)
            let addButton = UIBarButtonItem(image: addIcon?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(self.addPressed))
            rightItems.insert(addButton, at: 0)
        }

        self.navigationItem.rightBarButtonItems = rightItems

        self.navigationItem.titleView = UIView()
    }

    private var lastContentOffset: CGPoint = .zero

    public func updateContentOffset(offset: CGPoint) {
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !didLoadEvents {
            fetchUserRole()
            getEvents()
        }
    }

    private func fetchUserRole() {
        Task {
            do {
                let response: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/info",
                    method: "GET"
                )
                let role = response.data.role ?? ""
                await MainActor.run {
                    let wasAgency = self.isAgency
                    self.isAgency = role == "agency" || role == "agency_employee"
                    if wasAgency != self.isAgency {
                        self.updateNavigation()
                    }
                }
            } catch {
                print("⚠️ fetchUserRole failed: \(error)")
            }
        }
    }

    private func getEvents() {
        self.controllerNode.beginLoading()
        let body = EventListRequest(offset: 0, limit: 30, creatorId: nil)
        Task {
            do {
                let response: EventListResponse = try await DivoAPIClient.shared.request(
                    path: "/event/list",
                    method: "POST",
                    body: body
                )
                await MainActor.run {
                    self.cachedItems = response.data.items
                    self.didLoadEvents = true
                    self.renderCachedItems()
                }
                return
            } catch {}
            await MainActor.run {
                self.cachedItems = []
                self.didLoadEvents = true
                self.renderCachedItems()
            }
        }
    }

    private func renderCachedItems() {
        let items = self.cachedItems
        guard !items.isEmpty else {
            self.controllerNode.reloadEvents(events: [])
            return
        }
        let divoLocale = Locale(identifier: DivoStrings.current.rawValue)
        let datePartFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = divoLocale
            f.setLocalizedDateFormatFromTemplate("MMM d")
            return f
        }()
        let timePartFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = divoLocale
            f.timeStyle = .short
            f.dateStyle = .none
            return f
        }()
        let isoFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            return f
        }()
        let eventDataArray: [EventData] = items.map { item in
            let dateString: String
            if let raw = item.date {
                let normalized = raw.replacingOccurrences(of: " ", with: "T")
                if let date = isoFormatter.date(from: normalized) {
                    dateString = datePartFormatter.string(from: date) + " · " + timePartFormatter.string(from: date)
                } else {
                    dateString = raw
                }
            } else {
                dateString = ""
            }
            let timeRemaining: String
            if let raw = item.date, let date = isoFormatter.date(from: raw.replacingOccurrences(of: " ", with: "T")), date > Date() {
                let f = DateComponentsFormatter()
                f.unitsStyle = .abbreviated
                f.allowedUnits = [.day, .hour, .minute]
                f.calendar = Calendar.current
                f.calendar?.locale = divoLocale
                timeRemaining = f.string(from: Date(), to: date) ?? ""
            } else {
                timeRemaining = ""
            }
            let coverURL = item.files?.first?.fullUrl
            let avatarURL = item.creator?.avatar?.fullUrl
            let cityName = item.address?.city?.name ?? ""
            return EventData(
                id: item.id,
                title: item.title ?? "",
                subtitle: item.type?.title ?? "",
                profileName: "@" + (item.creator?.fullName ?? ""),
                timeRemaining: timeRemaining,
                type: item.type?.title ?? "",
                coverPhotoURL: coverURL,
                profilePhotoURL: avatarURL,
                location: cityName,
                eventDateFormatted: dateString
            )
        }
        self.controllerNode.reloadEvents(events: eventDataArray)
    }

    @objc private func searchPressed() {
        let controller = EventsSearchController(context: context)
        self.push(controller)
    }

    @objc private func addPressed() {
        let controller = CreateEventController(context: context)
        controller.delegate = self
        self.push(controller)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.peerViewDisposable.dispose()
        self.clearDisposable.dispose()
        self.supportPeerDisposable.dispose()
        if let observer = self.tokenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override public func loadDisplayNode() {
        self.displayNode = EventsControllerNode(controller: self, context: self.context, presentationData: self.presentationData)
        self.displayNodeDidLoad()


//        self._ready.set(combineLatest(queue: .mainQueue(),
////            self.contactsNode.contactListNode.ready,
////            self.contactsNode.storiesReady.get()
//        )
//        |> filter { a, b in
//            return a && b
//        }
//        |> take(1)
//        |> map { _ -> Bool in true })
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

extension EventsController: CreateEventDelegate {
    func didCreateEvent() {
        self.getEvents()
    }
}