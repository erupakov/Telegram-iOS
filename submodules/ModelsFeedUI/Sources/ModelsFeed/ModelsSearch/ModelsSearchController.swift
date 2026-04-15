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
        
        self.searchNode.requestAutocomplete = {[weak self] query in
            self?.fetchAutocompleteResults(for: query)
        }
        
        self.searchNode.requestGridSearch = { [weak self] query in
            self?.currentQuery = query
            self?.hasMoreGridResults = true
            self?.fetchGridResults(isFirstPage: true)
        }
        
        self.searchNode.loadMoreGridResults = { [weak self] in
            self?.fetchGridResults(isFirstPage: false)
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }
    
    private func openFaceRecognition() {
        let vc = FaceRecognitionController(context: self.context)
        (self.navigationController as? NavigationController)?.pushViewController(vc)
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
    
    // MARK: - Network Requests

    private func loadDictionaries() {
        self.dictionaryLoadFailed = false
        self.isDictionaryReady = false
        self.isDictionaryLoading = true
        self.dictionaryLoadGroup = DispatchGroup()

        self.searchNode.showFiltersButtonLoading()

        loadGenderDictionary()
        loadAppearanceDictionary()

        self.dictionaryLoadGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isDictionaryLoading = false
            self.searchNode.hideFiltersButtonLoading()

            if self.dictionaryLoadFailed {
                self.isDictionaryReady = false
                self.pendingFiltersOpen = false
                self.searchNode.showSnackbar(
                    message: DivoStrings.feedSearchFiltersLoadFailed,
                    style: .error,
                    retryAction: { [weak self] in
                        self?.openFilters()
                    }
                )
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
        
        return ModelsSearchRequest(
            offset: offset,
            limit: limit,
            query: query,
            role: role,
            modelParameters: ModelSearchParameters(
                gender: self.currentFilters.genderIds,
                age: age,
                weight: weight,
                height: height,
                waist: waist,
                shoesSize: shoesSize,
                hips: hips,
                eyeColor: self.currentFilters.eyeColor,
                skinColor: self.currentFilters.skinColor,
                hairColor: self.currentFilters.hairColor,
                hairLength: self.currentFilters.hairLength
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
                    self.searchNode.showSnackbar(
                        message: DivoStrings.feedSearchResultsLoadFailed,
                        style: .error
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
                    self.searchNode.showSnackbar(
                        message: DivoStrings.feedSearchResultsLoadFailed,
                        style: .error
                    )
                }
            }
        }
    }
}
