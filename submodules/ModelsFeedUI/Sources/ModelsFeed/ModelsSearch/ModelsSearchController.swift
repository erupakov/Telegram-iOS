//
//  ModelsSearchController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.04.2026.
//

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
import ProfileScreenUI
import FaceSearchUI
import PhotosUI
import AVFoundation

public class ModelsSearchController: ViewController {
    private let context: AccountContext
    
    private var searchNode: ModelsSearchNode {
        return self.displayNode as! ModelsSearchNode
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    // MARK: - Search State & Pagination
    private var currentQuery: String = ""
    private var isFetchingGrid = false
    private var hasMoreGridResults = true
    private var gridOffset = 0
    private let gridLimit = 20
    
    private var currentFilters = SearchFilterState()
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
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: nil)

        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
            }
        }).strict()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.currentSearchTask?.cancel()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ModelsSearchNode(context: self.context, presentationData: self.presentationData)

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

        self.searchNode.onFaceScanPressed = { [weak self] in
            self?.openFaceRecognition()
        }
        
        self.searchNode.onUserTapped = { [weak self] user in
            self?.openModelScreen(for: user)
        }
        
        self.searchNode.requestAutocomplete = {[weak self] query in
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

        self.searchNode.onGridLikeTapped = { [weak self] feedId, isLiked in
            self?.handleGridLike(feedId: feedId, isLiked: isLiked)
        }

        self.searchNode.onGridSaveTapped = { [weak self] userId, isSaved in
            self?.handleGridSave(userId: userId, isSaved: isSaved)
        }

        self.searchNode.onGridShareTapped = { [weak self] item, image in
            self?.handleGridShare(item: item, image: image)
        }

        self.searchNode.onFiltersClearTapped = { [weak self] in
            self?.handleFiltersClear()
        }

        self.searchNode.onFaceSearchHistorySeeAll = { [weak self] in
            self?.handleFaceSearchHistorySeeAll()
        }

        self.searchNode.onFaceSearchHistoryItemTapped = { [weak self] item in
            self?.handleFaceSearchHistoryItemTapped(item)
        }

        self.displayNodeDidLoad()

        DispatchQueue.main.async { [weak self] in
            self?.loadDictionaries()
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
        reloadFaceSearchHistory()
    }

    
    private func openFaceRecognition() {
        let theme = ActionSheetControllerTheme(
            dimColor: UIColor(white: 0, alpha: 0.5),
            backgroundType: .light,
            itemBackgroundColor: DivoColorPalette.cardBackground,
            itemHighlightedBackgroundColor: DivoColorPalette.screenBackground,
            standardActionTextColor: DivoColorPalette.primaryText,
            destructiveActionTextColor: DivoColorPalette.accent,
            disabledActionTextColor: DivoColorPalette.disabledText,
            primaryTextColor: DivoColorPalette.primaryText,
            secondaryTextColor: DivoColorPalette.secondaryText,
            controlAccentColor: DivoColorPalette.accent,
            controlColor: DivoColorPalette.secondaryText,
            switchFrameColor: DivoColorPalette.separatorSystem,
            switchContentColor: DivoColorPalette.accent,
            switchHandleColor: DivoColorPalette.cardBackground,
            baseFontSize: 17.0
        )
        let actionSheet = ActionSheetController(theme: theme)

        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                DivoActionSheetHeaderItem(title: DivoStrings.faceRecognitionSheetTitle, subtitle: DivoStrings.faceRecognitionSheetSubtitle),
                ActionSheetButtonItem(title: DivoStrings.faceRecognitionTakePhoto, color: .accent) { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.handleFaceSearchSource(.camera)
                },
                ActionSheetButtonItem(title: DivoStrings.faceRecognitionChooseFromLibrary, color: .accent) { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.handleFaceSearchSource(.gallery)
                },
                ActionSheetButtonItem(title: DivoStrings.faceRecognitionUseDivoPhoto, color: .accent) { [weak self, weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self?.openProfileSearchSheet()
                    }
                }
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: DivoStrings.cancel, color: .destructive, font: .bold) { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                }
            ])
        ])

        let presenter = self.activeFaceSearchController ?? self
        presenter.present(actionSheet, in: .window(.root))
    }

    private enum FaceSearchSource {
        case camera
        case gallery
    }

    private var pendingFaceSearchSource: FaceSearchSource?
    private weak var activeFaceSearchController: FaceSearchController?

    private func handleFaceSearchSource(_ source: FaceSearchSource) {
        if FaceSearchInfoDialog.wasShown {
            openPhotoPicker(source)
        } else {
            pendingFaceSearchSource = source
            let dialog = FaceSearchInfoDialog()
            dialog.modalPresentationStyle = .overFullScreen
            dialog.modalTransitionStyle = .crossDissolve
            dialog.onDismissed = { [weak self] in
                guard let self, let source = self.pendingFaceSearchSource else { return }
                self.pendingFaceSearchSource = nil
                self.openPhotoPicker(source)
            }
            self.view.window?.rootViewController?.present(dialog, animated: false)
        }
    }

    private var presentingWindow: UIWindow? {
        self.view.window ?? activeFaceSearchController?.view.window
    }

    private func openPhotoPicker(_ source: FaceSearchSource) {
        guard let rootVC = presentingWindow?.rootViewController else { return }
        switch source {
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.delegate = self
                rootVC.present(picker, animated: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.openPhotoPicker(.camera)
                        }
                    }
                }
            case .denied, .restricted:
                let alert = UIAlertController(
                    title: DivoStrings.cameraAccessDeniedTitle,
                    message: DivoStrings.cameraAccessDeniedMessage,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: DivoStrings.openSettings, style: .default) { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                })
                alert.addAction(UIAlertAction(title: DivoStrings.cancel, style: .cancel))
                rootVC.present(alert, animated: true)
            @unknown default:
                break
            }
        case .gallery:
            if #available(iOS 14, *) {
                var config = PHPickerConfiguration()
                config.filter = .images
                config.selectionLimit = 1
                let picker = PHPickerViewController(configuration: config)
                picker.delegate = self
                picker.view.tintColor = DivoColorPalette.accent
                rootVC.present(picker, animated: true)
            } else {
                let picker = UIImagePickerController()
                picker.sourceType = .photoLibrary
                picker.delegate = self
                rootVC.present(picker, animated: true)
            }
        }
    }

    private func openProfileSearchSheet() {
        let sheet = DivoProfileSearchSheetController()
        sheet.onProfileSelected = { [weak self] user in
            self?.loadProfilePhotoAndOpenFaceSearch(for: user)
        }
        presentingWindow?.rootViewController?.present(sheet, animated: true)
    }

    private func loadProfilePhotoAndOpenFaceSearch(for user: SearchUserDTO) {
        guard let urlString = user.searchImage?.fullUrl,
              let url = CDNURLHelper.convertToCDNURL(urlString) else {
            self.searchNode.showSnackbar(
                message: DivoStrings.faceRecognitionProfilePhotoLoadFailed,
                style: .error
            )
            return
        }

        FaceSearchPhotoLoader.loadProfilePhoto(
            url: url,
            host: self.view.window?.rootViewController?.view
        ) { [weak self] image in
            guard let self else { return }
            guard let image else {
                self.searchNode.showSnackbar(
                    message: DivoStrings.faceRecognitionProfilePhotoLoadFailed,
                    style: .error,
                    retryAction: { [weak self] in self?.loadProfilePhotoAndOpenFaceSearch(for: user) },
                    persistent: true
                )
                return
            }
            self.openFaceSearchScreen(with: image)
        }
    }

    private func openFaceSearchScreen(with image: UIImage) {
        if let existing = activeFaceSearchController, existing.navigationController != nil {
            existing.updateImage(image)
        } else {
            activeFaceSearchController = nil
            let controller = FaceSearchController(context: self.context, image: image)
            controller.onChangePhoto = { [weak self] in
                self?.openFaceRecognition()
            }
            controller.onOpenProfile = { [weak self] result in
                self?.openFaceSearchProfile(for: result)
            }
            activeFaceSearchController = controller
            (self.navigationController as? NavigationController)?.pushViewController(controller, animated: true)
        }
    }

    private func openModelScreen(for user: SearchUserDTO) {
        let mainImageURL = user.searchImage?.fullUrl
            .flatMap { CDNURLHelper.convertToCDNURL($0) }

        let profileModel = ProfileModel(
            name: user.title ?? user.user?.fullName ?? "",
            age: user.user?.age,
            location: user.user?.city?.name ?? "",
            isVerified: false,
            likesCount: "\(user.likesCount ?? 0)",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            userId: user.user?.id,
            role: user.user?.role,
            mainImageURL: mainImageURL,
            avatarImageURL: mainImageURL
        )
        let detailController = PublicProfileScreenController(context: self.context, model: profileModel)
        (self.navigationController as? NavigationController)?.pushViewController(detailController, animated: true)
    }

    private func openFaceSearchProfile(for result: FRSearchResult) {
        let controller = PublicProfileScreenController(context: self.context, model: ProfileModel(faceSearchResult: result))
        (self.navigationController as? NavigationController)?.pushViewController(controller, animated: true)
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
        let filterVC = SearchFilterController(currentFilters: self.currentFilters)
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
        self.view.window?.rootViewController?.present(navVC, animated: true)
    }
    
    // MARK: - Grid Actions

    private func handleGridLike(feedId: Int, isLiked: Bool) {
        let oldItem = searchNode.gridItem(forFeedId: feedId)
        let oldIsLiked = oldItem?.isLikedByUser ?? false
        let oldLikesCount = oldItem?.likesCount ?? 0
        let newLikesCount = max(0, oldLikesCount + (isLiked ? 1 : -1))

        searchNode.applyGridLikeState(feedId: feedId, isLiked: isLiked, likesCount: newLikesCount)

        let path = isLiked ? "/feedline/like" : "/feedline/unlike"
        let body = FollowRequest(id: feedId)

        Task { @MainActor in
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
            } catch {
                self.searchNode.applyGridLikeState(feedId: feedId, isLiked: oldIsLiked, likesCount: oldLikesCount)
            }
        }
    }

    private func handleGridSave(userId: Int, isSaved: Bool) {
        let oldItem = searchNode.gridItem(forUserId: userId)
        let oldIsSaved = oldItem?.isFavoriteByUser ?? false

        searchNode.applyGridSaveState(userId: userId, isSaved: isSaved)

        let path = isSaved ? "/follower/follow" : "/follower/unfollow"
        let body = FollowRequest(id: userId)

        Task { @MainActor in
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: path,
                    method: "POST",
                    body: body
                )
            } catch {
                self.searchNode.applyGridSaveState(userId: userId, isSaved: oldIsSaved)
            }
        }
    }

    private func handleGridShare(item: SearchUserDTO, image: UIImage?) {
        guard let userId = item.user?.id else { return }
        let shareURL = URL(string: "\(DivoConfig.shareBaseURL)/profile/\(userId)")!
        let shareItem = DivoShareItemSource(
            url: shareURL,
            title: item.title ?? item.user?.fullName ?? "",
            subtitle: item.user?.roleLabel ?? "",
            image: image
        )
        let activityVC = UIActivityViewController(activityItems: [shareItem], applicationActivities: nil)
        self.view.window?.rootViewController?.present(activityVC, animated: true)
    }

    private func handleFiltersClear() {
        let oldFilters = currentFilters
        let oldCount = oldFilters.activeFilterCount

        currentFilters = SearchFilterState()
        searchNode.updateActiveFiltersCount(0)

        gridOffset = 0
        hasMoreGridResults = true
        isFetchingGrid = false

        searchNode.showGridLoading(isFirstPage: true)

        currentSearchTask?.cancel()
        currentSearchTask = Task { @MainActor in
            isFetchingGrid = true

            do {
                let request = buildRequest(limit: gridLimit, offset: 0, query: currentQuery.isEmpty ? nil : currentQuery)
                let response: ModelsSearchResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/search",
                    method: "POST",
                    body: request
                )

                guard !Task.isCancelled else { isFetchingGrid = false; return }

                let profileItems = response.data.items.filter { $0.entity == "users" }
                let totalCount = response.data.pagination.meta.totalCount
                self.searchNode.updateGrid(
                    results: profileItems,
                    totalCount: totalCount,
                    isFirstPage: true,
                    query: self.currentQuery
                )
                self.gridOffset = response.data.items.count
                self.hasMoreGridResults = self.gridOffset < totalCount
                self.isFetchingGrid = false

                if profileItems.count < self.gridLimit && self.hasMoreGridResults {
                    self.fetchGridResults(isFirstPage: false)
                }
            } catch {
                self.isFetchingGrid = false
                guard !Task.isCancelled else { return }
                self.currentFilters = oldFilters
                self.searchNode.updateActiveFiltersCount(oldCount)
                self.searchNode.showGridError()
                let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.feedSearchResultsLoadFailed
                self.searchNode.showSnackbar(
                    message: userMsg,
                    style: .error,
                    retryAction: { [weak self] in
                        self?.handleFiltersClear()
                    },
                    persistent: true
                )
            }
        }
    }

    // MARK: - Face Search History

    private func reloadFaceSearchHistory() {
        let items = FaceSearchHistoryStorage.shared.loadRecent(3)
        searchNode.updateFaceSearchHistory(items)
    }

    private func handleFaceSearchHistorySeeAll() {
        let controller = FaceSearchHistoryController(context: self.context)
        controller.onItemTapped = { [weak self] item in
            self?.replayFaceSearch(item)
        }
        controller.onStartFaceSearch = { [weak self] in
            self?.openFaceRecognition()
        }
        (self.navigationController as? NavigationController)?.pushViewController(controller, animated: true)
    }

    private func handleFaceSearchHistoryItemTapped(_ item: FaceSearchHistoryItem) {
        replayFaceSearch(item)
    }

    private func replayFaceSearch(_ item: FaceSearchHistoryItem) {
        let imageData: Data
        let sourceImage: UIImage?

        if let srcData = FaceSearchHistoryStorage.shared.sourceImageData(for: item) {
            imageData = srcData
            sourceImage = UIImage(data: srcData)
        } else if let faceImage = FaceSearchHistoryStorage.shared.faceImage(for: item),
                  let faceData = faceImage.jpegData(compressionQuality: 0.85) {
            imageData = faceData
            sourceImage = faceImage
        } else {
            return
        }

        let filters = Self.reconstructFilters(from: item)

        let controller = FaceSearchResultsController(
            context: self.context,
            imageData: imageData,
            results: [],
            sourceImage: sourceImage,
            faceBBox: item.faceBBox,
            faceIndex: item.faceIndex,
            initialFilters: filters,
            historyEntryId: item.id,
            needsInitialLoad: true
        )
        controller.onOpenProfile = { [weak self] result in
            self?.openFaceSearchProfile(for: result)
        }
        (self.navigationController as? NavigationController)?.pushViewController(controller, animated: true)
    }

    private static func reconstructFilters(from item: FaceSearchHistoryItem) -> FaceSearchFilterState {
        var filters = FaceSearchFilterState()
        filters.similarity = Double(item.similarityPercent) / 100.0

        if let roleStr = item.searchFields["role"], !roleStr.isEmpty {
            filters.roleIds = roleStr.components(separatedBy: ",")
        }
        if let countryStr = item.searchFields["country_ids"], !countryStr.isEmpty {
            filters.countryIds = countryStr.components(separatedBy: ",")
        }
        if let ageFrom = item.searchFields["age_from"].flatMap(Int.init),
           let ageTo = item.searchFields["age_to"].flatMap(Int.init) {
            filters.ageRange = ageFrom...ageTo
        }
        if let hFrom = item.searchFields["height_from"].flatMap(Double.init),
           let hTo = item.searchFields["height_to"].flatMap(Double.init) {
            filters.heightRange = hFrom...hTo
        }
        if let wFrom = item.searchFields["waist_from"].flatMap(Double.init),
           let wTo = item.searchFields["waist_to"].flatMap(Double.init) {
            filters.waistRange = wFrom...wTo
        }
        if let hipFrom = item.searchFields["hips_from"].flatMap(Double.init),
           let hipTo = item.searchFields["hips_to"].flatMap(Double.init) {
            filters.hipsRange = hipFrom...hipTo
        }
        if let shFrom = item.searchFields["shoes_size_from"].flatMap(Double.init),
           let shTo = item.searchFields["shoes_size_to"].flatMap(Double.init) {
            filters.shoeSizeRange = shFrom...shTo
        }
        if let hairStr = item.searchFields["hair_length"], !hairStr.isEmpty {
            filters.hairLength = hairStr.components(separatedBy: ",").compactMap(Int.init)
        }

        return filters
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
    
    private func buildRequest(limit: Int, offset: Int, query: String? = nil) -> ModelsSearchRequest {
        
        let age = self.currentFilters.ageRange?.upperBound == nil ? nil : RangeParamInt(from: self.currentFilters.ageRange?.lowerBound, to: self.currentFilters.ageRange?.upperBound)
        let weight = self.currentFilters.weightRange?.upperBound == nil ? nil : RangeParamDouble(from: self.currentFilters.weightRange?.lowerBound, to: self.currentFilters.weightRange?.upperBound)
        let height = self.currentFilters.heightRange?.upperBound == nil ? nil : RangeParamDouble(from: self.currentFilters.heightRange?.lowerBound, to: self.currentFilters.heightRange?.upperBound)
        let waist = self.currentFilters.waistRange?.upperBound == nil ? nil : RangeParamDouble(from: self.currentFilters.waistRange?.lowerBound, to: self.currentFilters.waistRange?.upperBound)
        let shoesSize = self.currentFilters.shoeSizeRange?.upperBound == nil ? nil : RangeParamDouble(from: self.currentFilters.shoeSizeRange?.lowerBound, to: self.currentFilters.shoeSizeRange?.upperBound)
        let hips = self.currentFilters.hipsRange?.upperBound == nil ? nil : RangeParamDouble(from: self.currentFilters.hipsRange?.lowerBound, to: self.currentFilters.hipsRange?.upperBound)
        let role = self.currentFilters.roleIds.isEmpty ? nil : self.currentFilters.roleIds
        
        let gender = self.currentFilters.genderIds.isEmpty ? nil : self.currentFilters.genderIds
        let eyeColor = self.currentFilters.eyeColor?.isEmpty == true ? nil : self.currentFilters.eyeColor
        let skinColor = self.currentFilters.skinColor?.isEmpty == true ? nil : self.currentFilters.skinColor
        let hairColor = self.currentFilters.hairColor?.isEmpty == true ? nil : self.currentFilters.hairColor
        let hairLength = self.currentFilters.hairLength?.isEmpty == true ? nil : self.currentFilters.hairLength

        let hasModelParams = gender != nil || age != nil || weight != nil || height != nil || waist != nil || shoesSize != nil || hips != nil || eyeColor != nil || skinColor != nil || hairColor != nil || hairLength != nil

        return ModelsSearchRequest(
            offset: offset,
            limit: limit,
            query: query,
            role: role,
            withoutNfts: true,
            modelParameters: hasModelParams ? ModelSearchParameters(
                gender: gender,
                age: age,
                weight: weight,
                height: height,
                waist: waist,
                shoesSize: shoesSize,
                hips: hips,
                eyeColor: eyeColor,
                skinColor: skinColor,
                hairColor: hairColor,
                hairLength: hairLength
            ) : nil
        )
    }
    
    private func fetchAutocompleteResults(for query: String) {
        self.currentQuery = query
        
        currentSearchTask?.cancel()
        
        currentSearchTask = Task { @MainActor in
            do {
                let request = buildRequest(limit: 5, offset: 0, query: self.currentQuery.isEmpty ? nil : self.currentQuery)
                
                let response: ModelsSearchResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/search",
                    method: "POST",
                    body: request
                )
                
                guard !Task.isCancelled else { return }
                
                let profileItems = response.data.items.filter { $0.entity == "users" }
                self.searchNode.updateAutocomplete(results: profileItems)
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

                    let response: ModelsSearchResponse = try await DivoAPIClient.shared.request(
                        path: "/feedline/search",
                        method: "POST",
                        body: request
                    )

                    guard !Task.isCancelled else { return }

                    let profileItems = response.data.items.filter { $0.entity == "users" }
                    let totalCount = response.data.pagination.meta.totalCount

                    self.searchNode.updateGrid(
                        results: profileItems,
                        totalCount: totalCount,
                        isFirstPage: isFirst,
                        query: self.currentQuery
                    )

                    self.gridOffset += response.data.items.count
                    self.hasMoreGridResults = self.gridOffset < totalCount
                    isFirst = false

                    if profileItems.count >= self.gridLimit || !self.hasMoreGridResults {
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
}

// MARK: - PHPickerViewControllerDelegate

@available(iOS 14, *)
extension ModelsSearchController: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.openFaceSearchScreen(with: image)
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ModelsSearchController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        self.openFaceSearchScreen(with: image)
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
