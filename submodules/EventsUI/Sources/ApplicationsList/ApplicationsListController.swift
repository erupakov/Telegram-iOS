//
//  ApplicationsListController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 28.05.2026.
//

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import AppBundle
import TelegramBaseController
import DivoUIKit
import DivoCore

public final class ApplicationsListController: TelegramBaseController {
    private var controllerNode: ApplicationsListNode {
        return self.displayNode as! ApplicationsListNode
    }

    private let context: AccountContext
    private let eventId: Int
    private var presentationData: PresentationData
    
    // Хранилища локального кэша для быстрой перерисовки табов
    private var allApplicants: [ApplicantItem] = []
    private var filteredApplicants: [ApplicantItem] = []
    private var selectedTabIndex: Int = 0

    public init(context: AccountContext, eventId: Int) {
        self.context = context
        self.eventId = eventId
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(context: context, navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = ApplicationsListNode(context: self.context)
        
        self.controllerNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        self.controllerNode.onTabSelected = { [weak self] index in
            self?.switchToTab(index)
        }

        self.controllerNode.onSelectionTapped = { [weak self] id in
            self?.toggleApplicantSelection(id: id)
        }
        
        // Связываем кнопку повтора на экране ошибок
        self.controllerNode.onRetry = { [weak self] in
            self?.loadApplicants()
        }

        self.displayNodeDidLoad()
        
        // Загружаем список кандидатов
        loadApplicants()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    // Асинхронная загрузка участников с сервера (Задача)
    private func loadApplicants() {
        self.controllerNode.phase = .loading
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                // Запрашиваем детали события, которые теперь включают поле appliedMembers
                let response: EventFullDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/event/\(self.eventId)",
                    method: "GET"
                )
                
                guard let members = response.data?.appliedMembers else {
                    await MainActor.run {
                        self.allApplicants = []
                        self.filterAndRender(tabIndex: self.selectedTabIndex)
                    }
                    return
                }
                
                // Мапим объекты EventAppliedMember в понятные для интерфейса ячейки ApplicantItem
                let mappedItems: [ApplicantItem] = members.compactMap { member in
                    guard let user = member.user else { return nil }
            
                    let dateStr = self.formatAppliedDate(member.appliedAt)

                    // status: бэк сейчас отдаёт только "going" — рабочие статусы (pending/shortlisted/
                    // accepted/rejected) ещё не реализованы, поэтому rawValue-парс даёт nil, пока они
                    // не появятся. Как только бэк начнёт слать эти значения — табы подхватят их сами.
                    return ApplicantItem(
                        id: user.id,
                        name: user.fullName ?? "",
                        avatarUrl: user.avatar?.fullUrl,
                        isVerified: user.isVerified,
                        role: user.roleLabel,
                        dateApplied: dateStr,
                        status: ApplicationStatus(rawValue: member.status ?? "")
                    )
                }
                
                await MainActor.run {
                    self.allApplicants = mappedItems
                    self.filterAndRender(tabIndex: self.selectedTabIndex)
                }
                
            } catch {
                divoLog("loadApplicants failed: \(error)", level: .error)
                await MainActor.run {
                    // Переводим узел в состояние ошибки
                    self.controllerNode.phase = .failed(networkError: self.isNetworkError(error))
                }
            }
        }
    }

    private func switchToTab(_ index: Int) {
        self.selectedTabIndex = index
        filterAndRender(tabIndex: index)
    }

    // Мгновенная локальная фильтрация по табам без сетевых запросов
    private func filterAndRender(tabIndex: Int) {
        let filtered: [ApplicantItem]
        switch tabIndex {
        case 0: // ALL
            filtered = allApplicants
        case 1: // PENDING
            filtered = allApplicants.filter { $0.status == .pending }
        case 2: // SHORTLISTED
            filtered = allApplicants.filter { $0.status == .shortlisted }
        case 3: // ACCEPTED
            filtered = allApplicants.filter { $0.status == .accepted }
        case 4: // REJECTED
            filtered = allApplicants.filter { $0.status == .rejected }
        default:
            filtered = allApplicants
        }
        
        self.filteredApplicants = filtered
        
        if allApplicants.isEmpty {
            self.controllerNode.phase = .empty
        } else {
            self.controllerNode.phase = filtered.isEmpty ? .empty : .content
            self.controllerNode.update(items: filtered, totalCount: allApplicants.count)
        }
    }

    // Локальное переключение галочки выбора (чекбокса)
    private func toggleApplicantSelection(id: Int) {
        if let index = allApplicants.firstIndex(where: { $0.id == id }) {
            allApplicants[index].isSelected?.toggle()
            filterAndRender(tabIndex: selectedTabIndex)
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.statusBar.isHidden = true
    }

    // MARK: - Helpers

    private func isNetworkError(_ error: Error) -> Bool {
        if let apiError = error as? DivoAPIError, case .noInternetConnection = apiError {
            return true
        }
        return false
    }

    private func formatAppliedDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        let serverFormatter = DateFormatter()
        serverFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        serverFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = serverFormatter.date(from: dateString) else { return dateString }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: DivoStrings.current.rawValue)
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
