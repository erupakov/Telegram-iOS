//
//  ProfileHeaderShimmerView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 06.03.2026.
//

import UIKit
import DivoCore

class ProfileHeaderShimmerView: UIView {
    
    // MARK: - UI Elements (Placeholders)
    
    private let avatarPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let ringView: AvatarStrokeView = {
        let view = AvatarStrokeView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let namePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let crownPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let tagPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let infoPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 6
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
        
        let avatarSize: CGFloat = 80
        avatarPlaceholder.layer.cornerRadius = avatarSize / 2
        ringView.layer.cornerRadius = (avatarSize + 10) / 2
        
        startAnimation()
    }
    
    private func setupViews() {
        addSubview(ringView)
        addSubview(avatarPlaceholder)
        addSubview(namePlaceholder)
        addSubview(crownPlaceholder)
        addSubview(tagPlaceholder)
        addSubview(infoPlaceholder)
    }
    
    private func setupConstraints() {
        let avatarSize: CGFloat = 80
        
        NSLayoutConstraint.activate([
            avatarPlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            avatarPlaceholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarPlaceholder.widthAnchor.constraint(equalToConstant: avatarSize),
            avatarPlaceholder.heightAnchor.constraint(equalToConstant: avatarSize),
            
            ringView.centerXAnchor.constraint(equalTo: avatarPlaceholder.centerXAnchor),
            ringView.centerYAnchor.constraint(equalTo: avatarPlaceholder.centerYAnchor),
            ringView.widthAnchor.constraint(equalToConstant: avatarSize + 10),
            ringView.heightAnchor.constraint(equalToConstant: avatarSize + 10),
            
            namePlaceholder.leadingAnchor.constraint(equalTo: ringView.trailingAnchor, constant: 10),
            namePlaceholder.bottomAnchor.constraint(equalTo: tagPlaceholder.topAnchor, constant: -12),
            namePlaceholder.widthAnchor.constraint(equalToConstant: 180),
            namePlaceholder.heightAnchor.constraint(equalToConstant: 64),
            
            crownPlaceholder.leadingAnchor.constraint(equalTo: namePlaceholder.trailingAnchor, constant: 8),
            crownPlaceholder.centerYAnchor.constraint(equalTo: avatarPlaceholder.centerYAnchor),
            crownPlaceholder.widthAnchor.constraint(equalToConstant: 24),
            crownPlaceholder.heightAnchor.constraint(equalToConstant: 24),
            
            tagPlaceholder.leadingAnchor.constraint(equalTo: namePlaceholder.leadingAnchor),

            tagPlaceholder.widthAnchor.constraint(equalToConstant: 100),
            tagPlaceholder.heightAnchor.constraint(equalToConstant: 20),
            
            infoPlaceholder.leadingAnchor.constraint(equalTo: tagPlaceholder.trailingAnchor, constant: 10),
            infoPlaceholder.centerYAnchor.constraint(equalTo: tagPlaceholder.centerYAnchor),
            infoPlaceholder.topAnchor.constraint(equalTo: crownPlaceholder.bottomAnchor, constant: 10),
            infoPlaceholder.widthAnchor.constraint(equalToConstant: 120),
            infoPlaceholder.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func startAnimation() {
        [avatarPlaceholder, namePlaceholder, crownPlaceholder, tagPlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [avatarPlaceholder, namePlaceholder, crownPlaceholder, tagPlaceholder, infoPlaceholder].forEach {
            $0.stopShimmering()
        }
    }
}
