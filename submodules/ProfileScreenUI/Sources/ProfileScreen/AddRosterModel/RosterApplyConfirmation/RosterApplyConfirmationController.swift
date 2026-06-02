//
//  RosterApplyConfirmationController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 01.06.2026.
//

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import TelegramBaseController
import DivoUIKit
import DivoCore

public final class RosterApplyConfirmationController: TelegramBaseController {
    
    private var controllerNode: RosterApplyConfirmationNode {
        return self.displayNode as! RosterApplyConfirmationNode
    }

    private let context: AccountContext
    private let userId: Int
    private var agencyId: Int?
    private var userDetail: UserDetail?
    
    public var onConfirmSuccess: ((String?) -> Void)?

    public init(context: AccountContext, userId: Int, agencyId: Int? = nil) {
        self.context = context
        self.userId = userId
        self.agencyId = agencyId
        super.init(context: context, navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = RosterApplyConfirmationNode(context: self.context)
        
        self.controllerNode.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.controllerNode.onCancelTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        self.controllerNode.onConfirmTapped = { [weak self] name in
            self?.performConfirmAddition(name)
        }
        
        self.controllerNode.onRetryTapped = { [weak self] in
            guard let self = self else { return }
            self.controllerNode.resetToLoading()
            self.fetchModelDetail()
        }

        self.displayNodeDidLoad()
        fetchModelDetail()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    private func fetchModelDetail() {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                // 1. Загружаем детальную информацию о модели
                let userResponse: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/\(self.userId)",
                    method: "GET"
                )
                
                // 2. Если ID агентства не передано, берем его из профиля текущего пользователя
                if self.agencyId == nil {
                    let myProfileResponse: UserDetailResponse = try await DivoAPIClient.shared.request(
                        path: "/user/info",
                        method: "GET"
                    )
                    self.agencyId = myProfileResponse.data.agency?.id
                }

                await MainActor.run {
                    self.userDetail = userResponse.data
                    self.controllerNode.update(with: userResponse.data)
                }
            } catch {
                await MainActor.run {
                    self.controllerNode.markFailed(networkError: self.isNetworkError(error))
                }
            }
        }
    }
    
    private func performConfirmAddition(_ name: String?) {
        guard let agencyId = self.agencyId else { return }
        self.controllerNode.toggleSubmitLoading(active: true)
        
        Task { [weak self] in
            guard let userId = self?.userId else { return }
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/\(agencyId)/models/\(userId)",
                    method: "POST"
                )
                
                await MainActor.run {
                    guard let self = self else { return }
                    self.controllerNode.toggleSubmitLoading(active: false)
                    self.onConfirmSuccess?(name)
                }
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    self.controllerNode.toggleSubmitLoading(active: false)
                    self.controllerNode.showSnackbar(
                        message: DivoStrings.genericError,
                        style: .error
                    )
                }
            }
        }
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let apiError = error as? DivoAPIError, case .noInternetConnection = apiError {
            return true
        }
        return false
    }
}
