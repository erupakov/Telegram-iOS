//
//  ProfileApplyShimmerView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

class ProfileApplyShimmerView: UIView {
    
    // MARK: - UI Elements (Placeholders)
    
    private let titlePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let profilePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = DivoDesignTokens.Spacing.m
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
        addSubview(titlePlaceholder)
        addSubview(profilePlaceholder)

    }
    
    private func setupConstraints() {
        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 10
        textStack.alignment = .leading
        
        textStack.addArrangedSubview(titlePlaceholder)
        textStack.addArrangedSubview(profilePlaceholder)
        
        addSubview(textStack)
        
        NSLayoutConstraint.activate([
            textStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            titlePlaceholder.heightAnchor.constraint(equalToConstant: 20),
            titlePlaceholder.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width / 2),
            
            profilePlaceholder.heightAnchor.constraint(equalToConstant: 70),
            profilePlaceholder.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - DivoDesignTokens.Spacing.xl),
        ])
    }
    
    // MARK: - Animation
    
    func startAnimation() {
        [titlePlaceholder, profilePlaceholder].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [titlePlaceholder, profilePlaceholder].forEach {
            $0.stopShimmering()
        }
    }
}
