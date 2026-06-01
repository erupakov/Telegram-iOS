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
        return self._ready
    }

    private let context: AccountContext
    private let supportPeerDisposable = MetaDisposable()

    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    private let peerViewDisposable = MetaDisposable()

    private var isEmpty: Bool?
    private var tokenChangeObserver: NSObjectProtocol?
    private var localeChangeObserver: NSObjectProtocol?

    private let createActionDisposable = MetaDisposable()
    private let clearDisposable = MetaDisposable()

    private var isAgency: Bool = false
    private var userId: Int?
    private var didLoadEvents: Bool = false

    // Локальный кэш роли — чтобы при cold-start без сети мы знали, показывать ли
    // сегмент «Мои/Все» (агентство) на error state, а не ждали /user/info.
    private static func isAgencyCacheKey(for context: AccountContext) -> String {
        return "divo.events.isAgencyCache.\(context.account.peerId.toInt64())"
    }
    private static func cachedIsAgency(for context: AccountContext) -> Bool {
        return UserDefaults.standard.bool(forKey: isAgencyCacheKey(for: context))
    }
    private static func setCachedIsAgency(_ value: Bool, for context: AccountContext) {
        UserDefaults.standard.set(value, forKey: isAgencyCacheKey(for: context))
    }
    
    // Структура хранения состояния вкладок с поддержкой ошибок пагинации
    private struct TabState {
        var events: [EventData] = []
        var offset: Int = 0
        var isLoading: Bool = false
        var hasMore: Bool = true
        var isLoaded: Bool = false
        var scrollOffset: CGPoint = .zero
        var hasPaginationError: Bool = false // Флаг для отслеживания ошибок пагинации
    }

    private var tabStates: [TabState] = [TabState(), TabState()]
    private var selectedTabIndex: Int = 0
    private let eventsPageSize = 30

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        // Применяем последнюю известную роль до первого ответа /user/info —
        // чтобы при ошибке сети сегмент агентства всё равно отрисовался.
        self.isAgency = Self.cachedIsAgency(for: context)

        let navTheme = NavigationBarTheme(overallDarkAppearance: true, buttonColor: DivoColorPalette.primaryText, disabledButtonColor: DivoColorPalette.navBarDisabledButtonColor, primaryTextColor: DivoColorPalette.primaryTextOnDark, backgroundColor: .clear, opaqueBackgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
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
            guard let self = self else { return }
            self.tabStates = [TabState(), TabState()]
            self.fetchUserRole()
        }
        self.localeChangeObserver = NotificationCenter.default.addObserver(forName: DivoStrings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.tabBarItem.title = DivoStrings.tabEvents
            self?.tabStates = [TabState(), TabState()]
            self?.loadEventsList(tabIndex: self?.selectedTabIndex ?? 0, reset: true)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleEventAppliedStatusChanged(_:)),
            name: DivoConfig.divoEventAppliedStatusChanged,
            object: nil
        )
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
        }
    }

    // Доработанный метод получения роли с полноценным Error handling
    private func fetchUserRole() {
        self.controllerNode.phase = .loading

        Task { [weak self] in
            do {
                let response: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/info",
                    method: "GET"
                )
                let role = response.data.role ?? ""

                await MainActor.run {
                    guard let self else { return }
                    let wasAgency = self.isAgency
                    self.isAgency = role == "agency" || role == "agency_employee"
                    self.userId = response.data.id
                    Self.setCachedIsAgency(self.isAgency, for: self.context)
                    if wasAgency != self.isAgency {
                        self.updateNavigation()
                    }
                    self.loadEventsList(tabIndex: self.selectedTabIndex, reset: true)
                }
            } catch {
                divoLog("user/info failed: \(error)", level: .error)
                await MainActor.run {
                    guard let self else { return }
                    self.controllerNode.phase = .failed(networkError: isNetworkError(error))
                }
            }
        }
    }

    override public func loadDisplayNode() {
        self.displayNode = EventsControllerNode(controller: self, context: self.context, presentationData: self.presentationData)
        self.displayNodeDidLoad()

        self.controllerNode.loadMore = { [weak self] in
            self?.loadNextPage()
        }
        self.controllerNode.onTabSelected = { [weak self] index in
            self?.switchToTab(index)
        }
        self.controllerNode.createEvent = { [weak self] in
            self?.addPressed()
        }
        self.controllerNode.applyForEvent = { [weak self] eventId, cell in
            self?.applyForEvent(eventId: eventId, cell: cell)
        }
        self.controllerNode.onEventTapped = { [weak self] event in
            self?.openEventDetail(event)
        }
        
        // Связываем действие повторения запроса при полноэкранной ошибке
        self.controllerNode.onRetry = { [weak self] in
            self?.fetchUserRole()
        }
        
        // Связываем действие повторения запроса при ошибке пагинации (через снэкбар)
        self.controllerNode.onPaginationRetry = { [weak self] in
            guard let self = self else { return }
            self.tabStates[self.selectedTabIndex].hasPaginationError = false
            self.loadNextPage()
        }

        self.controllerNode.updateIsAgency(self.isAgency)
        self._ready.set(.single(true))
    }

    // Открытие детального экрана с отслеживанием изменений (Задача 2)
    private func openEventDetail(_ event: EventData) {
        let detailController = EventDetailController(
            context: self.context,
            eventId: event.id,
            isMyEvent: self.userId == event.creatorId,
            isAgency: self.isAgency
        )
        
        // Перехватываем callback при изменении статуса отклика на детальном экране
        detailController.onEventModified = { [weak self] in
            guard let self = self else { return }
            self.refreshSingleEventState(eventId: event.id)
        }
        
        self.push(detailController)
    }

    // Точечное асинхронное обновление статуса отклика для одного эвента
    private func refreshSingleEventState(eventId: Int) {
        Task {
            do {
                let response: EventFullDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/event/\(eventId)",
                    method: "GET"
                )
                guard let detail = response.data else { return }
                
                await MainActor.run {
                    let isApplied = detail.isApplied ?? false
                    
                    // Публикуем уведомление для всех экранов в приложении
                    NotificationCenter.default.post(
                        name: DivoConfig.divoEventAppliedStatusChanged,
                        object: nil,
                        userInfo: [
                            "eventId": eventId,
                            "isApplied": isApplied,
                            "appliesCount": detail.appliesCount ?? 0
                        ]
                    )
                }
            } catch {
                print("⚠️ refreshSingleEventState failed: \(error)")
            }
        }
    }

    private func switchToTab(_ index: Int) {
        guard index != selectedTabIndex else { return }

        tabStates[selectedTabIndex].scrollOffset = self.controllerNode.collectionViewContentOffset()

        selectedTabIndex = index
        tabStates[index].hasPaginationError = false
        let state = tabStates[index]
        controllerNode.hideSnackbar(animated: false)
        controllerNode.isPaginating = false

        if !state.isLoaded {
            controllerNode.setEvents([])
            controllerNode.phase = .loading
            loadEventsList(tabIndex: index, reset: true)
        } else {
            controllerNode.setEvents(state.events, scrollOffset: state.scrollOffset)
            controllerNode.phase = state.events.isEmpty ? .empty : .content
        }
    }

    private func loadNextPage() {
        let index = selectedTabIndex
        let state = tabStates[index]
        // Прерываем подгрузку, если уже есть активная ошибка пагинации
        guard !state.isLoading, state.hasMore, !state.hasPaginationError else { return }
        loadEventsList(tabIndex: index, reset: false)
    }

    // Формирование EventListRequest с фильтрацией по creatorId для таба "Мои"
    private func requestBody(tabIndex: Int, offset: Int, limit: Int) -> EventListRequest {
        if self.isAgency, tabIndex == 0 {
            return EventListRequest(offset: offset, limit: limit, creatorId: self.userId)
        } else {
            return EventListRequest(offset: offset, limit: limit, creatorId: nil)
        }
    }

    private func loadEventsList(tabIndex: Int, reset: Bool) {
        guard !tabStates[tabIndex].isLoading else { return }
        tabStates[tabIndex].isLoading = true

        let isCurrentTab = tabIndex == selectedTabIndex
        if isCurrentTab {
            if reset {
                controllerNode.phase = .loading
                controllerNode.isPaginating = false
            } else if !tabStates[tabIndex].events.isEmpty {
                controllerNode.isPaginating = true
            }
        }

        if reset {
            tabStates[tabIndex].offset = 0
            tabStates[tabIndex].hasMore = true
            tabStates[tabIndex].hasPaginationError = false
        }

        let offset = tabStates[tabIndex].offset
        let limit = eventsPageSize

        Task { [weak self] in
            do {
                let body = self?.requestBody(tabIndex: tabIndex, offset: offset, limit: limit)
                
                let response: EventListResponse = try await DivoAPIClient.shared.request(
                    path: "/event/list",
                    method: "POST",
                    body: body
                )
                let eventDataArray = self?.mapEvents(response.data.items) ?? []
                
                await MainActor.run {
                    guard let self else { return }
                    self.controllerNode.setUserId(self.userId)
                    self.controllerNode.updateIsAgency(self.isAgency)
                    if reset {
                        self.tabStates[tabIndex].events = eventDataArray
                    } else {
                        self.tabStates[tabIndex].events.append(contentsOf: eventDataArray)
                    }
                    let totalReceived = response.data.items.count
                    self.tabStates[tabIndex].offset = offset + totalReceived
                    self.tabStates[tabIndex].hasMore = totalReceived >= limit
                    self.tabStates[tabIndex].isLoading = false
                    self.tabStates[tabIndex].isLoaded = true
                    self.tabStates[tabIndex].hasPaginationError = false
                    self.didLoadEvents = true

                    if tabIndex == self.selectedTabIndex {
                        if reset {
                            self.controllerNode.setEvents(self.tabStates[tabIndex].events, scrollOffset: .zero)
                        } else {
                            self.controllerNode.appendEvents(eventDataArray)
                        }
                        self.controllerNode.isPaginating = false
                        self.controllerNode.phase = self.tabStates[tabIndex].events.isEmpty ? .empty : .content
                    }
                }
            } catch {
                divoLog("event/list failed (tab \(tabIndex)): \(error)", level: .error)
                await MainActor.run {
                    guard let self else { return }
                    self.tabStates[tabIndex].isLoading = false
                    if !reset {
                        self.tabStates[tabIndex].hasPaginationError = true
                    }
                    if tabIndex == self.selectedTabIndex {
                        self.controllerNode.isPaginating = false
                        if reset {
                            self.controllerNode.phase = .failed(networkError: isNetworkError(error))
                        } else {
                            // Пагинация — phase оставляем .content, кидаем снекбар поверх.
                            self.controllerNode.showPaginationError()
                        }
                    }
                }
            }
        }
    }
    
    // Вспомогательный маппер объектов API в EventData
    private func mapEvents(_ items: [EventListItem]) -> [EventData] {
        guard !items.isEmpty else { return [] }
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

        return items.map { item in
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
            
            let timeRemainingStr = EventDateFormatter.timeRemaining(deadline: item.applicationDeadline)
            
            let coverURL = item.files?.first?.fullUrl
            let avatarURL = item.creator?.avatar?.fullUrl
            let cityName = item.address?.city?.name ?? ""
            return EventData(
                id: item.id,
                title: item.title,
                subtitle: item.type?.title,
                profileName: item.creator?.fullName,
                timeRemaining: timeRemainingStr,
                type: item.type?.title,
                typeId: item.type?.id,
                coverPhotoURL: coverURL,
                profilePhotoURL: avatarURL,
                location: cityName,
                eventDateFormatted: dateString,
                countryFlag: Self.flag(for: item.address?.city?.countryCode),
                appliesCount: item.appliesCount,
                maxAttendees: item.maxAttendees,
                paymentTypeId: item.paymentType?.id,
                applicationDeadline: item.applicationDeadline,
                isCurrentRoleAgency: self.isAgency,
                isApplied: item.isApplied,
                creatorId: item.creator?.id,
                isVerified: item.creator?.isVerified
            )
        }
    }
    
    // Новая логика отклика на эвент из главного списка событий
    private func applyForEvent(eventId: Int, cell: EventCollectionViewCell) {
        // Инициализируем контроллер подтверждения параметров
        // Параметр eventData передаем как nil, контроллер сам загрузит его асинхронно
        let confirmationController = EventApplyConfirmationController(
            context: self.context,
            eventId: eventId,
            eventData: nil
        )
        
        // При успешном отклике обновляем главный список
        confirmationController.onApplySuccess = { [weak self] in
            guard let self = self else { return }
            self.refreshSingleEventState(eventId: eventId)
        }
        
        // Пушим контроллер в стек навигации
        self.push(confirmationController)
    }
    
    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2,
              code.allSatisfy({ $0.isASCII && $0.isLetter }) else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
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

    @objc private func handleEventAppliedStatusChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let eventId = userInfo["eventId"] as? Int,
              let isApplied = userInfo["isApplied"] as? Bool else { return }
        
        let appliesCount = userInfo["appliesCount"] as? Int
        
        // 1. Обновляем локальный кэш во всех вкладках (Мои / Все), чтобы при переключении кэш был свежим
        for tabIndex in 0..<self.tabStates.count {
            if let index = self.tabStates[tabIndex].events.firstIndex(where: { $0.id == eventId }) {
                self.tabStates[tabIndex].events[index].isApplied = isApplied
                if let appliesCount = appliesCount {
                    self.tabStates[tabIndex].events[index].appliesCount = appliesCount
                } else {
                    if let currentApplies = self.tabStates[tabIndex].events[index].appliesCount {
                        self.tabStates[tabIndex].events[index].appliesCount = max(0, currentApplies + (isApplied ? 1 : -1))
                    }
                }
            }
        }
        
        // 2. Моментально перерисовываем ячейку на экране (если она видна)
        self.controllerNode.updateEventLocally(eventId: eventId, isApplied: isApplied, appliesCount: appliesCount)
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
        if let observer = self.localeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

extension EventsController: CreateEventDelegate {
    func didCreateEvent() {
        self.loadEventsList(tabIndex: self.selectedTabIndex, reset: true)
    }
}