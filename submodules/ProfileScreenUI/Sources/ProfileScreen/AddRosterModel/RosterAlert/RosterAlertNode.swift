//
//  RosterAlertNode.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 03.06.2026.
//

import AsyncDisplayKit
import Display
import DivoUIKit
import DivoCore

final class RosterAlertNode: ASDisplayNode {
    private let agencyName: String
    
    private let cancelButton = DivoButton()
    
    private let dimNode: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DivoColorPalette.splashBackground.withAlphaComponent(0.4)
        view.alpha = 0.0
        return view
    }()
    
    private let backgroundNode: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = 30
        view.alpha = 0.0
        return view
    }()
    
    private let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = Font.semibold(17)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        return titleLabel
    }()
    
    private let subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.font = Font.regular(13)
        subtitleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 0
        subtitleLabel.text = DivoStrings.addModelAlertSubtitle
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        return subtitleLabel
    }()
    
    var dismiss: () -> Void = {}
    
    init(agencyName: String) {
        self.agencyName = agencyName
        
        super.init()
        
        self.clipsToBounds = false
        
        cancelButton.makeDivoButton(title: DivoStrings.cancel, buttonFont: Font.helveticaNeue(16), radius: 20, divoButtonStyle: .secondary)
        cancelButton.backgroundColor = DivoColorPalette.secondaryButtonBackground
        
        self.cancelButton.addTarget(self, action: #selector(dimTapped), for: .touchUpInside)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapped)))
        
        setupAutoLayout()
    }
    
    @objc private func dimTapped() {
        self.dismiss()
    }
    
    private func setupAutoLayout() {

        titleLabel.text = DivoStrings.addModelAlertTitle(agencyName)

        self.view.addSubview(dimNode)
        self.view.addSubview(backgroundNode)
        
        let contentStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, self.cancelButton])
        contentStack.axis = .vertical
        contentStack.spacing = DivoDesignTokens.Spacing.xs
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentStack.isLayoutMarginsRelativeArrangement = true

        contentStack.setCustomSpacing(24, after: subtitleLabel)
        
        self.backgroundNode.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            dimNode.topAnchor.constraint(equalTo: self.view.topAnchor),
            dimNode.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            dimNode.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            dimNode.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            backgroundNode.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            backgroundNode.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            backgroundNode.widthAnchor.constraint(equalToConstant: 270),
            backgroundNode.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.leadingAnchor, constant: 20),
            backgroundNode.trailingAnchor.constraint(lessThanOrEqualTo: self.view.trailingAnchor, constant: -20),
            
            contentStack.topAnchor.constraint(equalTo: backgroundNode.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: backgroundNode.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: backgroundNode.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: backgroundNode.bottomAnchor, constant: -12),
            
            cancelButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func animateIn() {
        self.dimNode.alpha = 1.0
        self.backgroundNode.alpha = 1.0
        
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.backgroundNode.layer.animateScale(from: 0.85, to: 1.0, duration: 0.3)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.dimNode.alpha = 0.0
        self.backgroundNode.alpha = 0.0
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.backgroundNode.layer.animateScale(from: 1.0, to: 0.85, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
}
