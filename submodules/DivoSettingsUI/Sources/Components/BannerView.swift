//
//  BannerView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 13.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

final class BannerView: UIView {
    
    private let bannerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        return view
    }()
    
    private let bannerImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = DivoImage.settingsBannerBackground
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = DivoDesignTokens.Radius.l
        return iv
    }()
    
    private let bannerDivoLabel: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = DivoImage.settingsSmallLogo
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()
    
    private let bannerTitleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.settingsBannerTitle.uppercased()
        return label
    }()
    
    private let bannerDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.bannerSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = DivoStrings.settingsBannerDescription
        label.numberOfLines = 0
        return label
    }()
    
    private let learnMoreButton = DivoButton()
    
    var onLearnMoreTapped: (() -> Void)?
    
    init() {
        super.init(frame: .zero)
        
        self.backgroundColor = .clear
        self.translatesAutoresizingMaskIntoConstraints = false
        
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        learnMoreButton.makeDivoButton(title: DivoStrings.settingsLearnMore, buttonFont: Font.helveticaNeue(16), radius: DivoDesignTokens.Radius.pill)
        
        addSubview(bannerContainer)
        bannerContainer.addSubview(bannerImageView)
        bannerContainer.addSubview(bannerDivoLabel)
        bannerContainer.addSubview(bannerTitleLabel)
        bannerContainer.addSubview(bannerDescriptionLabel)
        bannerContainer.addSubview(learnMoreButton)
        
        learnMoreButton.addTarget(self, action: #selector(learnMoreTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            bannerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            bannerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            bannerContainer.topAnchor.constraint(equalTo: topAnchor),
            bannerContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            bannerImageView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
            bannerImageView.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor),
            bannerImageView.topAnchor.constraint(equalTo: bannerContainer.topAnchor),
            bannerImageView.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor),
            
            bannerDivoLabel.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bannerDivoLabel.topAnchor.constraint(equalTo: bannerContainer.topAnchor, constant: DivoDesignTokens.Spacing.l),
            bannerDivoLabel.heightAnchor.constraint(equalToConstant: 30),
            bannerDivoLabel.widthAnchor.constraint(equalToConstant: 78),
            
            bannerTitleLabel.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bannerTitleLabel.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bannerTitleLabel.topAnchor.constraint(equalTo: bannerDivoLabel.bottomAnchor, constant: 20),
            
            bannerDescriptionLabel.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            bannerDescriptionLabel.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            bannerDescriptionLabel.topAnchor.constraint(equalTo: bannerTitleLabel.bottomAnchor, constant: 6),
            
            learnMoreButton.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            learnMoreButton.topAnchor.constraint(equalTo: bannerDescriptionLabel.bottomAnchor, constant: 12),
            learnMoreButton.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor, constant: -DivoDesignTokens.Spacing.m),
            learnMoreButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }
    
    @objc private func learnMoreTapped() {
        onLearnMoreTapped?()
    }
}
