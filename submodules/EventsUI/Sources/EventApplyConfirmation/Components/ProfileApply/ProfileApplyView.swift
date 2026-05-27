//
//  CurrentAgencyView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 07.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

final class ProfileApplyView: UIView {
        
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground
        view.layer.cornerRadius = DivoDesignTokens.Radius.l
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = DivoStrings.shareWithOrganiser
        label.font = Font.regular(12)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = DivoDesignTokens.Radius.card
        iv.backgroundColor = DivoColorPalette.cardBackground
        iv.layer.borderWidth = 1
        iv.layer.borderColor = DivoColorPalette.borderWorkHistoryImage.cgColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let profileNameLabel: UILabel = {
        let label = UILabel()
        label.font = Font.medium(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let roleLabelContainer: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.roleBadgeBlue
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.required, for: .horizontal)
        return view
    }()
    
    private let roleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(11)
        label.textColor = DivoColorPalette.primaryTextOnDark
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private var lastLogoURL: URL?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(titleLabel)
        addSubview(containerView)
        
        containerView.addSubview(logoImageView)
        
        roleLabelContainer.addSubview(roleLabel)
        
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let infoStack = UIStackView(arrangedSubviews: [roleLabelContainer, metaLabel, spacer])
        infoStack.axis = .horizontal
        infoStack.spacing = DivoDesignTokens.Spacing.xs
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        
        let textStack = UIStackView(arrangedSubviews: [profileNameLabel, infoStack])
        textStack.axis = .vertical
        textStack.spacing = DivoDesignTokens.Spacing.xs
        textStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(textStack)
        
        profileNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.topAnchor, constant: -10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            logoImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            logoImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            logoImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            logoImageView.widthAnchor.constraint(equalToConstant: 48),
            logoImageView.heightAnchor.constraint(equalToConstant: 48),
            
            textStack.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 10),
            textStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            textStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            
            roleLabelContainer.heightAnchor.constraint(equalToConstant: 22),
            
            roleLabel.leadingAnchor.constraint(equalTo: roleLabelContainer.leadingAnchor, constant: DivoDesignTokens.Spacing.s),
            roleLabel.centerYAnchor.constraint(equalTo: roleLabelContainer.centerYAnchor),
            roleLabel.trailingAnchor.constraint(equalTo: roleLabelContainer.trailingAnchor, constant: -DivoDesignTokens.Spacing.s),
        ])
    }
    
    func configure(name: String?, role: String?, meta: String?, fullUrl: String?) {
        UIView.performWithoutAnimation {
            self.profileNameLabel.text = name?.uppercased() ?? DivoStrings.unknownAgency
            self.roleLabel.text = role
            self.metaLabel.text = meta
            self.profileNameLabel.layer.removeAllAnimations()
            self.layoutIfNeeded()
        }
        
        if let avatarURL = CDNURLHelper.convertToCDNURL(fullUrl) {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: avatarURL)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.logoImageView.image = image
                            self.logoImageView.applyAvatarTopCropIfNeeded(image: image)
                        }
                    }
                } catch {}
            }
        }
        self.layoutIfNeeded()
    }
}
