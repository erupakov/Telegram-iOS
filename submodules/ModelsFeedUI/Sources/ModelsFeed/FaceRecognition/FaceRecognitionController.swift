//
//  FaceRecognitionController.swift
//  divo-ios
//
//  Created by Marina Zaytseva on 16.04.2026.
//

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramPresentationData
import DivoCore
import DivoUIKit

public final class FaceRecognitionController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: nil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = FaceRecognitionNode(context: self.context, presentationData: self.presentationData)
        node.onClosePressed = { [weak self] in
            guard let self else { return }
            if let nav = self.navigationController as? NavigationController {
                _ = nav.popViewController(animated: true)
            } else {
                self.dismiss()
            }
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationBar?.isHidden = true
    }
}

private final class FaceRecognitionNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData

    var onClosePressed: (() -> Void)?

    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DivoColorPalette.cardBackground
        button.layer.cornerRadius = DivoDesignTokens.Radius.pill
        button.setImage(DivoImage.searchCloseIcon, for: .normal)
        button.tintColor = DivoColorPalette.primaryText
        button.layer.applyDivoShadow()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let iconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.sheet
        view.layer.applyDivoShadow(opacity: 0.05) // TODO: DS alignment — non-DS opacity
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = DivoImage.searchFaceScan
        imageView.tintColor = DivoColorPalette.accent
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.faceRecognitionTitle
        label.font = Font.helveticaNeue(26)
        label.textColor = DivoColorPalette.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.faceRecognitionComingSoon
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        super.init()
        self.backgroundColor = DivoColorPalette.screenBackground
    }

    override func didLoad() {
        super.didLoad()
        setupUI()
    }

    private func setupUI() {
        let safeArea = view.safeAreaLayoutGuide
        let sidePadding: CGFloat = 16.0
        let elementHeight: CGFloat = 40.0

        view.addSubview(closeButton)
        view.addSubview(iconContainer)
        iconContainer.addSubview(iconView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: DivoDesignTokens.Spacing.s),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding),
            closeButton.widthAnchor.constraint(equalToConstant: elementHeight),
            closeButton.heightAnchor.constraint(equalToConstant: elementHeight)
        ])

        NSLayoutConstraint.activate([
            iconContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            iconContainer.widthAnchor.constraint(equalToConstant: 68),
            iconContainer.heightAnchor.constraint(equalToConstant: 68),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.xl),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.xl),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DivoDesignTokens.Spacing.s),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DivoDesignTokens.Spacing.xl),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DivoDesignTokens.Spacing.xl)
        ])

        closeButton.addDivoPressState(.pill)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    }

    @objc private func closeTapped() {
        onClosePressed?()
    }
}
