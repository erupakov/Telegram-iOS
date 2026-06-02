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
    private var isLoading: Bool = false

    // Callback завершения выбора модели
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

        // 1. Обработка ввода в поисковую строку с задержкой (Debounce)
        self.controllerNode.onSearchTextChanged = { [weak self] text in
            guard let self = self else { return }
            self.searchDebounceTimer?.invalidate()

            let cleanQuery = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanQuery.isEmpty {
                self.currentQuery = ""
                self.controllerNode.state = .initial
                return
            }

            self.searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.currentQuery = cleanQuery
                self?.performRosterSearch(query: cleanQuery)
            }
        }

        // 2. Закрытие экрана
        self.controllerNode.onCloseTapped = { [weak self] in
            self?.dismiss()
        }

        // 3. Выбор пользователя из результатов поиска
        self.controllerNode.onUserSelected = { [weak self] user in
            guard let self = self else { return }
            
            // Если модель уже добавлена в наш ростер, просто игнорируем
            if case .alreadyAdded(let agencyName) = user.status {
                self.showRepresentedByAnotherAlert(agencyName: agencyName)
                return
            }
            
            self.onModelAdded?(user)
        }

        // 4. Повтор запроса при ошибке
        self.controllerNode.onRetry = { [weak self] in
            guard let self = self else { return }
            if !self.currentQuery.isEmpty {
                self.performRosterSearch(query: self.currentQuery)
            }
        }
    }
    
    // Метод вызова родного закругленного алерта Telegram
// Метод вызова родного закругленного алерта Telegram
    private func showRepresentedByAnotherAlert(agencyName: String) {
        // 1. Получаем тему для алерта на основе текущей темы презентации
        // let alertTheme = defaultAlertControllerTheme(self.presentationData.theme)
        
        // 2. Создаем стилизованные AttributedString (используя встроенные расширения Telegram)
        // let titleAttr = NSAttributedString(
        //     string: "This model is currently represented by \(agencyName)",
        //     font: Font.bold(17),
        //     textColor: .red//self.presentationData.theme.actionSheet.primaryActionTextColor
        // )
        
        // let textAttr = NSAttributedString(
        //     string: "You cannot add her to your roster while she is with another agency.",
        //     font: Font.regular(13),
        //     textColor: .red //self.presentationData.theme.actionSheet.secondaryActionTextColor
        // )
        
        // // 3. Собираем алерт-контроллер по правильной сигнатуре
        // let alertController = textAlertController(
        //     theme: nil,
        //     title: titleAttr,
        //     text: textAttr,
        //     actions: [
        //         TextAlertAction(
        //             type: .defaultAction,
        //             title: DivoStrings.cancel,
        //             action: {}
        //         )
        //     ]
        // )
        
        // // Презентуем алерт поверх всего окна приложения (стандартный метод Telegram)
        // self.present(alertController, in: .window(.root))
    }

    // MARK: - Server Request Flow
    private func performRosterSearch(query: String) {
        guard !isLoading else { return }
        
        self.controllerNode.state = .loading
        self.isLoading = true
        
        Task { [weak self] in
            do {
                let request = AgencySearchRequest(
                    name: query
                )
                
                // Делаем реальный сетевой POST-запрос к /agency/search
                let response: AgencySearchResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/search",
                    method: "POST",
                    body: request
                )
                
                let profileItems = response.data.items
                
                // Маппим DTO-объекты в наши UI-модели RosterSearchUser
                let mappedUsers = self?.mapToRosterUsers(profileItems) ?? []
               
                await MainActor.run {
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    // Проверяем, не успел ли измениться поисковый запрос во время выполнения запроса к серверу
                    let currentTextFieldText = self.controllerNode.searchTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard currentTextFieldText == query else { return }

                    if mappedUsers.isEmpty {
                        self.controllerNode.state = .empty
                    } else {
                        self.controllerNode.state = .success(users: mappedUsers)
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    self.isLoading = false
                    self.controllerNode.state = .failed(networkError: true)
                }
            }
        }
    }

    // Метод маппинга SearchUserDTO в RosterSearchUser с определением статуса модели
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
