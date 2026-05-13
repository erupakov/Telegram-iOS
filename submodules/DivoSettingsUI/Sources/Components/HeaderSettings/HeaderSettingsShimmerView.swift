//
//  HeaderAvater.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 13.05.2026.
//

import UIKit
import Display
import DivoCore
import DivoUIKit

class HeaderSettingsShimmerView: UIView {
    
    // MARK: - UI Elements (Placeholders)
    
    static let avatarSize: CGFloat = 94
    
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
    
    private let phonePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.layer.cornerRadius = 9
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
        addSubview(phonePlaceholder)
    }
    
    private func setupConstraints() {
        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 12
        textStack.alignment = .center
        
        textStack.addArrangedSubview(avatarPlaceholder)
        textStack.addArrangedSubview(namePlaceholder)
        textStack.addArrangedSubview(phonePlaceholder)
        
        addSubview(textStack)
        
        NSLayoutConstraint.activate([
            textStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            avatarPlaceholder.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarPlaceholder.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            
            namePlaceholder.heightAnchor.constraint(equalToConstant: 22),
            namePlaceholder.widthAnchor.constraint(equalToConstant: 100),
            
            phonePlaceholder.heightAnchor.constraint(equalToConstant: 18),
            phonePlaceholder.widthAnchor.constraint(equalToConstant: 120),
        ])
        
        textStack.setCustomSpacing(6, after: namePlaceholder)
    }
    
    // MARK: - Animation
    
    func startAnimation() {
        [avatarPlaceholder, namePlaceholder, phonePlaceholder].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [avatarPlaceholder, namePlaceholder, phonePlaceholder].forEach {
            $0.stopShimmering()
        }
    }
}
