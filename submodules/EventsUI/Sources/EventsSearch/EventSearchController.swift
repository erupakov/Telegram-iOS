import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import DivoCore
import DivoUIKit
import TelegramPresentationData
import AccountContext
import CountrySelectionUI
import AppBundle

public final class EventsSearchController: ViewController {
    private let context: AccountContext
    
    private var searchNode: EventsSearchNode {
        return self.displayNode as! EventsSearchNode
    }
    
    // MARK: - Search State & Pagination
    private var currentQuery: String = ""
    private var isFetchingGrid = false
    private var hasMoreGridResults = true
    private var gridOffset = 0
    private let gridLimit = 20
    
    /// id и роль текущего DIVO-пользователя (из /user/info) — для «мой эвент»/isAgency, как в EventsController.
    private var currentUserId: Int?
    private var isAgency: Bool = false

    private var currentFilters = EventsSearchFilterState()
    private var preloadedEventTypes: [FilterOptionItem] = []
    private var preloadedGenders: [FilterOptionItem] = []
    private var preloadedHairLength: [FilterOptionAppearanceItem] = []
    private var preloadedHairColor: [FilterOptionAppearanceItem] = []
    private var preloadedEyeColor: [FilterOptionAppearanceItem] = []
    private var preloadedSkinColor: [FilterOptionAppearanceItem] = []
    
    private var dictionaryLoadGroup = DispatchGroup()
    private var isDictionaryReady = false
    private var dictionaryLoadFailed = false
    private var isDictionaryLoading = false
    private var pendingFiltersOpen = false

    private var currentSearchTask: Task<Void, Never>?

    public init(context: AccountContext) {
        self.context = context

        super.init(navigationBarPresentationData: nil)

        // Подписываемся на синхронизацию статусов откликов
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleEventAppliedStatusChanged(_:)),
            name: DivoConfig.divoEventAppliedStatusChanged,
            object: nil
        )
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.currentSearchTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = EventsSearchNode(context: self.context)

        // MARK: - Bindings
        
        self.searchNode.onClosePressed = { [weak self] in
            if let nav = self?.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            } else {
                self?.dismiss()
            }
        }
        
        self.searchNode.onFilterPressed = { [weak self] in
            self?.openFilters()
        }
        
        self.searchNode.onEventTapped = { [weak self] eventId, creatorId in
            self?.openEventDetailScreen(for: eventId, creatorId: creatorId)
        }
        
        self.searchNode.requestAutocomplete = { [weak self] query in
            self?.fetchAutocompleteResults(for: query)
        }
        
        self.searchNode.cancelAutocomplete = { [weak self] in
            self?.currentSearchTask?.cancel()
        }
        
        self.searchNode.requestGridSearch = { [weak self] query in
            self?.currentQuery = query
            self?.hasMoreGridResults = true
            self?.fetchGridResults(isFirstPage: true)
        }
        
        self.searchNode.loadMoreGridResults = { [weak self] in
            self?.fetchGridResults(isFirstPage: false)
        }

        self.searchNode.onSearchCleared = { [weak self] in
            guard let self else { return }
            self.currentQuery = ""
            if self.currentFilters.activeFilterCount > 0 {
                self.hasMoreGridResults = true
                self.fetchGridResults(isFirstPage: true)
            }
        }

        self.searchNode.onGridApplyTapped = { [weak self] eventId in
            self?.applyForEvent(eventId: eventId)
        }

        self.searchNode.onFiltersClearTapped = { [weak self] in
            self?.handleFiltersClear()
        }

        self.displayNodeDidLoad()

        DispatchQueue.main.async { [weak self] in
            self?.loadDictionaries()
        }

        self.fetchCurrentUserId()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }

    // MARK: - Navigation & Action Flow

    /// Тянем id+роль текущего юзера (как EventsController) — нужно, чтобы понять «мой эвент».
    /// DivoConfig.currentDivoUserId для этого ненадёжен (ставится только в auth/registration путях).
    private func fetchCurrentUserId() {
        Task { @MainActor in
            do {
                let response: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/info",
                    method: "GET"
                )
                self.currentUserId = response.data.id
                let role = response.data.role ?? ""
                self.isAgency = role == "agency" || role == "agency_employee"
            } catch {
                divoLog("EventsSearch: /user/info failed: \(error)", level: .error)
            }
        }
    }

    private func openEventDetailScreen(for eventId: Int?, creatorId: Int?) {
        // «Мой эвент» = создатель совпадает с текущим DIVO-пользователем (как в EventsController).
        let isMyEvent: Bool
        if let myId = self.currentUserId, let creatorId {
            isMyEvent = myId == creatorId
        } else {
            isMyEvent = false
        }

        let detailController = EventDetailController(
            context: self.context,
            eventId: eventId,
            isMyEvent: isMyEvent,
            isAgency: self.isAgency
        )
        
        // Подписываемся на обновление при возврате
        detailController.onEventModified = { [weak self] in
            self?.refreshSingleEventState(eventId: eventId)
        }
        
        self.push(detailController)
    }

    private func applyForEvent(eventId: Int) {
        let confirmationController = EventApplyConfirmationController(
            context: self.context,
            eventId: eventId,
            eventData: nil
        )
        
        confirmationController.onApplySuccess = { [weak self] in
            self?.refreshSingleEventState(eventId: eventId)
        }
        
        self.push(confirmationController)
    }

    private func refreshSingleEventState(eventId: Int?) {
        guard let eventId = eventId else { return }
        Task { [weak self] in
            do {
                let response: EventFullDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/event/\(eventId)",
                    method: "GET"
                )
                guard let detail = response.data else { return }
                
                await MainActor.run {
                    guard let self = self else { return }
                    let isApplied = detail.isApplied ?? false
                    
                    self.searchNode.applyGridApplyState(eventId: eventId, isApplied: isApplied)
                    
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
                divoLog("refreshSingleEventState failed: \(error)", level: .error)
            }
        }
    }

    @objc private func handleEventAppliedStatusChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let eventId = userInfo["eventId"] as? Int,
              let isApplied = userInfo["isApplied"] as? Bool else { return }
        
        self.searchNode.applyGridApplyState(eventId: eventId, isApplied: isApplied)
    }

    private func openFilters() {
        if isDictionaryReady {
            presentFiltersSheet()
            return
        }
        pendingFiltersOpen = true
        if !isDictionaryLoading {
            loadDictionaries()
        }
    }

    private func presentFiltersSheet() {
        let filterVC = EventsSearchFilterController(currentFilters: self.currentFilters)
        filterVC.eventTypeOptions = self.preloadedEventTypes
        filterVC.genderOptions = self.preloadedGenders
        filterVC.hairLengthOptions = self.preloadedHairLength
        filterVC.hairColorOptions = self.preloadedHairColor
        filterVC.eyeColorOptions = self.preloadedEyeColor
        filterVC.skinColorOptions = self.preloadedSkinColor

        filterVC.onApply = { [weak self] newFilters in
            guard let self = self else { return }
            self.currentFilters = newFilters
            self.gridOffset = 0
            self.hasMoreGridResults = true
            self.searchNode.updateActiveFiltersCount(newFilters.activeFilterCount)
            self.fetchGridResults(isFirstPage: true)
        }

        filterVC.onClose = { [weak self] newFilters in
            guard let self = self else { return }
            guard self.currentFilters != newFilters else { return }

            self.currentFilters = newFilters
            self.gridOffset = 0
            self.hasMoreGridResults = true
            self.searchNode.updateActiveFiltersCount(newFilters.activeFilterCount)
            self.fetchGridResults(isFirstPage: true)
        }

        let navVC = UINavigationController(rootViewController: filterVC)
        if #available(iOS 15.0, *) {
            if let sheet = navVC.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 24
            }
        }
        self.present(navVC, animated: true)
    }

    private func handleFiltersClear() {
        currentFilters = EventsSearchFilterState()
        searchNode.updateActiveFiltersCount(0)
        isFetchingGrid = false
        hasMoreGridResults = true
        fetchGridResults(isFirstPage: true)
    }

    // MARK: - Network Requests

    private func loadDictionaries() {
        self.dictionaryLoadFailed = false
        self.isDictionaryReady = false
        self.isDictionaryLoading = true
        self.dictionaryLoadGroup = DispatchGroup()

        if pendingFiltersOpen {
            self.searchNode.showFiltersButtonLoading()
        }

        loadGenderDictionary()
        loadAppearanceDictionary()
        loadEventTypesList(offset: 0, limit: 20)

        self.dictionaryLoadGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isDictionaryLoading = false
            self.searchNode.hideFiltersButtonLoading()

            if self.dictionaryLoadFailed {
                self.isDictionaryReady = false
                if self.pendingFiltersOpen {
                    self.pendingFiltersOpen = false
                    self.searchNode.showSnackbar(
                        message: DivoStrings.feedSearchFiltersLoadFailed,
                        style: .error,
                        retryAction: { [weak self] in
                            self?.openFilters()
                        },
                        persistent: true
                    )
                }
            } else {
                self.isDictionaryReady = true
                if self.pendingFiltersOpen {
                    self.pendingFiltersOpen = false
                    self.presentFiltersSheet()
                }
            }
        }
    }
    
    private func loadGenderDictionary() {
        dictionaryLoadGroup.enter()
        Task { @MainActor in
            defer { dictionaryLoadGroup.leave() }
            do {
                let response: GenderResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/gender",
                    method: "GET"
                )
                
                self.preloadedGenders = response.data.map {
                    FilterOptionItem(id: $0.id, title: $0.title)
                }
            } catch {
                self.dictionaryLoadFailed = true
            }
        }
    }
    
    private func loadAppearanceDictionary() {
        dictionaryLoadGroup.enter()
        Task { @MainActor in
            defer { dictionaryLoadGroup.leave() }
            do {
                let response: AppearanceDictionaryResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/appearances",
                    method: "GET"
                )
                
                self.preloadedHairLength = response.data.hairLength.map {
                    FilterOptionAppearanceItem(id: $0.id, title: $0.title)
                }
                self.preloadedHairColor = response.data.hairColor.map {
                    FilterOptionAppearanceItem(id: $0.id, title: $0.title)
                }
                self.preloadedEyeColor = response.data.eyeColor.map {
                    FilterOptionAppearanceItem(id: $0.id, title: $0.title)
                }
                self.preloadedSkinColor = response.data.skinColor.map {
                    FilterOptionAppearanceItem(id: $0.id, title: $0.title)
                }
                
            } catch {
                self.dictionaryLoadFailed = true
            }
        }
    }
    
    private func loadEventTypesList(offset: Int, limit: Int) {
        dictionaryLoadGroup.enter()
        Task { @MainActor in
            defer { dictionaryLoadGroup.leave() }
            do {
                let request = AgencyListRequest(offset: offset, limit: limit, title: nil)
                let response: AgencyListResponse = try await DivoAPIClient.shared.request(
                    path: "/event/types",
                    method: "POST",
                    body: request
                )

                self.preloadedEventTypes = response.data.items.map {
                    FilterOptionItem(id: String($0.id), title: $0.title)
                }
            } catch {
                self.dictionaryLoadFailed = true
            }
        }
    }
    
    // FIXME DIVO: бэк не поддерживает поиск/фильтры эвентов (/event/list — только offset/limit/creatorId,
    // /event/search нет, swagger 2026-06-03) → query и currentFilters сюда не прокидываются.
    // Доработать после реализации ручки на сервере (задача на доработку заведена).
    private func buildRequest(limit: Int, offset: Int, query: String? = nil) -> EventListRequest {
        return EventListRequest(
            offset: offset,
            limit: limit,
            creatorId: nil
        )
    }
    
    private func fetchAutocompleteResults(for query: String) {
        self.currentQuery = query
        currentSearchTask?.cancel()
        
        currentSearchTask = Task { @MainActor in
            do {
                let request = buildRequest(limit: 5, offset: 0, query: self.currentQuery.isEmpty ? nil : self.currentQuery)
                
                let response: EventListResponse = try await DivoAPIClient.shared.request(
                    path: "/event/list",
                    method: "POST",
                    body: request
                )
                
                guard !Task.isCancelled else { return }
                
                let eventItems = response.data.items.map { item -> EventItem in
                    let (formattedDate, formattedTime) = self.formatEventDateAndTime(dateString: item.date)
                    let city = item.address?.city?.name ?? DivoStrings.unknownCity
                    let flag = Self.flag(for: item.address?.city?.countryCode)
                    let avatarUrl = item.files?.first?.fullUrl
                    let finalAvatarUrl = avatarUrl != nil ? CDNURLHelper.convertToCDNURL(avatarUrl!)?.absoluteString : nil

                    return EventItem(
                        name: item.title ?? "Event",
                        data: formattedDate,
                        time: formattedTime,
                        countryFlag: flag,
                        city: city,
                        customAvatarURL: finalAvatarUrl,
                        originalDate: item.date,
                        eventId: item.id,
                        isApplied: item.isApplied,
                        creatorId: item.creator?.id
                    )
                }
                
                self.searchNode.updateAutocomplete(results: eventItems)
            } catch {
                if !Task.isCancelled {
                    self.searchNode.hideAutocompleteLoading()
                    let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.feedSearchResultsLoadFailed
                    self.searchNode.showSnackbar(
                        message: userMsg,
                        style: .error,
                        retryAction: { [weak self] in
                            guard let self else { return }
                            self.fetchAutocompleteResults(for: self.currentQuery)
                        },
                        persistent: true
                    )
                }
            }
        }
    }
    
    private func fetchGridResults(isFirstPage: Bool) {
        guard !isFetchingGrid && hasMoreGridResults else { return }

        currentSearchTask?.cancel()
        isFetchingGrid = true

        if isFirstPage {
            gridOffset = 0
            hasMoreGridResults = true
            self.searchNode.mode = .grid
            self.searchNode.showGridLoading(isFirstPage: true)
        } else {
            self.searchNode.showPaginationLoading()
        }

        var isFirst = isFirstPage
        let maxAutoFetches = isFirstPage ? 3 : 1

        currentSearchTask = Task { @MainActor in
            defer { isFetchingGrid = false }

            var fetchCount = 0
            while self.hasMoreGridResults && fetchCount < maxAutoFetches {
                fetchCount += 1
                do {
                    let request = buildRequest(limit: gridLimit, offset: gridOffset, query: self.currentQuery.isEmpty ? nil : self.currentQuery)

                    let response: EventListResponse = try await DivoAPIClient.shared.request(
                        path: "/event/list",
                        method: "POST",
                        body: request
                    )

                    guard !Task.isCancelled else { return }

                    let events = self.mapEvents(response.data.items)
                    let totalCount = response.data.pagination?.meta?.totalCount

                    self.searchNode.updateGrid(
                        results: events,
                        totalCount: totalCount ?? 0,
                        isFirstPage: isFirst,
                        query: self.currentQuery
                    )

                    self.gridOffset += response.data.items.count
                    self.hasMoreGridResults = self.gridOffset < totalCount ?? 0
                    isFirst = false

                    if events.count >= self.gridLimit || !self.hasMoreGridResults {
                        break
                    }

                } catch {
                    if !Task.isCancelled {
                        let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.feedSearchResultsLoadFailed
                        if isFirst {
                            self.searchNode.showGridError()
                            self.searchNode.showSnackbar(
                                message: userMsg,
                                style: .error,
                                retryAction: { [weak self] in
                                    guard let self else { return }
                                    self.fetchGridResults(isFirstPage: true)
                                },
                                persistent: true
                            )
                        } else {
                            self.searchNode.showPaginationError()
                            self.searchNode.showSnackbar(
                                message: userMsg,
                                style: .error,
                                retryAction: { [weak self] in
                                    guard let self else { return }
                                    self.fetchGridResults(isFirstPage: false)
                                },
                                persistent: true
                            )
                        }
                    }
                    break
                }
            }
        }
    }

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
                isCurrentRoleAgency: DivoConfig.currentUserRole == .agency,
                isApplied: item.isApplied,
                creatorId: item.creator?.id,
                isVerified: item.creator?.isVerified
            )
        }
    }

    private func formatEventDateAndTime(dateString: String?) -> (date: String, time: String) {
        guard let dateString = dateString else {
            return (DivoStrings.tbd, DivoStrings.tbd)
        }

        let serverFormatter = DateFormatter()
        serverFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = serverFormatter.date(from: dateString) else {
            return (dateString, "")
        }

        let languageCode = DivoStrings.current.rawValue
        let localeIdentifierByLanguage: [String: String] = [
            "ru": "ru_RU",
            "en": "en_US",
            "pt": "pt_PT",
            "es": "es_ES",
            "zh": "zh_CN"
        ]
        let locale = Locale(identifier: localeIdentifierByLanguage[languageCode] ?? "en_US")

        let dateUIFormatter = DateFormatter()
        dateUIFormatter.locale = locale
        dateUIFormatter.dateFormat = "LLLL d"
        let rawFormattedDate = dateUIFormatter.string(from: date)
        let formattedDate: String = {
            guard let first = rawFormattedDate.first else { return rawFormattedDate }
            return String(first).uppercased(with: locale) + rawFormattedDate.dropFirst()
        }()

        let timeUIFormatter = DateFormatter()
        timeUIFormatter.locale = locale
        switch languageCode {
        case "en":
            timeUIFormatter.dateFormat = "h:mm a"
        case "zh":
            timeUIFormatter.dateFormat = "a h:mm"
        case "ru", "pt", "es":
            timeUIFormatter.dateFormat = "HH:mm"
        default:
            timeUIFormatter.dateFormat = "HH:mm"
        }
        let formattedTime = timeUIFormatter.string(from: date)

        return (formattedDate, formattedTime)
    }

    private static func flag(for countryCode: String?) -> String {
        guard let code = countryCode, code.count == 2,
              code.allSatisfy({ $0.isASCII && $0.isLetter }) else { return "" }
        return code.uppercased().unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(127397 + scalar.value)!)
        }
    }
}
