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
        
        self.displayNodeDidLoad()

        DispatchQueue.main.async { [weak self] in
            self?.loadDictionaries()
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }

    
    private func openFaceRecognition() {
        let alert = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )

        let titleAttr = NSAttributedString(
            string: DivoStrings.faceRecognitionSheetTitle,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: DivoColorPalette.primaryText
            ]
        )
        alert.setValue(titleAttr, forKey: "attributedTitle")

        let messageAttr = NSAttributedString(
            string: DivoStrings.faceRecognitionSheetSubtitle,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: DivoColorPalette.primaryText.withAlphaComponent(0.6)
            ]
        )
        alert.setValue(messageAttr, forKey: "attributedMessage")

        let takePhotoAction = UIAlertAction(title: DivoStrings.faceRecognitionTakePhoto, style: .default) { _ in
            // TODO: open camera for face recognition
        }
        takePhotoAction.setValue(DivoColorPalette.primaryText, forKey: "titleTextColor")
        alert.addAction(takePhotoAction)

        let chooseAction = UIAlertAction(title: DivoStrings.faceRecognitionChooseFromLibrary, style: .default) { _ in
            // TODO: open photo library for face recognition
        }
        chooseAction.setValue(DivoColorPalette.primaryText, forKey: "titleTextColor")
        alert.addAction(chooseAction)

        let divoAction = UIAlertAction(title: DivoStrings.faceRecognitionUseDivoPhoto, style: .default) { _ in
            // TODO: pick DIVO profile photo for face recognition
        }
        divoAction.setValue(DivoColorPalette.primaryText, forKey: "titleTextColor")
        alert.addAction(divoAction)

        let cancelAction = UIAlertAction(title: DivoStrings.cancel, style: .cancel)
        cancelAction.setValue(DivoColorPalette.accent, forKey: "titleTextColor")
        alert.addAction(cancelAction)

        self.view.window?.rootViewController?.present(alert, animated: true)
    }

    private func openModelScreen(for user: SearchUserDTO) {
        let mainImageURL = user.searchImage?.fullUrl
            .flatMap { CDNURLHelper.convertToCDNURL($0) }

        let profileModel = ProfileModel(
            name: user.title,
            age: user.user?.age ?? 0,
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
            title: item.title,
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
            defer { isFetchingGrid = false }
            isFetchingGrid = true

            do {
                let request = buildRequest(limit: gridLimit, offset: 0, query: currentQuery.isEmpty ? nil : currentQuery)
                let response: ModelsSearchResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/search",
                    method: "POST",
                    body: request
                )

                guard !Task.isCancelled else { return }

                let totalCount = response.data.pagination.meta.totalCount
                self.searchNode.updateGrid(
                    results: response.data.items,
                    totalCount: totalCount,
                    isFirstPage: true,
                    query: self.currentQuery
                )
                self.gridOffset = response.data.items.count
                self.hasMoreGridResults = self.gridOffset < totalCount
            } catch {
                guard !Task.isCancelled else { return }
                self.currentFilters = oldFilters
                self.searchNode.updateActiveFiltersCount(oldCount)
                self.searchNode.showGridError()
                self.searchNode.showSnackbar(
                    message: DivoStrings.feedSearchResultsLoadFailed,
                    style: .error,
                    retryAction: { [weak self] in
                        self?.handleFiltersClear()
                    },
                    persistent: true
                )
            }
        }
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

        return ModelsSearchRequest(
            offset: offset,
            limit: limit,
            query: query,
            role: role,
            modelParameters: ModelSearchParameters(
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
            )
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
                
                self.searchNode.updateAutocomplete(results: response.data.items)
            } catch {
                if !Task.isCancelled {
                    self.searchNode.hideAutocompleteLoading()
                    self.searchNode.showSnackbar(
                        message: DivoStrings.feedSearchResultsLoadFailed,
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

        currentSearchTask = Task { @MainActor in
            defer { isFetchingGrid = false }

            do {
                let request = buildRequest(limit: gridLimit, offset: gridOffset, query: self.currentQuery.isEmpty ? nil : self.currentQuery)

                let response: ModelsSearchResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/search",
                    method: "POST",
                    body: request
                )

                guard !Task.isCancelled else { return }

                let totalCount = response.data.pagination.meta.totalCount

                self.searchNode.updateGrid(
                    results: response.data.items,
                    totalCount: totalCount,
                    isFirstPage: isFirstPage,
                    query: self.currentQuery
                )

                self.gridOffset += response.data.items.count
                self.hasMoreGridResults = self.gridOffset < totalCount

            } catch {
                if !Task.isCancelled {
                    if isFirstPage {
                        self.searchNode.showGridError()
                        self.searchNode.showSnackbar(
                            message: DivoStrings.feedSearchResultsLoadFailed,
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
                            message: DivoStrings.feedSearchResultsLoadFailed,
                            style: .error,
                            retryAction: { [weak self] in
                                guard let self else { return }
                                self.fetchGridResults(isFirstPage: false)
                            },
                            persistent: true
                        )
                    }
                }
            }
        }
    }
}
