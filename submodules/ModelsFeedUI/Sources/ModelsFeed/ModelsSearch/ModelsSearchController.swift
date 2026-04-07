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
        self.displayNode = ModelsSearchNode(context: self.context, presentationData: self.presentationData)
        
        // MARK: - Bindings (Связь UI и Логики)
        
        self.searchNode.onClosePressed = { [weak self] in
            if let nav = self?.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            } else {
                self?.dismiss()
            }
        }
        
        self.searchNode.onFilterPressed = {
            print("Filter button tapped - Open Filters")
        }
        
        // Запрос подсказок (Срабатывает через таймер из Node)
        self.searchNode.requestAutocomplete = {[weak self] query in
            self?.fetchAutocompleteResults(for: query)
        }
        
        // Запрос сетки (Нажат Return)
        self.searchNode.requestGridSearch = { [weak self] query in
            self?.currentQuery = query
            self?.fetchGridResults(isFirstPage: true)
        }
        
        // Пагинация сетки (Доскроллили до конца)
        self.searchNode.loadMoreGridResults = { [weak self] in
            self?.fetchGridResults(isFirstPage: false)
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }
    
    // MARK: - Network Requests
    
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
