//
//  RosterAlertController.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 02.06.2026.
//

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import DivoUIKit
import DivoCore

public final class RosterAlertController: ViewController {
    
    private var controllerNode: RosterAlertNode {
        return self.displayNode as! RosterAlertNode
    }

    private let agencyName: String
    
    // MARK: - Init
    public init(agencyName: String) {
        self.agencyName = agencyName
        
        super.init(navigationBarPresentationData: nil)
        
        self.blocksBackgroundWhenInOverlay = true
        self.statusBar.statusBarStyle = .Ignore
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = RosterAlertNode(agencyName: self.agencyName)
        self.displayNodeDidLoad()
        
        self.controllerNode.dismiss = { [weak self] in
            self?.dismissAnimated()
        }
    }
    
    private func dismissAnimated() {
        self.controllerNode.animateOut { [weak self] in
            self?.dismiss(animated: false, completion: nil)
        }
    }
    
    private var didPlayAppearanceAnimation = false
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !self.didPlayAppearanceAnimation {
            self.didPlayAppearanceAnimation = true
            self.controllerNode.animateIn()
        }
    }
}
