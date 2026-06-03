//
//  AddRosterModelController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 01.06.2026.
//

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import TelegramBaseController
import DivoUIKit
import DivoCore

public class AddRosterModelController: TelegramBaseController {
    
    private var controllerNode: AddRosterModelNode {
        return self.displayNode as! AddRosterModelNode
    }

    private let context: AccountContext
    private var presentationData: PresentationData
    private var searchDebounceTimer: Timer?
    
    private var currentQuery: String = ""
    
    private var currentSearchTask: Task<Void, Never>?
    private var loadedUsers: [RosterSearchUser] = []
    
    public var onModelAdded: ((RosterSearchUser) -> Void)?

    // MARK: - Init
    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(context: context, navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = AddRosterModelNode()
        self.displayNodeDidLoad()

        self.controllerNode.onSearchTextChanged = { [weak self] text in
            guard let self = self else { return }
            self.searchDebounceTimer?.invalidate()
            
            self.currentSearchTask?.cancel()

            let cleanQuery = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanQuery.isEmpty {
                self.currentQuery = ""
                self.loadedUsers = []
                self.controllerNode.state = .initial
                return
            }

            self.searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.currentQuery = cleanQuery
                self?.performRosterSearch(query: cleanQuery)
            }
        }

        self.controllerNode.onCloseTapped = { [weak self] in
            self?.dismiss()
        }

        self.controllerNode.onUserSelected = { [weak self] user in
            guard let self = self else { return }
            
            if case .alreadyAdded(let agencyName) = user.status {
                self.showRepresentedByAnotherAlert(agencyName: agencyName)
                return
            }
            
            self.onModelAdded?(user)
        }

        self.controllerNode.onRetry = { [weak self] in
            guard let self = self else { return }
            if !self.currentQuery.isEmpty {
                self.performRosterSearch(query: self.currentQuery)
            }
        }
    }
    
    // Метод вызова кастомного алерта
    private func showRepresentedByAnotherAlert(agencyName: String) {
        let alert = RosterAlertController(
            agencyName: agencyName
        )
        
        alert.modalPresentationStyle = .overCurrentContext
        self.navigationController?.present(alert, animated: false, completion: nil)
    }

    // MARK: - Server Request Flow
    
    private func performRosterSearch(query: String) {
        self.currentSearchTask?.cancel()
        
        self.controllerNode.state = .loading
        
        self.currentSearchTask = Task { [weak self] in
            do {
                let request = AgencySearchRequest(
                    name: query
                )
                
                let response: AgencySearchResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/search",
                    method: "POST",
                    body: request
                )
                
                guard !Task.isCancelled else { return }
                
                let profileItems = response.data.items
                
                let mappedUsers = self?.mapToRosterUsers(profileItems) ?? []
               
                await MainActor.run {
                    guard let self = self else { return }
                    
                    let currentTextFieldText = self.controllerNode.searchTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard currentTextFieldText == query else { return }

                    self.loadedUsers = mappedUsers
                    if mappedUsers.isEmpty {
                        self.controllerNode.state = .empty
                    } else {
                        self.controllerNode.state = .success(users: mappedUsers)
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    guard !Task.isCancelled else { return }
                    
                    self.controllerNode.state = .failed(networkError: true)
                }
            }
        }
    }

    private func mapToRosterUsers(_ items: [AgencySearchUserDTO]) -> [RosterSearchUser] {
        return items.compactMap { item -> RosterSearchUser? in
            let name = item.name
            let avatarUrl = item.photo?.fullUrl
            var status: RosterUserStatus
            if let agencyName = item.currentAgency?.title {
                status = .alreadyAdded(agencyName: agencyName)
            } else {
                //handle НАДО В РУЧКЕ ДОБАВИТЬ
                status = .available(handle: item.name ?? "", role: Role(apiRole: item.role).title)
            }
            
            return RosterSearchUser(
                id: item.userId ?? 0,
                name: name ?? "",
                avatarUrl: avatarUrl,
                isPremium: item.isPremium ?? false,
                status: status
            )
        }
    }
}
