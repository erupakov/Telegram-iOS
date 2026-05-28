//
//  ApplicationsListShimmerView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 28.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

final class ApplicationsListCellShimmerView: UIView {
    
    private static let avatarSize: CGFloat = 52

    private let avatarImageView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = avatarSize / 2
        return view
    }()

    private let nameLabel: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 10
        return view
    }()

    private let metaLabel: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.cardBackground.withAlphaComponent(0.1)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 9
        return view
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = DivoColorPalette.primaryText.withAlphaComponent(0.12)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        startAnimation()
    }
    
    private func setupViews() {
        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(metaLabel)
        addSubview(separatorView)
        
        NSLayoutConstraint.activate([
            avatarImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -12),
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            nameLabel.heightAnchor.constraint(equalToConstant: 20),
            nameLabel.widthAnchor.constraint(equalToConstant: 110),
            
            metaLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 11),
            metaLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            metaLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            metaLabel.heightAnchor.constraint(equalToConstant: 18),
            metaLabel.widthAnchor.constraint(equalToConstant: 140),
            
            separatorView.leadingAnchor.constraint(equalTo: avatarImageView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    func startAnimation() {
        [avatarImageView, nameLabel, metaLabel].forEach {
            $0.stopShimmering()
            $0.startShimmering()
        }
    }
    
    func stopAnimation() {
        [avatarImageView, nameLabel, metaLabel].forEach {
            $0.stopShimmering()
        }
    }
}
