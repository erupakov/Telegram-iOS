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

final class DivoSplashControllerNode: ASDisplayNode {
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = DivoImage.splashScreen
        return imageView
    }()

    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.shadow.withAlphaComponent(0.2)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = DivoImage.logo
        imageView.tintColor = DivoColorPalette.cardBackground
        return imageView
    }()

    init(theme: PresentationTheme) {
        super.init()
        self.backgroundColor = DivoColorPalette.shadow
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        setupViews()
    }

    private func setupViews() {
        self.view.addSubview(backgroundImageView)
        self.view.addSubview(overlayView)
        self.view.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: self.view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            logoImageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 160),
            logoImageView.heightAnchor.constraint(equalToConstant: 54)
        ])
    }

    func animateIn() {
        logoImageView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.logoImageView.alpha = 1
        }
    }
}