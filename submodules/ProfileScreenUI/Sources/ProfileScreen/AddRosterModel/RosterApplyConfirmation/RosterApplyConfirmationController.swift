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

    public var onConfirmSuccess: ((String?) -> Void)?

    public init(context: AccountContext, userId: Int) {
        self.context = context
        self.userId = userId
        super.init(context: context, navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = RosterApplyConfirmationNode()
        
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
                let userResponse: UserDetailResponse = try await DivoAPIClient.shared.request(
                    path: "/user/\(self.userId)",
                    method: "GET"
                )

                await MainActor.run {
                    self.controllerNode.update(with: userResponse.data)
                }
            } catch {
                await MainActor.run {
                    self.controllerNode.markFailed(networkError: isNetworkError(error))
                }
            }
        }
    }
    
    private func performConfirmAddition(_ name: String?) {
        self.controllerNode.toggleSubmitLoading(active: true)
        
        Task { [weak self] in
            guard let userId = self?.userId else { return }
            do {
                let _: FollowResponse = try await DivoAPIClient.shared.request(
                    path: "/agency/\(userId)/models",
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
                    let userMsg = (error as? DivoAPIError)?.userFacingMessage ?? DivoStrings.genericError
                    self.controllerNode.showSnackbar(message: userMsg, style: .error)
                }
            }
        }
    }

}
