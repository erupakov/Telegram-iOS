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
import TelegramCore
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
    }
    
    override public func loadDisplayNode() {
        self.loadGenderDictionary()
        
        self.displayNode = ModelsSearchNode(context: self.context, presentationData: self.presentationData)
        
        // MARK: - Bindings (Связь UI и Логики)
        
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
        
        self.searchNode.requestAutocomplete = {[weak self] query in
            self?.fetchAutocompleteResults(for: query)
        }
        
        self.searchNode.requestGridSearch = { [weak self] query in
            self?.currentQuery = query
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
    
    private func openFilters() {
        let filterVC = SearchFilterController(currentFilters: self.currentFilters)
        filterVC.genderOptions = self.preloadedGenders

        filterVC.onApply = { [weak self] newFilters in
            guard let self = self else { return }
            self.currentFilters = newFilters
            self.gridOffset = 0
            self.hasMoreGridResults = true
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
    
    private func loadGenderDictionary() {
        Task { @MainActor in
            do {
                let response: GenderResponse = try await DivoAPIClient.shared.request(
                    path: "/dictionary/gender",
                    method: "GET"
                )
                
                self.preloadedGenders = response.data.map {
                    FilterOptionItem(id: $0.id, title: $0.title)
                }
            } catch {
                print("❌ Error loading gender dictionary: \(error)")
                self.preloadedGenders = [
                    FilterOptionItem(id: "male", title: "Male"),
                    FilterOptionItem(id: "female", title: "Female")
                ]
            }
        }
    }
    
    private func buildRequest(limit: Int, offset: Int, query: String) -> ModelsSearchRequest {
        return ModelsSearchRequest(
            offset: offset,
            limit: limit,
            query: query
        )
    }

    private func fetchAutocompleteResults(for query: String) {
        self.currentQuery = query
        Task { @MainActor in
            do {
                let request = buildRequest(limit: 5, offset: 0, query: query)
                
                let response: ModelsSearchResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/search",
                    method: "POST",
                    body: request
                )
                
                self.searchNode.updateAutocomplete(results: response.data.items)
            } catch {
                print("Autocomplete error: \(error)")
            }
        }
    }
    
    private func fetchGridResults(isFirstPage: Bool) {
        guard !isFetchingGrid && hasMoreGridResults else { return }
        isFetchingGrid = true
        
        if isFirstPage {
            gridOffset = 0
            hasMoreGridResults = true
        }
        
        Task { @MainActor in
            defer { isFetchingGrid = false }
            
            do {
                let request = buildRequest(limit: gridLimit, offset: gridOffset, query: self.currentQuery)

                let response: ModelsSearchResponse = try await DivoAPIClient.shared.request(
                    path: "/feedline/search",
                    method: "POST",
                    body: request
                )
                
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
                print("Grid fetch error: \(error)")
            }
        }
    }
}
