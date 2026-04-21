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
    
    private let namePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let premiumBadgePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 11
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let rolePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Radius.m
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let infoPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
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
        addSubview(namePlaceholder)
        addSubview(premiumBadgePlaceholder)
        addSubview(rolePlaceholder)
        addSubview(infoPlaceholder)
    }
    
    private func setupConstraints() {
        let nameWidth: CGFloat = 180
        let premiumBadgeWidth: CGFloat = 80
        let roleWidth: CGFloat = 100
        let infoWidth: CGFloat = 140
        
        NSLayoutConstraint.activate([
            // namePlaceholder
            namePlaceholder.topAnchor.constraint(equalTo: topAnchor),
            namePlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            namePlaceholder.widthAnchor.constraint(equalToConstant: nameWidth),
            namePlaceholder.heightAnchor.constraint(equalToConstant: 64), // Примерная высота под 2 строки шрифта 32
            
            // premiumBadgePlaceholder
            premiumBadgePlaceholder.leadingAnchor.constraint(equalTo: namePlaceholder.trailingAnchor, constant: DivoDesignTokens.Spacing.s),
            premiumBadgePlaceholder.bottomAnchor.constraint(equalTo: namePlaceholder.bottomAnchor, constant: -4),
            premiumBadgePlaceholder.widthAnchor.constraint(equalToConstant: premiumBadgeWidth),
            premiumBadgePlaceholder.heightAnchor.constraint(equalToConstant: 22),
            premiumBadgePlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            
            // rolePlaceholder
            rolePlaceholder.topAnchor.constraint(equalTo: namePlaceholder.bottomAnchor, constant: 6),
            rolePlaceholder.leadingAnchor.constraint(equalTo: namePlaceholder.leadingAnchor),
            rolePlaceholder.widthAnchor.constraint(equalToConstant: roleWidth),
            rolePlaceholder.heightAnchor.constraint(equalToConstant: 22),
            rolePlaceholder.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // infoPlaceholder
            infoPlaceholder.leadingAnchor.constraint(equalTo: rolePlaceholder.trailingAnchor, constant: 10),
            infoPlaceholder.centerYAnchor.constraint(equalTo: rolePlaceholder.centerYAnchor),
            infoPlaceholder.widthAnchor.constraint(equalToConstant: infoWidth),
            infoPlaceholder.heightAnchor.constraint(equalToConstant: 20),
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