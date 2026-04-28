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

    private static let badgeHeight: CGFloat = 22

    // MARK: - UI Elements (Placeholders)
    
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
        view.layer.cornerRadius = badgeHeight / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let rolePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = badgeHeight / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let infoPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = badgeHeight / 2
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
        addSubview(namePlaceholder)
        addSubview(premiumBadgePlaceholder)
        addSubview(rolePlaceholder)
        addSubview(infoPlaceholder)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            namePlaceholder.topAnchor.constraint(equalTo: topAnchor),
            namePlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            namePlaceholder.widthAnchor.constraint(equalToConstant: 180),
            namePlaceholder.heightAnchor.constraint(equalToConstant: 64),
            
            premiumBadgePlaceholder.leadingAnchor.constraint(equalTo: namePlaceholder.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            premiumBadgePlaceholder.bottomAnchor.constraint(equalTo: namePlaceholder.bottomAnchor, constant: -DivoDesignTokens.Spacing.xs),
            premiumBadgePlaceholder.widthAnchor.constraint(equalToConstant: 80),
            premiumBadgePlaceholder.heightAnchor.constraint(equalToConstant: Self.badgeHeight),
            premiumBadgePlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            
            rolePlaceholder.topAnchor.constraint(equalTo: namePlaceholder.bottomAnchor, constant: 6),
            rolePlaceholder.leadingAnchor.constraint(equalTo: namePlaceholder.leadingAnchor),
            rolePlaceholder.widthAnchor.constraint(equalToConstant: 100),
            rolePlaceholder.heightAnchor.constraint(equalToConstant: Self.badgeHeight),
            rolePlaceholder.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            infoPlaceholder.leadingAnchor.constraint(equalTo: rolePlaceholder.trailingAnchor, constant: 10),
            infoPlaceholder.centerYAnchor.constraint(equalTo: rolePlaceholder.centerYAnchor),
            infoPlaceholder.widthAnchor.constraint(equalToConstant: 140),
            infoPlaceholder.heightAnchor.constraint(equalToConstant: Self.badgeHeight),
            infoPlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }
    
    // MARK: - Animation
    
    func startAnimation() {
        [namePlaceholder, premiumBadgePlaceholder, rolePlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [namePlaceholder, premiumBadgePlaceholder, rolePlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
        }
    }
}
