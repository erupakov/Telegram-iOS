//
//  OnboardingCell.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 28.02.2026.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import DivoUIKit
import DivoCore

public final class DivoSplashController: ViewController {
    private var controllerNode: DivoSplashControllerNode {
        return self.displayNode as! DivoSplashControllerNode
    }

    private let theme: PresentationTheme
    public var nextPressed: ((PresentationStrings?) -> Void)?
    private var transitionTimer: SwiftSignalKit.Timer?

    public init(theme: PresentationTheme) {
        self.theme = theme
        super.init(navigationBarPresentationData: nil)
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        transitionTimer?.invalidate()
    }

    public override func loadDisplayNode() {
        self.displayNode = DivoSplashControllerNode(theme: self.theme)
        self.displayNodeDidLoad()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        transitionTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
            self?.proceedNext()
        }, queue: Queue.mainQueue())
        transitionTimer?.start()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        transitionTimer?.invalidate()
    }

    public func animateIn() {
        self.controllerNode.animateIn()
    }

    private func proceedNext() {
        if let navigationController = self.navigationController, navigationController.viewControllers.last === self {
            self.nextPressed?(nil)
        }
    }
}