//
//  ProfileHeaderShimmerView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

import UIKit
import DivoCore
import DivoUIKit

class ProfileHeaderShimmerView: UIView {
    
    // MARK: - UI Elements (Placeholders)
    
    private let avatarPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Spacing.xl
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let namePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.s
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let premiumBadgePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let rolePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let infoPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        startAnimation()
    }
    
    private func setupViews() {
        addSubview(avatarPlaceholder)
        addSubview(namePlaceholder)
        addSubview(premiumBadgePlaceholder)
        addSubview(rolePlaceholder)
        addSubview(infoPlaceholder)
    }
    
    private func setupConstraints() {
        let avatarSize: CGFloat = 64
        
        NSLayoutConstraint.activate([
            
            avatarPlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            avatarPlaceholder.bottomAnchor.constraint(equalTo: bottomAnchor),
            avatarPlaceholder.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarPlaceholder.heightAnchor.constraint(equalToConstant: avatarSize),
            
            namePlaceholder.topAnchor.constraint(equalTo: topAnchor),
            namePlaceholder.leadingAnchor.constraint(equalTo: avatarPlaceholder.trailingAnchor, constant: 10),
            namePlaceholder.widthAnchor.constraint(equalToConstant: 180),
            namePlaceholder.heightAnchor.constraint(equalToConstant: 64),
            namePlaceholder.bottomAnchor.constraint(equalTo: rolePlaceholder.topAnchor, constant: -DivoDesignTokens.Spacing.s),

            premiumBadgePlaceholder.leadingAnchor.constraint(equalTo: namePlaceholder.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            premiumBadgePlaceholder.bottomAnchor.constraint(equalTo: rolePlaceholder.topAnchor, constant: -6),
            premiumBadgePlaceholder.widthAnchor.constraint(equalToConstant: 20),
            premiumBadgePlaceholder.heightAnchor.constraint(equalToConstant: 20),
            
            rolePlaceholder.topAnchor.constraint(equalTo: namePlaceholder.bottomAnchor, constant: 5),
            rolePlaceholder.leadingAnchor.constraint(equalTo: namePlaceholder.leadingAnchor),
            rolePlaceholder.widthAnchor.constraint(equalToConstant: 100),
            rolePlaceholder.heightAnchor.constraint(equalToConstant: 22),
            rolePlaceholder.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            infoPlaceholder.leadingAnchor.constraint(equalTo: rolePlaceholder.trailingAnchor, constant: 10),
            infoPlaceholder.centerYAnchor.constraint(equalTo: rolePlaceholder.centerYAnchor),
            infoPlaceholder.widthAnchor.constraint(equalToConstant: 140),
            infoPlaceholder.heightAnchor.constraint(equalToConstant: 22),
            infoPlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }
    
    // MARK: - Animation
    
    func startAnimation() {
        [avatarPlaceholder, namePlaceholder, premiumBadgePlaceholder, rolePlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [avatarPlaceholder, namePlaceholder, premiumBadgePlaceholder, rolePlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
        }
    }
}
