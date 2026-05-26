//
//  OnboardingQuizOptionRow.swift
//  divo-ios
//
//  Created by Michail Shagovitov on 19.05.2026.
//

import UIKit
import Display
import DivoCore
import DivoUIKit

public enum OnboardingQuizOptionTypeRow {
    case big
    case medium
    case small
}

// MARK: - Option row

final class OnboardingQuizOptionRow: UIControl {
    let option: OnboardingQuizDescriptor.Option
    var onTap: (() -> Void)?
    
    let type: OnboardingQuizOptionTypeRow

    private let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = Font.helveticaNeue(20)
        titleLabel.textColor = DivoColorPalette.primaryText
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        return titleLabel
    }()

    private let subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.font = Font.regular(16)
        subtitleLabel.textColor = DivoColorPalette.primaryText.withAlphaComponent(0.8)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        return subtitleLabel
    }()

    private let radioView: UIImageView = {
        let radioView = UIImageView()
        radioView.translatesAutoresizingMaskIntoConstraints = false
        radioView.contentMode = .scaleAspectFit
        radioView.tintColor = DivoColorPalette.accent
        return radioView
    }()
    
    private var radioViewTopAnchor: NSLayoutConstraint!
    private var radioViewCenterYAnchor: NSLayoutConstraint!
    private var rowHeightAnchor: NSLayoutConstraint!

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = DivoDesignTokens.Spacing.xs
        stack.isUserInteractionEnabled = false
        return stack
    }()

    init(option: OnboardingQuizDescriptor.Option, type: OnboardingQuizOptionTypeRow, icon: UIImage, isSelected: Bool) {
        self.option = option
        self.type = type
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = DivoColorPalette.cardBackground
        layer.cornerRadius = DivoDesignTokens.Radius.l
        layer.borderWidth = isSelected ? 1 : 0
        layer.borderColor = DivoColorPalette.accent.cgColor

        titleLabel.text = OnboardingStrings.resolve(option.titleKey).uppercased()

        if let subtitleKey = option.subtitleKey {
            subtitleLabel.text = OnboardingStrings.resolve(subtitleKey)
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        addSubview(radioView)
        addSubview(stack)
        
        radioViewTopAnchor = radioView.topAnchor.constraint(equalTo: topAnchor, constant: DivoDesignTokens.Spacing.m)
        radioViewCenterYAnchor = radioView.centerYAnchor.constraint(equalTo: centerYAnchor)
        rowHeightAnchor = heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        
        NSLayoutConstraint.activate([
            radioViewCenterYAnchor,
            radioViewTopAnchor,
            radioView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            radioView.widthAnchor.constraint(equalToConstant: 24),
            radioView.heightAnchor.constraint(equalToConstant: 24),
            
            stack.leadingAnchor.constraint(equalTo: radioView.trailingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DivoDesignTokens.Spacing.m),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: DivoDesignTokens.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DivoDesignTokens.Spacing.m),

            rowHeightAnchor,
        ])
        
        switch self.type {
        case .big:
            radioViewTopAnchor.isActive = true
            radioViewCenterYAnchor.isActive = false
            rowHeightAnchor.constant = 80
            titleLabel.font = Font.helveticaNeue(20)
        case .medium:
            radioViewTopAnchor.isActive = true
            radioViewCenterYAnchor.isActive = false
            rowHeightAnchor.constant = 70
            titleLabel.font = Font.helveticaNeue(14)
            subtitleLabel.font = Font.regular(14)
        case .small:
            radioViewTopAnchor.isActive = false
            radioViewCenterYAnchor.isActive = true
            rowHeightAnchor.constant = 56
            titleLabel.font = Font.helveticaNeue(14)
        }
        
        radioView.image = icon
        setSelected(isSelected)
        addTarget(self, action: #selector(tap), for: .touchUpInside)
        // Стандартный DIVO press-state: alpha 0.65 + лёгкий scale 0.98 для list-row.
        addPressState(alpha: DivoDesignTokens.PressState.alpha, scale: DivoDesignTokens.PressState.scaleListRow)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ isSelected: Bool) {
        switch self.type {
        case .big, .medium:
            let image = isSelected ? DivoImage.largecircleFillCircle : DivoImage.circle
            radioView.image = image
            layer.borderWidth = isSelected ? 1 : 0
            layer.borderColor = DivoColorPalette.accent.cgColor
            titleLabel.textColor = DivoColorPalette.primaryText
        case .small:
            radioView.tintColor = isSelected ? DivoColorPalette.accent : DivoColorPalette.primaryText
            
            layer.borderWidth = isSelected ? 1 : 0
            layer.borderColor = DivoColorPalette.accent.cgColor
            
            titleLabel.textColor = isSelected ? DivoColorPalette.accent : DivoColorPalette.primaryText
        }
    }

    @objc private func tap() { onTap?() }
}
