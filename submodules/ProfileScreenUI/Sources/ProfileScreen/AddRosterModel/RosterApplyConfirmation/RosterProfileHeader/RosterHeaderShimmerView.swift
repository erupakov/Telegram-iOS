//
//  RosterHeaderShimmerView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 26.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

class RosterHeaderShimmerView: UIView {
    
    // MARK: - UI Elements (Placeholders)
    
    static let avatarSize: CGFloat = 68
    
    private let avatarPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = avatarSize / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let namePlaceholder: UIView = {
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
        addSubview(infoPlaceholder)
    }
    
    private func setupConstraints() {
        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 18
        textStack.alignment = .center
        
        textStack.addArrangedSubview(avatarPlaceholder)
        textStack.addArrangedSubview(namePlaceholder)
        textStack.addArrangedSubview(infoPlaceholder)
        
        addSubview(textStack)
        
        NSLayoutConstraint.activate([
            textStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            avatarPlaceholder.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarPlaceholder.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            
            namePlaceholder.heightAnchor.constraint(equalToConstant: 40),
            namePlaceholder.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - (DivoDesignTokens.Spacing.xl*2)),
            
            infoPlaceholder.heightAnchor.constraint(equalToConstant: 22),
            infoPlaceholder.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - DivoDesignTokens.Spacing.xl),
        ])
        
        textStack.setCustomSpacing(6, after: namePlaceholder)
    }
    
    // MARK: - Animation
    
    func startAnimation() {
        [avatarPlaceholder, namePlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [avatarPlaceholder, namePlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
        }
    }
}
