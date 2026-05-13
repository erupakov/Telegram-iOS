//
//  SettingsRowView.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 13.05.2026.
//

import UIKit
import Display
import DivoUIKit
import DivoCore

final class SettingsRowView: UIView {
    
    private let settingsIconContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DivoColorPalette.screenBackground
        view.layer.cornerRadius = 6
        return view
    }()
    
    private let settingsIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(16)
        label.textColor = DivoColorPalette.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = Font.regular(14)
        label.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.6)
        label.textAlignment = .right
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let separator: UIView = {
        let separator = UIView()
        separator.backgroundColor = DivoColorPalette.primaryText.withAlphaComponent(0.1)
        separator.translatesAutoresizingMaskIntoConstraints = false
        return separator
    }()
    
    init(icon: UIImage, title: String, isLast: Bool) {
        super.init(frame: .zero)
        
        self.backgroundColor = .clear
        self.translatesAutoresizingMaskIntoConstraints = false
        
        settingsIcon.image = icon
        titleLabel.text = title
        addSubview(settingsIconContainer)
        settingsIconContainer.addSubview(settingsIcon)
        addSubview(titleLabel)
        addSubview(valueLabel)
        
        let chevronImageView = UIImageView()
        chevronImageView.image = DivoImage.searchChevronRight
        chevronImageView.tintColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chevronImageView)
        
        if !isLast {
            addSubview(separator)
            
            NSLayoutConstraint.activate([
                separator.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
                separator.bottomAnchor.constraint(equalTo: bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        
        NSLayoutConstraint.activate([
            settingsIconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DivoDesignTokens.Spacing.m),
            settingsIconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsIconContainer.heightAnchor.constraint(equalToConstant: 29),
            settingsIconContainer.widthAnchor.constraint(equalToConstant: 29),
            
            settingsIcon.centerXAnchor.constraint(equalTo: settingsIconContainer.centerXAnchor),
            settingsIcon.centerYAnchor.constraint(equalTo: settingsIconContainer.centerYAnchor),
            settingsIcon.heightAnchor.constraint(equalToConstant: 20),
            settingsIcon.widthAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: settingsIcon.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 20),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20),
            
            valueLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: DivoDesignTokens.Spacing.m),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setItems(_ text: String) {
        self.valueLabel.text = text
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }

    func setSeparator(_ isHidden: Bool) {
        self.separator.isHidden = isHidden
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
}
