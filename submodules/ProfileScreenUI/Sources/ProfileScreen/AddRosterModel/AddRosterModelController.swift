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

    /// Наше агентство. «Уже добавлен» показываем только для моделей из ЕГО ростера — `currentAgency`
    /// из поиска не гарантирует, что модель реально в ростере (рассинхрон статуса).
    private let agencyId: Int?
    /// userId моделей нашего ростера; nil — не загрузился (тогда фолбэк на сверку currentAgency.id).
    private var rosterUserIdsTask: Task<Set<Int>?, Never>?

    // MARK: - Init
    public init(context: AccountContext, agencyId: Int?) {
        self.context = context
        self.agencyId = agencyId
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(context: context, navigationBarPresentationData: nil)

        if let agencyId {
            self.rosterUserIdsTask = Task {
                do {
                    return try await AgencyRoster.fetchUserIds(agencyId: agencyId)
                } catch {
                    divoLog("[ROSTER] не удалось загрузить ростер агентства: \(error)", level: .error)
                    return nil
                }
            }
        }
    }

    deinit {
        self.rosterUserIdsTask?.cancel()
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
            
            switch user.status {
            case .representedByAnother(let agencyName):
                self.showRepresentedByAnotherAlert(agencyName: agencyName)
                return
            case .inYourRoster:
                return
            case .available:
                break
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

    public override func viewDidLoad() {
        super.viewDidLoad()
        // DIVO свёрстан под светлую палитру — форсим .light
        overrideUserInterfaceStyle = .light
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
                let rosterUserIds: Set<Int>? = await self?.rosterUserIdsTask?.value
                
                let mappedUsers = self?.mapToRosterUsers(profileItems, rosterUserIds: rosterUserIds) ?? []
               
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
                    
                    if isNetworkError(error) {
                        self.controllerNode.state = .failed(networkError: true)
                    } else if let message = (error as? DivoAPIError)?.userFacingMessage, !message.isEmpty {
                        self.controllerNode.state = .idle
                        self.controllerNode.showSnackbar(message: message, style: .error)
                    } else {
                        self.controllerNode.state = .failed(networkError: false)
                    }
                }
            }
        }
    }

    private func mapToRosterUsers(_ items: [AgencySearchUserDTO], rosterUserIds: Set<Int>?) -> [RosterSearchUser] {
        return items.compactMap { item -> RosterSearchUser? in
            guard let userId = item.userId else { return nil }
            let avatarUrl = item.photo?.fullUrl
            let status: RosterUserStatus
            let currentAgencyIsOurs = item.currentAgency?.id != nil && item.currentAgency?.id == self.agencyId
            if let rosterUserIds, rosterUserIds.contains(userId) {
                // Реально в нашем ростере.
                status = .inYourRoster
            } else if rosterUserIds == nil, currentAgencyIsOurs {
                // Ростер не загрузился — фолбэк на currentAgency нашего агентства.
                status = .inYourRoster
            } else if let agencyName = item.currentAgency?.title, !currentAgencyIsOurs {
                status = .representedByAnother(agencyName: agencyName)
            } else {
                // currentAgency указывает на нас, но в ростере модели нет — рассинхрон: даём добавить.
                // FIXME DIVO: handle приходит как имя — ждём отдельное поле от бэка
                status = .available(handle: item.name ?? "", role: Role(apiRole: item.role).title)
            }
            
            return RosterSearchUser(
                id: userId,
                name: item.name ?? "",
                avatarUrl: avatarUrl,
                isPremium: item.isPremium ?? false,
                status: status
            )
        }
    }
}
